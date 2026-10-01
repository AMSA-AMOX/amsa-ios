import Foundation

// Schema of `research_journal_v1` in src/app/(dashboard)/dashboard/research/compare/page.tsx
/// localStorage `research_journal_v1` — same JSON schema as the web.
struct JournalData: Codable, Equatable {
    struct CustomColumn: Codable, Equatable, Identifiable {
        var id: String
        var name: String
    }

    var rowOrder: [Int] = []
    var customColumns: [CustomColumn] = []
    var customData: [String: [String: String]] = [:]
    var statusData: [String: String] = [:]
    var notesData: [String: String] = [:]

    init() {}

    /// `loadJournal` accepts any stored object whose `rowOrder` is an array.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rowOrder = try c.decode([Int].self, forKey: .rowOrder)
        customColumns = (try? c.decodeIfPresent([CustomColumn].self, forKey: .customColumns)) ?? []
        customData = (try? c.decodeIfPresent([String: [String: String]].self, forKey: .customData)) ?? [:]
        statusData = (try? c.decodeIfPresent([String: String].self, forKey: .statusData)) ?? [:]
        notesData = (try? c.decodeIfPresent([String: String].self, forKey: .notesData)) ?? [:]
    }

    static func load() -> JournalData {
        guard let data = Preferences.journal, let parsed = try? JSONDecoder().decode(JournalData.self, from: data) else {
            return JournalData()
        }
        return parsed
    }

    func persist() { Preferences.journal = try? JSONEncoder().encode(self) }
}
