import Foundation

/// Public configuration injected through Info.plist from Config/*.xcconfig.
/// Only browser-exposed values exist here; server secrets never reach the app.
struct AppConfig: Sendable {
    let apiBaseURL: URL
    let supabaseURL: URL
    let supabaseAnonKey: String
    let logoDevToken: String
    let turnstileSiteKey: String

    static let current: AppConfig = {
        let info = Bundle.main.infoDictionary ?? [:]
        func string(_ key: String) -> String {
            guard let value = info[key] as? String, !value.isEmpty, !value.hasPrefix("$(") else {
                fatalError("Missing Info.plist key \(key) — run scripts/gen-secrets.sh and regenerate the project.")
            }
            return value
        }
        func url(_ key: String) -> URL {
            guard let url = URL(string: string(key)) else { fatalError("Invalid URL for \(key)") }
            return url
        }
        return AppConfig(
            apiBaseURL: url("AMSAAPIBaseURL"),
            supabaseURL: url("AMSASupabaseURL"),
            supabaseAnonKey: string("AMSASupabaseAnonKey"),
            logoDevToken: string("AMSALogoDevToken"),
            turnstileSiteKey: string("AMSATurnstileSiteKey")
        )
    }()

    /// Absolute URL for a path served by the website (e.g. `/states/aspen_co.webp`).
    func siteURL(_ path: String) -> URL {
        apiBaseURL.appending(path: path)
    }
}
