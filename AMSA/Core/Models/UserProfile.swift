import Foundation

/// `user` from GET /api/auth/me and PATCH /api/user/profile (same shape; `roles` only from /me).
struct UserProfile: Decodable, Sendable, Equatable {
    var id: Int
    var email: String?
    var firstName: String?
    var lastName: String?
    var role: String?
    var acceptanceStatus: String?
    var profilePic: String?
    var level: FlexibleString?
    var headline: String?
    var bio: String?
    var createdAt: String?
    var phoneNumber: String?
    var city: String?
    var state: String?
    var schoolName: String?
    var schoolEmail: String?
    var major: String?
    var degreeLevel: String?
    var graduationYear: FlexibleString?
    var schoolYear: String?
    var personalEmail: String?
    var x: String?
    var facebook: String?
    var instagram: String?
    var linkedin: String?
    var logoDomain: String?
    var collegeId: Int?
    var roles: [String]?
}

struct MeResponse: Decodable, Sendable {
    let user: UserProfile
}
