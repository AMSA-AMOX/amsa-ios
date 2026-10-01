import Foundation
@testable import AMSA

enum Fixture {
    static func decode<T: Decodable>(_ type: T.Type = T.self, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    static func decode<T: Decodable>(_ type: T.Type = T.self, object: [String: Any]) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
    }

    /// A catalog row with only the fields a test cares about; everything else is absent (→ defaults).
    static func college(_ id: Int, _ name: String, _ fields: [String: Any] = [:]) throws -> College {
        try decode(College.self, object: fields.merging(["id": id, "name": name]) { $1 })
    }

    static func date(_ iso: String) -> Date { ISODate.parse(iso)! }
}
