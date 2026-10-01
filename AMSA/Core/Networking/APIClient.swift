import Foundation
import os

/// Decodes endpoints that return no meaningful body (204, `{ok:true}`, `{message}`).
struct Empty: Decodable, Sendable {
    init() {}
    init(from decoder: Decoder) throws {}
}

enum HTTPMethod: String, Sendable {
    case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE"
}

/// One request against the website's `/api/*` routes.
struct Endpoint<Response: Decodable & Sendable>: Sendable {
    var method: HTTPMethod = .get
    var path: String
    var query: [(String, String)] = []
    var body: JSONValue? = nil
    /// `true` = web `authFetch` (Bearer token); `false` = web plain `fetch` (no token).
    var authenticated: Bool = true
}

/// The bearer token, readable synchronously from any isolation domain so a
/// request issued right after login/launch never races the session restore.
final class Credentials: Sendable {
    private let state = OSAllocatedUnfairLock<String?>(initialState: nil)
    var token: String? { state.withLock { $0 } }
    func set(_ token: String?) { state.withLock { $0 = token } }
}

/// Port of src/lib/api.ts + AuthContext.authFetch.
actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    nonisolated let credentials = Credentials()
    private var onUnauthorized: (@Sendable () async -> Void)?

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    private var token: String? { credentials.token }

    /// Called when a request that carried a token comes back 401 ("No token" / "Invalid token").
    func setUnauthorizedHandler(_ handler: @escaping @Sendable () async -> Void) { onUnauthorized = handler }

    func send<R>(_ endpoint: Endpoint<R>) async throws -> R {
        var request = URLRequest(url: try url(for: endpoint.path, query: endpoint.query))
        request.httpMethod = endpoint.method.rawValue
        // The web helper always sends this header, even on GET.
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let sentToken = endpoint.authenticated ? token : nil
        if endpoint.authenticated, sentToken == nil {
            // authFetch: `if (!token) return Promise.reject({ message: "Not authenticated" })`
            throw APIError(status: 401, message: "Not authenticated", errorField: nil, body: nil)
        }
        if let sentToken { request.setValue("Bearer \(sentToken)", forHTTPHeaderField: "Authorization") }
        if let body = endpoint.body { request.httpBody = try JSONEncoder().encode(body) }
        return try await perform(request, sentToken: sentToken)
    }

    /// Unauthenticated GET returning the raw body (e.g. the colleges catalog, cached to disk as-is).
    func sendRaw(path: String, query: [(String, String)] = []) async throws -> Data {
        var request = URLRequest(url: try url(for: path, query: query))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw APIError(status: status, message: nil, errorField: nil, body: data)
        }
        return data
    }

    private func perform<R: Decodable>(_ request: URLRequest, sentToken: String?) async throws -> R {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard (200..<300).contains(status) else {
            // `r.json().catch(() => ({}))` — non-JSON bodies become an empty object.
            let parsed = try? JSONDecoder().decode(ErrorBody.self, from: data)
            if status == 401, sentToken != nil, let onUnauthorized { await onUnauthorized() }
            throw APIError(status: status, message: parsed?.message, errorField: parsed?.error, body: data)
        }

        // 204 / empty body → `{}`.
        let payload = data.isEmpty ? Data("{}".utf8) : data
        do {
            return try JSONDecoder().decode(R.self, from: payload)
        } catch {
            #if DEBUG
            print("⚠️ Decoding \(R.self) from \(request.url?.path ?? "") failed: \(error)")
            #endif
            throw APIError.decoding
        }
    }

    private func url(for path: String, query: [(String, String)]) throws -> URL {
        guard var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw APIError.decoding
        }
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
            // URLComponents leaves `+` unescaped, which servers decode as a space;
            // encodeURIComponent (used by the web) escapes it.
            components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        }
        guard let url = components.url else { throw APIError.decoding }
        return url
    }

    private struct ErrorBody: Decodable {
        let message: String?
        let error: String?
    }
}
