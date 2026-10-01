import Foundation

/// Mirrors how the web's `api()` helper rejects: with the parsed JSON body.
/// Screens display `message ?? <web fallback copy>`, exactly like `e?.message ?? "…"`.
struct APIError: Error, Sendable, LocalizedError {
    /// HTTP status, or 0 for transport/decoding failures.
    let status: Int
    /// `message` from the response body (the field every page reads).
    let message: String?
    /// `error` from the response body (admin/maintenance routes use this instead).
    let errorField: String?
    /// Extra fields some routes return alongside the message (e.g. `errors`, `college`).
    let body: Data?

    var errorDescription: String? { message }

    static func transport(_ underlying: Error) -> APIError {
        APIError(status: 0, message: nil, errorField: nil, body: nil)
    }

    static let decoding = APIError(status: 0, message: nil, errorField: nil, body: nil)
}

extension Error {
    /// `e?.message` as the web pages read it.
    var apiMessage: String? { (self as? APIError)?.message }
}
