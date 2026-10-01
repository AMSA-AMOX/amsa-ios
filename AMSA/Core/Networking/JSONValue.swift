import Foundation

/// Request bodies are built as JSON values so presence and explicit `null`
/// match the web payloads exactly (synthesized Encodable drops nil keys).
enum JSONValue: Encodable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case int(Int)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .number(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        }
    }
}

extension JSONValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral,
    ExpressibleByNilLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral, ExpressibleByFloatLiteral
{
    init(stringLiteral value: String) { self = .string(value) }
    init(integerLiteral value: Int) { self = .int(value) }
    init(floatLiteral value: Double) { self = .number(value) }
    init(booleanLiteral value: Bool) { self = .bool(value) }
    init(nilLiteral: ()) { self = .null }
    init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }
}

extension JSONValue {
    /// `.null` for nil, otherwise the wrapped value.
    static func optional(_ value: String?) -> JSONValue { value.map(JSONValue.string) ?? .null }
    static func optional(_ value: Int?) -> JSONValue { value.map(JSONValue.int) ?? .null }
    static func optional(_ value: Double?) -> JSONValue { value.map(JSONValue.number) ?? .null }
    static func strings(_ values: [String]) -> JSONValue { .array(values.map(JSONValue.string)) }
}
