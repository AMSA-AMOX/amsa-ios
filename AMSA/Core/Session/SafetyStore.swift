import Foundation

/// Something a member can report (POST /api/reports `targetType` + `targetId`).
enum ReportTarget: Hashable, Sendable {
    case post(Int)
    case hubThread(Int)
    case hubComment(Int)
    case collegeReview(String)
    case placeReview(String)
    case question(Int)
    case user(Int)

    var type: String {
        switch self {
        case .post: "post"
        case .hubThread: "hub_thread"
        case .hubComment: "hub_comment"
        case .collegeReview: "college_review"
        case .placeReview: "place_review"
        case .question: "question"
        case .user: "user"
        }
    }

    var id: String {
        switch self {
        case .post(let id), .hubThread(let id), .hubComment(let id), .question(let id), .user(let id): String(id)
        case .collegeReview(let id), .placeReview(let id): id
        }
    }

    /// "post", "thread", … for "Report this post".
    var noun: String {
        switch self {
        case .post: "post"
        case .hubThread: "thread"
        case .hubComment: "comment"
        case .collegeReview, .placeReview: "review"
        case .question: "message"
        case .user: "member"
        }
    }
}

/// `REPORT_REASONS` in src/lib/reports.ts.
enum ReportReason: String, CaseIterable, Identifiable, Sendable {
    case spam, harassment, hate, sexual, violence
    case selfHarm = "self_harm"
    case misinformation, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spam: "Spam or scam"
        case .harassment: "Harassment or bullying"
        case .hate: "Hate speech"
        case .sexual: "Sexual content"
        case .violence: "Violence or threats"
        case .selfHarm: "Self-harm"
        case .misinformation: "False information"
        case .other: "Something else"
        }
    }
}

/// A report about to be filed, with the author so the sheet can offer to block them too.
struct ReportRequest: Identifiable, Sendable {
    let target: ReportTarget
    /// nil for anonymous content.
    var author: BlockCandidate?
    var id: String { "\(target.type):\(target.id)" }
}

/// A member who can be blocked from a menu.
struct BlockCandidate: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String

    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }
}

struct BlockedMember: Decodable, Sendable, Identifiable, Equatable {
    let id: Int
    let firstName: String?
    let lastName: String?
    let profilePic: String?
    let blockedAt: String?

    var fullName: String { "\(firstName ?? "") \(lastName ?? "")".trimmed }
    var initials: String { .initials(firstName, lastName) }
}

enum SafetyAPI {
    struct BlocksResponse: Decodable, Sendable { let blocks: [BlockedMember]? }
    struct TermsResponse: Decodable, Sendable { let termsAcceptedAt: String? }

    static func report(_ target: ReportTarget, reason: ReportReason, details: String) -> Endpoint<Empty> {
        var body: [String: JSONValue] = [
            "targetType": .string(target.type), "targetId": .string(target.id), "reason": .string(reason.rawValue),
        ]
        if !details.trimmed.isEmpty { body["details"] = .string(details.trimmed) }
        return Endpoint(method: .post, path: "/api/reports", body: .object(body))
    }

    static func blocks() -> Endpoint<BlocksResponse> { Endpoint(path: "/api/user/blocks") }

    static func block(_ userId: Int) -> Endpoint<Empty> {
        Endpoint(method: .post, path: "/api/user/blocks", body: ["userId": .int(userId)])
    }

    static func unblock(_ userId: Int) -> Endpoint<Empty> {
        Endpoint(method: .delete, path: "/api/user/blocks/\(userId)")
    }

    static func acceptTerms() -> Endpoint<TermsResponse> { Endpoint(method: .post, path: "/api/user/terms") }
}

/// Who the signed-in member has blocked, so blocked members' content disappears from lists right away
/// (the server hides it on the next load, in both directions).
@MainActor
@Observable
final class SafetyStore {
    private(set) var blockedIds: Set<Int> = []
    private var loadedFor: String?

    private let api: APIClient
    private let tokenProvider: () -> String?

    init(api: APIClient, tokenProvider: @escaping () -> String?) {
        self.api = api
        self.tokenProvider = tokenProvider
    }

    func isHidden(_ userId: Int?) -> Bool {
        guard let userId else { return false }
        return blockedIds.contains(userId)
    }

    func load() {
        guard let token = tokenProvider(), loadedFor != token else { return }
        loadedFor = token
        Task {
            // An older server has no blocks API yet; nothing is blocked then.
            if let blocks = try? await api.send(SafetyAPI.blocks()).blocks {
                blockedIds = Set(blocks.map(\.id))
            }
        }
    }

    func report(_ request: ReportRequest, reason: ReportReason, details: String) async throws {
        _ = try await api.send(SafetyAPI.report(request.target, reason: reason, details: details))
    }

    func block(_ userId: Int) async throws {
        _ = try await api.send(SafetyAPI.block(userId))
        blockedIds.insert(userId)
    }

    func unblock(_ userId: Int) async throws {
        _ = try await api.send(SafetyAPI.unblock(userId))
        blockedIds.remove(userId)
    }

    func reset() {
        blockedIds = []
        loadedFor = nil
    }
}
