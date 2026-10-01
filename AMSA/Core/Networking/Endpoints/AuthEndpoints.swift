import Foundation

enum AuthAPI {
    /// POST /api/auth/login
    static func login(email: String, password: String) -> Endpoint<AuthResponse> {
        Endpoint(method: .post, path: "/api/auth/login",
                 body: ["email": .string(email), "password": .string(password)], authenticated: false)
    }

    /// POST /api/auth/signup — the web trims only the email before sending.
    static func signup(email: String, password: String, firstName: String, lastName: String,
                       turnstileToken: String) -> Endpoint<AuthResponse> {
        Endpoint(method: .post, path: "/api/auth/signup", body: [
            "email": .string(email.trimmed),
            "password": .string(password),
            "firstName": .string(firstName),
            "lastName": .string(lastName),
            "turnstileToken": .string(turnstileToken),
        ], authenticated: false)
    }

    /// POST /api/auth/forgot-password
    static func forgotPassword(email: String) -> Endpoint<MessageResponse> {
        Endpoint(method: .post, path: "/api/auth/forgot-password", body: ["email": .string(email)], authenticated: false)
    }

    /// GET /api/auth/me
    static func me() -> Endpoint<MeResponse> { Endpoint(path: "/api/auth/me") }
}

struct MessageResponse: Decodable, Sendable {
    let message: String?
}
