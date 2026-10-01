import Foundation

/// A place (`place_reviews`) or college (`college_reviews`) review.
struct Review: Decodable, Sendable, Identifiable, Equatable {
    struct Author: Decodable, Sendable, Equatable {
        let id: Int?
        let firstName: String?
        let lastName: String?
        let profilePic: String?
    }

    let id: String
    let content: String
    let images: [String]
    let createdAt: String
    let userId: Int?
    let author: Author?
    var helpfulCount: Int
    var hasHelpful: Bool

    enum CodingKeys: String, CodingKey {
        case id, content, images, helpfulCount, hasHelpful
        case createdAt = "created_at"
        case userId = "user_id"
        case author = "Users"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(FlexibleString.self, forKey: .id).value
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        images = try c.decodeIfPresent([String].self, forKey: .images) ?? []
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        userId = try c.decodeIfPresent(Int.self, forKey: .userId)
        author = try c.decodeIfPresent(Author.self, forKey: .author)
        // The POST response omits these; the web adds 0 / false.
        helpfulCount = try c.decodeIfPresent(Int.self, forKey: .helpfulCount) ?? 0
        hasHelpful = try c.decodeIfPresent(Bool.self, forKey: .hasHelpful) ?? false
    }
}

struct ReviewsResponse: Decodable, Sendable { let reviews: [Review]? }
struct CreateReviewResponse: Decodable, Sendable { let review: Review?; let message: String? }
struct ReviewHelpfulResponse: Decodable, Sendable { let hasHelpful: Bool?; let helpfulCount: Int? }

/// Everything that differs between the Places and College review columns.
struct ReviewsConfig {
    let list: (_ authenticated: Bool) -> Endpoint<ReviewsResponse>
    let create: (_ content: String, _ images: [String]) -> Endpoint<CreateReviewResponse>
    let delete: (_ id: String) -> Endpoint<Empty>
    let helpful: (_ id: String) -> Endpoint<ReviewHelpfulResponse>
    let placeholder: String
    let prompts: [String]
    let uploadPath: (_ userId: Int, _ index: Int) -> String

    static func place(abbr: String, stateName: String) -> ReviewsConfig {
        let upper = abbr.uppercased()
        return ReviewsConfig(
            list: { auth in Endpoint(path: "/api/places/reviews", query: [("stateAbbr", upper)], authenticated: auth) },
            create: { content, images in
                Endpoint(method: .post, path: "/api/places/reviews",
                         body: ["stateAbbr": .string(upper), "content": .string(content), "images": .strings(images)])
            },
            delete: { id in Endpoint(method: .delete, path: "/api/places/reviews/\(id)") },
            helpful: { id in Endpoint(method: .post, path: "/api/places/reviews/\(id)/helpful") },
            placeholder: "Share your experience living in \(stateName)…",
            prompts: StaticData.constants.placeReviewPrompts,
            uploadPath: { userId, index in UploadPath.placeReview(userId: userId, index: index) }
        )
    }

    static func college(id: Int, name: String) -> ReviewsConfig {
        ReviewsConfig(
            list: { auth in Endpoint(path: "/api/colleges/reviews", query: [("collegeId", String(id))], authenticated: auth) },
            create: { content, images in
                Endpoint(method: .post, path: "/api/colleges/reviews",
                         body: ["collegeId": .int(id), "content": .string(content), "images": .strings(images)])
            },
            delete: { reviewId in Endpoint(method: .delete, path: "/api/colleges/reviews/\(reviewId)") },
            helpful: { reviewId in Endpoint(method: .post, path: "/api/colleges/reviews/\(reviewId)/helpful") },
            placeholder: "Share your experience at \(name)…",
            prompts: StaticData.constants.collegeReviewPrompts,
            uploadPath: { userId, index in UploadPath.collegeReview(userId: userId, index: index) }
        )
    }
}
