import Foundation

/// A value some routes return as a string and others as a number
/// (e.g. `graduationYear`, `startYear`). Stored as the string JS would render.
struct FlexibleString: Codable, Sendable, Hashable, CustomStringConvertible, ExpressibleByStringLiteral {
    let value: String

    init(_ value: String) { self.value = value }
    init(stringLiteral value: String) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            value = s
        } else if let i = try? container.decode(Int.self) {
            value = String(i)
        } else if let d = try? container.decode(Double.self) {
            value = JSNumber.string(d)
        } else if let b = try? container.decode(Bool.self) {
            value = b ? "true" : "false"
        } else {
            throw DecodingError.typeMismatch(
                String.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected string or number"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    var description: String { value }
}

/// A number some routes return as a JSON string (Postgres `numeric`).
struct FlexibleDouble: Codable, Sendable, Hashable {
    let value: Double

    init(_ value: Double) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let d = try? container.decode(Double.self) {
            value = d
        } else if let s = try? container.decode(String.self), let d = Double(s) {
            value = d
        } else {
            throw DecodingError.typeMismatch(
                Double.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected number"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

enum JSNumber {
    /// `String(n)` in JS: integers without a trailing `.0`.
    static func string(_ d: Double) -> String {
        if d.rounded() == d, abs(d) < 1e15 { return String(Int(d)) }
        return String(d)
    }
}

extension KeyedDecodingContainer {
    /// Decodes a string-or-number field as a string; nil when absent or null.
    func flexibleString(_ key: Key) -> String? {
        (try? decodeIfPresent(FlexibleString.self, forKey: key))?.value
    }
}
