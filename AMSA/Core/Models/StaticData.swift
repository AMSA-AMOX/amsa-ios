import Foundation

/// `StateInfo` from research/state-data.ts merged with `STATE_SVG` (places/page.tsx)
/// and `FIPS_TO_ABBR`. Generated into Resources/Data/states.json by tools/extract-data.ts.
struct StateInfo: Decodable, Sendable, Identifiable, Hashable {
    enum CostTier: String, Decodable, Sendable, CaseIterable {
        case veryHigh = "very_high", high, moderate, affordable
    }
    enum Transit: String, Decodable, Sendable, CaseIterable {
        case excellent, good, limited, poor
    }
    struct Photo: Decodable, Sendable, Hashable {
        let file: String
        let location: String
    }

    let abbr: String
    let fips: String
    let name: String
    let cities: [String]
    let colTier: CostTier
    let monthlyRent: String
    let climate: String
    let tempRange: String
    let publicTransport: Transit
    let transitInfo: String
    let places: [String]
    let photo: Photo

    var id: String { abbr }
}

struct AppConstants: Decodable, Sendable {
    let standardFields: [String]
    let postTopics: [String]
    let placeReviewPrompts: [String]
    let collegeReviewPrompts: [String]
}

struct LogoAliases: Decodable, Sendable {
    /// Ordered [name, domain] pairs (insertion order matters for prefix matching).
    let schools: [[String]]
    let companies: [[String]]
}

struct USMapData: Decodable, Sendable {
    struct Shape: Decodable, Sendable {
        let fips: String
        let abbr: String
        let d: String
        let cx: Double?
        let cy: Double?
    }
    let width: Double
    let height: Double
    let states: [Shape]
}

/// Bundled datasets, decoded once.
enum StaticData {
    static let states: [StateInfo] = load("states")
    static let statesByAbbr: [String: StateInfo] = Dictionary(uniqueKeysWithValues: states.map { ($0.abbr, $0) })
    static let constants: AppConstants = load("constants")
    static let logoAliases: LogoAliases = load("logo-aliases")
    static let usMap: USMapData = load("us-states")

    /// `STATE_NAMES` (research/state-names.ts) — identical to STATE_DATA names (asserted by the extractor).
    static func stateName(_ abbr: String) -> String? { statesByAbbr[abbr]?.name }

    private static func load<T: Decodable>(_ name: String) -> T {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(T.self, from: data)
        else { fatalError("Bundled data \(name).json missing or invalid") }
        return value
    }
}
