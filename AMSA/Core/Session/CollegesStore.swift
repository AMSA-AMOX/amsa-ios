import Foundation

// Port of research/use-colleges-data.ts. The web keeps the catalog in sessionStorage for
// 10 minutes; the app keeps it on disk, shows it immediately and refreshes when stale.
@MainActor
@Observable
final class CollegesStore {
    private static let ttl: TimeInterval = 10 * 60
    private static let cache = DiskCache(fileName: "research_colleges_cache_v7.json")

    private(set) var colleges: [College] = []
    private(set) var byId: [Int: College] = [:]
    private(set) var loading = true
    private(set) var error = ""

    private var fetchedAt: Date?
    private var task: Task<Void, Never>?
    private let api: APIClient

    init(api: APIClient) { self.api = api }

    func load() {
        if let fetchedAt, Date().timeIntervalSince(fetchedAt) <= Self.ttl { return }
        guard task == nil else { return }
        task = Task {
            if colleges.isEmpty, let cached = Self.cache.read() {
                if let rows = await Self.decode(cached.data) {
                    apply(rows)
                    loading = false
                    if Date().timeIntervalSince(cached.savedAt) <= Self.ttl {
                        fetchedAt = cached.savedAt
                        task = nil
                        return
                    }
                }
            }
            await fetch()
            task = nil
        }
    }

    private func fetch() async {
        do {
            let data = try await api.sendRaw(path: "/api/colleges")
            guard let rows = await Self.decode(data) else { throw APIError.decoding }
            apply(rows)
            fetchedAt = Date()
            error = ""
            Self.cache.write(data)
        } catch {
            // Keep showing a cached catalog if we have one.
            if colleges.isEmpty { self.error = "Failed to load college data" }
        }
        loading = false
    }

    private func apply(_ rows: [College]) {
        colleges = rows
        byId = Dictionary(rows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private nonisolated static func decode(_ data: Data) async -> [College]? {
        await Task.detached(priority: .userInitiated) {
            (try? JSONDecoder().decode(CollegesResponse.self, from: data))?.colleges
        }.value
    }
}
