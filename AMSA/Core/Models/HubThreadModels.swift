import Foundation

/// `ThreadUser` on the threads page.
struct ThreadUser: Decodable, Sendable, Equatable, Hashable {
    let id: Int
    let firstName: String?
    let lastName: String?
    let profilePic: String?

    var fullName: String { "\(firstName ?? "") \(lastName ?? "")".trimmed }
    var initials: String { .initials(firstName, lastName) }
}

/// `HubThread` (GET /api/hub-threads).
struct HubThread: Decodable, Sendable, Identifiable, Equatable {
    let id: Int
    let title: String
    let body: String?
    let category: String
    let categoryDomain: String?
    let images: [String]
    let status: String?
    let isAnon: Bool
    let asker: ThreadUser?
    let commentCount: Int
    let upvoteCount: Int
    let hasUpvoted: Bool
    let approvedAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, body, category, categoryDomain, images, status, isAnon, asker, commentCount, upvoteCount,
             hasUpvoted, approvedAt, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try c.decodeIfPresent(String.self, forKey: .body)
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "general"
        categoryDomain = try c.decodeIfPresent(String.self, forKey: .categoryDomain)
        images = try c.decodeIfPresent([String].self, forKey: .images) ?? []
        status = try c.decodeIfPresent(String.self, forKey: .status)
        isAnon = try c.decodeIfPresent(Bool.self, forKey: .isAnon) ?? false
        asker = try c.decodeIfPresent(ThreadUser.self, forKey: .asker)
        commentCount = try c.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
        upvoteCount = try c.decodeIfPresent(Int.self, forKey: .upvoteCount) ?? 0
        hasUpvoted = try c.decodeIfPresent(Bool.self, forKey: .hasUpvoted) ?? false
        approvedAt = try c.decodeIfPresent(String.self, forKey: .approvedAt)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }

    var askerName: String {
        isAnon ? "Anonymous" : (asker.map { $0.fullName } ?? "Member")
    }
}

/// `HubComment` (GET /api/hub-threads/{id}) — replies are one level deep.
struct HubComment: Decodable, Sendable, Identifiable, Equatable {
    let id: Int
    let content: String
    let isAnon: Bool
    let parentId: Int?
    let author: ThreadUser?
    let createdAt: String
    var upvoteCount: Int
    var hasUpvoted: Bool
    var replies: [HubComment]

    enum CodingKeys: String, CodingKey {
        case id, content, isAnon, parentId, author, createdAt, upvoteCount, hasUpvoted, replies
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        isAnon = try c.decodeIfPresent(Bool.self, forKey: .isAnon) ?? false
        parentId = try c.decodeIfPresent(Int.self, forKey: .parentId)
        author = try c.decodeIfPresent(ThreadUser.self, forKey: .author)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        upvoteCount = try c.decodeIfPresent(Int.self, forKey: .upvoteCount) ?? 0
        hasUpvoted = try c.decodeIfPresent(Bool.self, forKey: .hasUpvoted) ?? false
        replies = try c.decodeIfPresent([HubComment].self, forKey: .replies) ?? []
    }

    var authorName: String {
        isAnon ? "Anonymous" : (author.map { $0.fullName } ?? "Member")
    }
}

struct HubThreadsResponse: Decodable, Sendable {
    let threads: [HubThread]?
    let nextCursor: String?
}
struct HubThreadDetailResponse: Decodable, Sendable {
    let comments: [HubComment]?
}
struct UpvoteResponse: Decodable, Sendable {
    let upvoteCount: Int
    let hasUpvoted: Bool
}
struct CreateCommentResponse: Decodable, Sendable {
    let comment: HubComment
}

enum HubThreadsAPI {
    static func list(limit: Int = 20, cursor: String? = nil) -> Endpoint<HubThreadsResponse> {
        var query = [("limit", String(limit))]
        if let cursor { query.append(("cursor", cursor)) }
        return Endpoint(path: "/api/hub-threads", query: query)
    }

    static func pending() -> Endpoint<HubThreadsResponse> {
        Endpoint(path: "/api/hub-threads", query: [("view", "pending")])
    }

    static func detail(_ id: Int) -> Endpoint<HubThreadDetailResponse> { Endpoint(path: "/api/hub-threads/\(id)") }

    static func upvote(_ id: Int) -> Endpoint<UpvoteResponse> { Endpoint(method: .post, path: "/api/hub-threads/\(id)/upvote") }

    static func comment(threadId: Int, content: String, parentId: Int? = nil) -> Endpoint<CreateCommentResponse> {
        var body: [String: JSONValue] = ["content": .string(content), "isAnon": false]
        if let parentId { body["parentId"] = .int(parentId) }
        return Endpoint(method: .post, path: "/api/hub-threads/\(threadId)/comments", body: .object(body))
    }

    static func upvoteComment(threadId: Int, commentId: Int) -> Endpoint<UpvoteResponse> {
        Endpoint(method: .post, path: "/api/hub-threads/\(threadId)/comments/\(commentId)/upvote")
    }

    static func delete(_ id: Int) -> Endpoint<Empty> { Endpoint(method: .delete, path: "/api/hub-threads/\(id)") }

    static func create(title: String, body: String, category: String, categoryDomain: String?, images: [String],
                       isAnon: Bool) -> Endpoint<Empty> {
        Endpoint(method: .post, path: "/api/hub-threads", body: [
            "title": .string(title), "body": .string(body), "category": .string(category),
            "categoryDomain": .optional(categoryDomain), "images": .strings(images), "isAnon": .bool(isAnon),
        ])
    }

    static func moderate(_ id: Int, status: String) -> Endpoint<Empty> {
        Endpoint(method: .patch, path: "/api/hub-threads/\(id)", body: ["status": .string(status)])
    }
}
