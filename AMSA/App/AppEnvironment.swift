import Foundation
import Observation

/// Long-lived app services, created once at launch and shared through the environment.
@MainActor
final class AppEnvironment {
    let config: AppConfig
    let api: APIClient
    let session: SessionStore
    let shell: ShellStore
    let router: Router
    let links: ExternalLinkPresenter
    let storage: SupabaseStorage
    let colleges: CollegesStore
    let safety: SafetyStore
    let push: PushNotifications

    init(config: AppConfig) {
        self.config = config
        let api = APIClient(baseURL: config.apiBaseURL)
        self.api = api
        let session = SessionStore(api: api)
        self.session = session
        self.shell = ShellStore(api: api, tokenProvider: { [weak session] in session?.token })
        self.router = Router()
        self.links = ExternalLinkPresenter()
        self.storage = SupabaseStorage(baseURL: config.supabaseURL, anonKey: config.supabaseAnonKey)
        self.colleges = CollegesStore(api: api)
        self.safety = SafetyStore(api: api, tokenProvider: { [weak session] in session?.token })
        self.push = PushNotifications(api: api)

        // A follower or question just arrived: refresh the bell badge.
        push.onReceive = { [weak self] in self?.shell.load(force: true) }
        session.onLogout = { [weak self] in
            self?.push.signedOut()
            self?.shell.reset()
            self?.safety.reset()
            self?.router.reset()
        }
        Task { [weak session] in
            await api.setUnauthorizedHandler { @Sendable in
                await MainActor.run { session?.handleUnauthorized() }
            }
        }
    }

    static func live() -> AppEnvironment { AppEnvironment(config: .current) }
}
