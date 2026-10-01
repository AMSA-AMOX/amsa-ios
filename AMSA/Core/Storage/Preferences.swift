import Foundation

/// UserDefaults replacements for the web's non-session localStorage keys.
enum Preferences {
    private static var defaults: UserDefaults { .standard }

    /// localStorage `amsa_notif_seen` — ISO timestamp of the newest seen notification.
    static var notificationsSeen: String {
        get { defaults.string(forKey: "amsa_notif_seen") ?? "" }
        set { defaults.set(newValue, forKey: "amsa_notif_seen") }
    }

    /// localStorage `research_compare_ids` — JSON `number[]`.
    static var compareIds: [Int] {
        get {
            guard let data = defaults.data(forKey: "research_compare_ids"),
                  let ids = try? JSONDecoder().decode([Int].self, from: data) else { return [] }
            return ids
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "research_compare_ids") }
    }

    static var hasCompareIds: Bool { defaults.object(forKey: "research_compare_ids") != nil }

    static func removeCompareIds() { defaults.removeObject(forKey: "research_compare_ids") }

    /// localStorage `research_journal_v1` — raw JSON (schema owned by the Compare screen).
    static var journal: Data? {
        get { defaults.data(forKey: "research_journal_v1") }
        set {
            if let newValue { defaults.set(newValue, forKey: "research_journal_v1") }
            else { defaults.removeObject(forKey: "research_journal_v1") }
        }
    }
}
