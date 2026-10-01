import Foundation

// MARK: - Verification queue (api/admin/verification)

struct VerificationSubmission: Decodable, Sendable, Identifiable, Equatable {
    struct UserRef: Decodable, Sendable, Equatable {
        let id: Int
        let role: String?
    }

    let id: String
    let userId: Int
    let createdAt: String
    let fullName: String?
    let pronouns: String?
    let enrolledUniversity: String?
    let yearInSchool: String?
    let state: String?
    let city: String?
    let major: String?
    let expectedGraduation: String?
    let email: String?
    let socialMedia: String?
    let phone: String?
    let careerInterests: [String]
    let careerInterestsOther: String?
    let amsaInterests: [String]
    let amsaInterestsOther: String?
    let mentorshipInterest: String?
    let eventIdeas: String?
    let heardAboutAmsa: String?
    let heardAboutAmsaOther: String?
    let reviewStatus: String
    let assignedRole: String?
    let adminNote: String?
    let user: UserRef?

    enum CodingKeys: String, CodingKey {
        case id, userId, createdAt, fullName, pronouns, enrolledUniversity, yearInSchool, state, city, major,
             expectedGraduation, email, socialMedia, phone, careerInterests, careerInterestsOther, amsaInterests,
             amsaInterestsOther, mentorshipInterest, eventIdeas, heardAboutAmsa, heardAboutAmsaOther, reviewStatus,
             assignedRole, adminNote, user
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        userId = try c.decode(Int.self, forKey: .userId)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        fullName = try c.decodeIfPresent(String.self, forKey: .fullName)
        pronouns = try c.decodeIfPresent(String.self, forKey: .pronouns)
        enrolledUniversity = try c.decodeIfPresent(String.self, forKey: .enrolledUniversity)
        yearInSchool = try c.decodeIfPresent(String.self, forKey: .yearInSchool)
        state = try c.decodeIfPresent(String.self, forKey: .state)
        city = try c.decodeIfPresent(String.self, forKey: .city)
        major = try c.decodeIfPresent(String.self, forKey: .major)
        expectedGraduation = c.flexibleString(.expectedGraduation)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        socialMedia = try c.decodeIfPresent(String.self, forKey: .socialMedia)
        phone = c.flexibleString(.phone)
        careerInterests = (try? c.decodeIfPresent([String].self, forKey: .careerInterests)) ?? []
        careerInterestsOther = try c.decodeIfPresent(String.self, forKey: .careerInterestsOther)
        amsaInterests = (try? c.decodeIfPresent([String].self, forKey: .amsaInterests)) ?? []
        amsaInterestsOther = try c.decodeIfPresent(String.self, forKey: .amsaInterestsOther)
        mentorshipInterest = try c.decodeIfPresent(String.self, forKey: .mentorshipInterest)
        eventIdeas = try c.decodeIfPresent(String.self, forKey: .eventIdeas)
        heardAboutAmsa = try c.decodeIfPresent(String.self, forKey: .heardAboutAmsa)
        heardAboutAmsaOther = try c.decodeIfPresent(String.self, forKey: .heardAboutAmsaOther)
        reviewStatus = try c.decode(String.self, forKey: .reviewStatus)
        assignedRole = try c.decodeIfPresent(String.self, forKey: .assignedRole)
        adminNote = try c.decodeIfPresent(String.self, forKey: .adminNote)
        user = try? c.decodeIfPresent(UserRef.self, forKey: .user)
    }
}

struct VerificationQueueResponse: Decodable, Sendable {
    let submissions: [VerificationSubmission]?
}

// MARK: - Post approval (api/admin/posts)

struct ModerationPost: Decodable, Sendable, Identifiable, Equatable {
    struct Author: Decodable, Sendable, Equatable {
        let firstName: String?
        let lastName: String?
    }

    let id: Int
    let body: String?
    let images: [String]
    let createdAt: String
    let reviewStatus: String
    let reviewNote: String?
    let author: Author?

    enum CodingKeys: String, CodingKey { case id, body, images, createdAt, reviewStatus, reviewNote, author }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        body = try c.decodeIfPresent(String.self, forKey: .body)
        images = (try? c.decodeIfPresent([String].self, forKey: .images)) ?? []
        createdAt = try c.decode(String.self, forKey: .createdAt)
        reviewStatus = try c.decode(String.self, forKey: .reviewStatus)
        reviewNote = try c.decodeIfPresent(String.self, forKey: .reviewNote)
        author = try? c.decodeIfPresent(Author.self, forKey: .author)
    }
}

struct ModerationPostsResponse: Decodable, Sendable {
    let posts: [ModerationPost]?
}

// MARK: - Endpoints

enum AdminAPI {
    static func verification(status: String) -> Endpoint<VerificationQueueResponse> {
        Endpoint(path: "/api/admin/verification", query: [("status", status)])
    }

    /// `assignedRole: undefined` is dropped by `JSON.stringify`, so rejections omit the key.
    static func reviewVerification(_ id: String, status: String, assignedRole: String?, adminNote: String) -> Endpoint<Empty> {
        var body: [String: JSONValue] = ["reviewStatus": .string(status), "adminNote": .string(adminNote)]
        if let assignedRole { body["assignedRole"] = .string(assignedRole) }
        return Endpoint(method: .patch, path: "/api/admin/verification/\(id)", body: .object(body))
    }

    static func posts(status: String) -> Endpoint<ModerationPostsResponse> {
        Endpoint(path: "/api/admin/posts", query: [("status", status)])
    }

    static func reviewPost(_ id: Int, status: String, note: String) -> Endpoint<Empty> {
        Endpoint(method: .patch, path: "/api/admin/posts/\(id)",
                 body: ["reviewStatus": .string(status), "reviewNote": .string(note)])
    }
}
