import Foundation

/// `ShellData` from GET /api/me/shell (RPC `get_shell`).
struct ShellData: Decodable, Sendable, Equatable {
    struct Pending: Decodable, Sendable, Equatable {
        var posts: Int = 0
        var threads: Int = 0
        var verification: Int = 0
    }
    /// nil = no US Member application on file.
    var membershipStatus: String?
    var unseenNotifications: Int
    var pending: Pending
}

enum ShellAPI {
    static func shell(seenAfter: String) -> Endpoint<ShellData> {
        Endpoint(path: "/api/me/shell", query: [("seenAfter", seenAfter)])
    }
}

// Port of src/hooks/useShell.ts — one shared /api/me/shell request per minute for all chrome.
@MainActor
@Observable
final class ShellStore {
    private static let ttl: TimeInterval = 60

    private(set) var shell: ShellData?
    private var cacheKey: String?
    private var fetchedAt: Date?
    private var inFlight: Task<Void, Never>?

    private let api: APIClient
    private let tokenProvider: () -> String?

    init(api: APIClient, tokenProvider: @escaping () -> String?) {
        self.api = api
        self.tokenProvider = tokenProvider
    }

    func load(force: Bool = false) {
        guard let token = tokenProvider() else { return }
        let seenAfter = Preferences.notificationsSeen
        let key = "\(token):\(seenAfter)"
        if !force, cacheKey == key, let fetchedAt, Date().timeIntervalSince(fetchedAt) < Self.ttl { return }
        if inFlight != nil, cacheKey == key, !force { return }
        cacheKey = key
        inFlight?.cancel()
        inFlight = Task {
            do {
                let data = try await api.send(ShellAPI.shell(seenAfter: seenAfter))
                shell = data
                fetchedAt = Date()
            } catch {
                /* keep whatever we had */
            }
            inFlight = nil
        }
    }

    /// `invalidateShell()` — call after actions that change badge counts, then reload.
    func invalidate() {
        fetchedAt = nil
        load(force: true)
    }

    func reset() {
        inFlight?.cancel()
        inFlight = nil
        shell = nil
        cacheKey = nil
        fetchedAt = nil
    }
}
