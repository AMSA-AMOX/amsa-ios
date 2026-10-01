import Foundation
import Observation

/// Port of src/context/AuthContext.tsx. The session lives in the Keychain
/// (web: localStorage `amsa_auth`) and is shared by every screen.
@MainActor
@Observable
final class SessionStore {
    nonisolated static let account = "amsa_auth"

    private(set) var token: String?
    private(set) var user: AuthUser?
    /// Set when a 401 ended the session, so Login can explain why.
    private(set) var endedByExpiry = false

    let api: APIClient
    /// Cleared on logout (per-user caches such as the shell badges).
    var onLogout: (@MainActor () -> Void)?

    init(api: APIClient) {
        self.api = api
        restore()
    }

    var isAuthenticated: Bool { token != nil && user != nil }

    /// Role from the login response — identical to the JWT claim the server gates on.
    var role: String? { user?.role }

    func login(email: String, password: String) async throws -> AuthUser {
        let response = try await api.send(AuthAPI.login(email: email, password: password))
        save(token: response.token, user: response.user)
        return response.user
    }

    func signup(email: String, password: String, firstName: String, lastName: String,
                turnstileToken: String) async throws -> AuthUser {
        let response = try await api.send(AuthAPI.signup(
            email: email, password: password, firstName: firstName, lastName: lastName, turnstileToken: turnstileToken))
        save(token: response.token, user: response.user)
        return response.user
    }

    func logout() {
        token = nil
        user = nil
        Keychain.delete(Self.account)
        api.credentials.set(nil)
        onLogout?()
    }

    /// `updateUser(partial)` — merges fields into the stored user.
    func updateUser(_ mutate: (inout AuthUser) -> Void) {
        guard var current = user, let token else { return }
        mutate(&current)
        user = current
        persist(StoredSession(token: token, user: current))
    }

    // MARK: - Private

    private func save(token: String, user: AuthUser) {
        api.credentials.set(token)
        self.token = token
        self.user = user
        endedByExpiry = false
        persist(StoredSession(token: token, user: user))
    }

    private func persist(_ session: StoredSession) {
        if let data = try? JSONEncoder().encode(session) { Keychain.write(data, account: Self.account) }
    }

    private func restore() {
        guard let data = Keychain.read(Self.account),
              let stored = try? JSONDecoder().decode(StoredSession.self, from: data)
        else { return }
        // The web keeps using a stale token until requests fail; we drop an expired one up front.
        if let claims = JWTClaims(token: stored.token), claims.isExpired() {
            Keychain.delete(Self.account)
            endedByExpiry = true
            return
        }
        api.credentials.set(stored.token)
        token = stored.token
        user = stored.user
    }

    /// Wired to APIClient: any authenticated request answered with 401 ends the session.
    func handleUnauthorized() {
        guard isAuthenticated else { return }
        endedByExpiry = true
        logout()
    }
}
