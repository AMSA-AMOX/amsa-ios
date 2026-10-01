import Foundation

/// Reads (does not verify) the claims of the site's HS256 token: `{ id, role, iat, exp }`.
struct JWTClaims: Decodable, Sendable, Equatable {
    let id: Int
    let role: String
    let iat: Double?
    let exp: Double?

    init?(token: String) {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64), let claims = try? JSONDecoder().decode(JWTClaims.self, from: data)
        else { return nil }
        self = claims
    }

    func isExpired(at now: Date = .now) -> Bool {
        guard let exp else { return false }
        return now.timeIntervalSince1970 >= exp
    }
}
