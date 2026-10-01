import Foundation

/// The session user stored alongside the token — `User` in src/context/AuthContext.tsx.
struct AuthUser: Codable, Sendable, Equatable {
    var id: Int
    var email: String
    var role: String
    var roles: [String]
    var firstName: String
    var lastName: String
    var acceptanceStatus: String
    var profilePic: String?
    var level: FlexibleString?
    var bio: String?

    var fullName: String { "\(firstName) \(lastName)" }
    var initials: String { .initials(firstName, lastName) }
}

/// POST /api/auth/login and /api/auth/signup response.
struct AuthResponse: Decodable, Sendable {
    let message: String?
    let user: AuthUser
    let token: String
}

/// localStorage `amsa_auth` shape: `{ token, user }`.
struct StoredSession: Codable, Sendable, Equatable {
    var token: String
    var user: AuthUser
}

enum Role {
    static let admin = "admin"
    static let boardMember = "board_member"
    static let ambassador = "ambassador"
    static let usMember = "us_member"
    static let alum = "alum"
    static let member = "member"

    /// `getRoleLabel` in src/lib/auth.ts.
    static func label(_ role: String?) -> String {
        switch role {
        case admin: "Admin"
        case boardMember: "Board Member"
        case ambassador: "Ambassador"
        case usMember: "US Member"
        case alum: "Alum"
        default: "Member"
        }
    }
}
