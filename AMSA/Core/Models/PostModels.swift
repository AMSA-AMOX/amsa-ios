import Foundation

/// `PostItem` from src/components/posts/types.ts (built in src/app/api/posts/route.ts).
struct PostItem: Decodable, Sendable, Identifiable, Equatable {
    struct Author: Decodable, Sendable, Equatable {
        let id: Int
        let firstName: String?
        let lastName: String?
        let headline: String?
        let profilePic: String?
    }
    struct College: Decodable, Sendable, Equatable {
        let id: Int
        let name: String
        let logoUrl: String?
    }

    let id: Int
    var body: String
    var images: [String]
    var createdAt: String
    var appreciationCount: Int
    var hasAppreciated: Bool
    var reviewStatus: String
    var reviewedAt: String?
    var reviewNote: String?
    var topic: String?
    var author: Author?
    var college: College?

    enum CodingKeys: String, CodingKey {
        case id, body, images, createdAt, appreciationCount, hasAppreciated, reviewStatus, reviewedAt, reviewNote,
             topic, author, college
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        images = try c.decodeIfPresent([String].self, forKey: .images) ?? []
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        appreciationCount = try c.decodeIfPresent(Int.self, forKey: .appreciationCount) ?? 0
        hasAppreciated = try c.decodeIfPresent(Bool.self, forKey: .hasAppreciated) ?? false
        reviewStatus = try c.decodeIfPresent(String.self, forKey: .reviewStatus) ?? "approved"
        reviewedAt = try c.decodeIfPresent(String.self, forKey: .reviewedAt)
        reviewNote = try c.decodeIfPresent(String.self, forKey: .reviewNote)
        topic = try c.decodeIfPresent(String.self, forKey: .topic)
        author = try c.decodeIfPresent(Author.self, forKey: .author)
        college = try c.decodeIfPresent(College.self, forKey: .college)
    }

    var isApproved: Bool { reviewStatus == "approved" }
}

struct PostsResponse: Decodable, Sendable { let posts: [PostItem]? }
struct CreatePostResponse: Decodable, Sendable {
    let post: PostItem
    let requiresApproval: Bool?
}
struct AppreciateResponse: Decodable, Sendable {
    let hasAppreciated: Bool?
    let appreciationCount: Int?
}
struct FollowsResponse: Decodable, Sendable {
    let followersCount: Int?
    let followingCount: Int?
    let followingIds: [Int]?
}
struct UserCollegeResponse: Decodable, Sendable {
    struct College: Decodable, Sendable, Equatable {
        let id: Int
        let name: String
        let logoUrl: String?
    }
    let college: College?
}

enum PostsAPI {
    /// GET /api/posts
    static func list(limit: Int, creatorId: Int? = nil, includeModeration: Bool = false) -> Endpoint<PostsResponse> {
        var query: [(String, String)] = []
        if includeModeration { query.append(("includeModeration", "true")) }
        query.append(("limit", String(limit)))
        if let creatorId { query.append(("creatorId", String(creatorId))) }
        return Endpoint(path: "/api/posts", query: query)
    }

    /// POST /api/posts
    static func create(body: String, topics: [String], images: [String], collegeId: Int?) -> Endpoint<CreatePostResponse> {
        Endpoint(method: .post, path: "/api/posts", body: [
            "body": .string(body),
            "topics": .strings(topics),
            "images": .strings(images),
            "collegeId": .optional(collegeId),
        ])
    }

    static func delete(_ id: Int) -> Endpoint<Empty> { Endpoint(method: .delete, path: "/api/posts/\(id)") }
    static func helpful(_ id: Int) -> Endpoint<AppreciateResponse> { Endpoint(method: .post, path: "/api/posts/\(id)/helpful") }
    static func report(_ id: Int) -> Endpoint<Empty> { Endpoint(method: .post, path: "/api/posts/\(id)/report") }
}

enum FollowsAPI {
    static func mine() -> Endpoint<FollowsResponse> { Endpoint(path: "/api/user/follows") }
    static func follow(_ id: Int) -> Endpoint<Empty> {
        Endpoint(method: .post, path: "/api/user/follows", body: ["followingId": .int(id)])
    }
    static func unfollow(_ id: Int) -> Endpoint<Empty> { Endpoint(method: .delete, path: "/api/user/follows/\(id)") }
}

enum UserCollegeAPI {
    static func mine() -> Endpoint<UserCollegeResponse> { Endpoint(path: "/api/user/college") }
}

/// JS `\w` is ASCII-only; ICU's `\w` also matches Unicode letters, so patterns spell it out.
enum JSRegex {
    static let word = "[A-Za-z0-9_]"
    /// `[^\w]`
    static let nonWord = "[^A-Za-z0-9_]"
}

/// Topic tagging in components/posts/PostComposer.tsx.
enum PostTopics {
    /// First 3 of `topics` (POST_TOPICS) present as `#Topic` — `new RegExp(`#${t}(?=[^\\w]|$)`, "i")` —
    /// in POST_TOPICS order.
    static func derived(from body: String, topics: [String]) -> [String] {
        let found = topics.filter { topic in
            let pattern = "#\(NSRegularExpression.escapedPattern(for: topic))(?=\(JSRegex.nonWord)|$)"
            return body.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
        return Array(found.prefix(3))
    }
}
