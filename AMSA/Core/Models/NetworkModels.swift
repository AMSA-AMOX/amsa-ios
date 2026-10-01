import Foundation

/// `SearchableMember` (RPC `get_network_members`).
struct NetworkMember: Decodable, Sendable, Identifiable, Equatable {
    let id: Int
    let firstName: String?
    let lastName: String?
    let profilePic: String?
    let schoolName: String?
    let graduationYear: FlexibleString?
    let role: String?
    let logoDomain: String?
    var followersCount: Int
    let followingCount: Int?
    let mutualCount: Int
    var isFollowing: Bool

    enum CodingKeys: String, CodingKey {
        case id, firstName, lastName, profilePic, schoolName, graduationYear, role, logoDomain, followersCount,
             followingCount, mutualCount, isFollowing
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try c.decodeIfPresent(String.self, forKey: .lastName)
        profilePic = try c.decodeIfPresent(String.self, forKey: .profilePic)
        schoolName = try c.decodeIfPresent(String.self, forKey: .schoolName)
        graduationYear = try c.decodeIfPresent(FlexibleString.self, forKey: .graduationYear)
        role = try c.decodeIfPresent(String.self, forKey: .role)
        logoDomain = try c.decodeIfPresent(String.self, forKey: .logoDomain)
        followersCount = try c.decodeIfPresent(Int.self, forKey: .followersCount) ?? 0
        followingCount = try c.decodeIfPresent(Int.self, forKey: .followingCount)
        mutualCount = try c.decodeIfPresent(Int.self, forKey: .mutualCount) ?? 0
        isFollowing = try c.decodeIfPresent(Bool.self, forKey: .isFollowing) ?? false
    }
}

struct NetworkMembersResponse: Decodable, Sendable { let users: [NetworkMember]? }

/// `Experience` rows (`to_jsonb` of Experiences).
struct Experience: Decodable, Sendable, Identifiable, Equatable {
    let id: Int
    let userId: Int?
    let jobTitle: String
    let company: String
    let companyUrl: String?
    let logoDomain: String?
    let employmentType: String?
    let startMonth: String?
    let startYear: FlexibleString?
    let endMonth: String?
    let endYear: FlexibleString?
    let currentlyWorking: Bool
    let location: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, userId, jobTitle, company, companyUrl, logoDomain, employmentType, startMonth, startYear, endMonth,
             endYear, currentlyWorking, location, description
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        userId = try c.decodeIfPresent(Int.self, forKey: .userId)
        jobTitle = try c.decodeIfPresent(String.self, forKey: .jobTitle) ?? ""
        company = try c.decodeIfPresent(String.self, forKey: .company) ?? ""
        companyUrl = try c.decodeIfPresent(String.self, forKey: .companyUrl)
        logoDomain = try c.decodeIfPresent(String.self, forKey: .logoDomain)
        employmentType = try c.decodeIfPresent(String.self, forKey: .employmentType)
        startMonth = try c.decodeIfPresent(String.self, forKey: .startMonth)
        startYear = try c.decodeIfPresent(FlexibleString.self, forKey: .startYear)
        endMonth = try c.decodeIfPresent(String.self, forKey: .endMonth)
        endYear = try c.decodeIfPresent(FlexibleString.self, forKey: .endYear)
        currentlyWorking = try c.decodeIfPresent(Bool.self, forKey: .currentlyWorking) ?? false
        location = try c.decodeIfPresent(String.self, forKey: .location)
        description = try c.decodeIfPresent(String.self, forKey: .description)
    }
}

/// GET /api/user/network/{id}
struct NetworkProfileResponse: Decodable, Sendable {
    struct User: Decodable, Sendable, Equatable {
        let id: Int
        let firstName: String?
        let lastName: String?
        let role: String?
        let roles: [String]?
        let profilePic: String?
        let bio: String?
        let schoolName: String?
        let schoolEmail: String?
        let major: String?
        let degreeLevel: String?
        let schoolYear: String?
        let graduationYear: FlexibleString?
        let linkedin: String?
        let instagram: String?
        let facebook: String?
        let x: String?
        let logoDomain: String?
        let collegeId: Int?
        var followersCount: Int?
        let followingCount: Int?
        var isFollowing: Bool?

        var displayName: String { "\(firstName ?? "") \(lastName ?? "")".trimmed }
    }
    let user: User?
    let experiences: [Experience]?
}

/// Direct Q&A `ThreadItem` (the `/api/threads` routes).
struct QAThread: Decodable, Sendable, Identifiable, Equatable {
    let id: Int
    let question: String
    var answer: String?
    let answeredAt: String?
    let createdAt: String
    var status: String
    var isAnonymous: Bool
    let asker: ThreadUser?
    let recipient: ThreadUser?

    enum CodingKeys: String, CodingKey {
        case id, question, answer, answeredAt, createdAt, status, isAnonymous, asker, recipient
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        question = try c.decodeIfPresent(String.self, forKey: .question) ?? ""
        answer = try c.decodeIfPresent(String.self, forKey: .answer)
        answeredAt = try c.decodeIfPresent(String.self, forKey: .answeredAt)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "answered"
        isAnonymous = try c.decodeIfPresent(Bool.self, forKey: .isAnonymous) ?? false
        asker = try c.decodeIfPresent(ThreadUser.self, forKey: .asker)
        recipient = try c.decodeIfPresent(ThreadUser.self, forKey: .recipient)
    }
}

struct QAThreadsResponse: Decodable, Sendable { let threads: [QAThread]? }
struct QAThreadResponse: Decodable, Sendable { let thread: QAThread? }

/// PATCH `{isAnonymous}` returns only `{ thread: { id, isAnonymous } }`.
struct QAThreadAnonymityResponse: Decodable, Sendable {
    struct Thread: Decodable, Sendable { let id: Int; let isAnonymous: Bool? }
    let thread: Thread?
}

enum NetworkAPI {
    static func discovery(limit: Int = 80) -> Endpoint<NetworkMembersResponse> {
        Endpoint(path: "/api/user/network", query: [("limit", String(limit))])
    }
    static func search(_ q: String, limit: Int = 80) -> Endpoint<NetworkMembersResponse> {
        Endpoint(path: "/api/user/network/search", query: [("q", q), ("limit", String(limit))])
    }
    static func profile(_ id: Int) -> Endpoint<NetworkProfileResponse> { Endpoint(path: "/api/user/network/\(id)") }
}

enum QAThreadsAPI {
    static func profile(_ userId: Int) -> Endpoint<QAThreadsResponse> { Endpoint(path: "/api/threads/profile/\(userId)") }
    static func inbox() -> Endpoint<QAThreadsResponse> { Endpoint(path: "/api/threads", query: [("view", "inbox")]) }
    static func ask(recipientId: Int, question: String) -> Endpoint<Empty> {
        Endpoint(method: .post, path: "/api/threads",
                 body: ["recipientId": .int(recipientId), "question": .string(question), "isPublic": true])
    }
    static func answer(_ id: Int, answer: String, isAnonymous: Bool? = nil) -> Endpoint<QAThreadResponse> {
        var body: [String: JSONValue] = ["answer": .string(answer)]
        if let isAnonymous { body["isAnonymous"] = .bool(isAnonymous) }
        return Endpoint(method: .patch, path: "/api/threads/\(id)", body: .object(body))
    }
    static func setAnonymous(_ id: Int, _ value: Bool) -> Endpoint<QAThreadAnonymityResponse> {
        Endpoint(method: .patch, path: "/api/threads/\(id)", body: ["isAnonymous": .bool(value)])
    }
    static func delete(_ id: Int) -> Endpoint<Empty> { Endpoint(method: .delete, path: "/api/threads/\(id)") }
}
