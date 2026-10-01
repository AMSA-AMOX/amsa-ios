import Foundation

/// Parses API timestamps with the same semantics as JavaScript's `new Date(string)`:
/// - explicit `Z` / `±hh:mm` offset → absolute instant
/// - date-time without offset → device-local time
/// - date only (`yyyy-mm-dd`) → UTC midnight
enum ISODate {
    private static let regex = try! NSRegularExpression(
        pattern: #"^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?)?\s*(Z|[+-]\d{2}(?::?\d{2})?)?$"#,
        options: [.caseInsensitive]
    )

    static func parse(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let ns = string as NSString
        guard let match = regex.firstMatch(in: string, range: NSRange(location: 0, length: ns.length)) else { return nil }
        func group(_ i: Int) -> String? {
            let r = match.range(at: i)
            return r.location == NSNotFound ? nil : ns.substring(with: r)
        }
        guard let year = Int(group(1) ?? ""), let month = Int(group(2) ?? ""), let day = Int(group(3) ?? "") else {
            return nil
        }
        let hasTime = group(4) != nil
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = Int(group(4) ?? "0")
        components.minute = Int(group(5) ?? "0")
        components.second = Int(group(6) ?? "0")
        // JS keeps millisecond precision; extra digits are truncated.
        if let fraction = group(7) {
            let millis = Int(String((fraction + "000").prefix(3))) ?? 0
            components.nanosecond = millis * 1_000_000
        }

        var calendar = Calendar(identifier: .gregorian)
        if let offset = group(8) {
            calendar.timeZone = timeZone(forOffset: offset) ?? TimeZone(secondsFromGMT: 0)!
        } else if hasTime {
            calendar.timeZone = .current
        } else {
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        }
        return calendar.date(from: components)
    }

    private static func timeZone(forOffset offset: String) -> TimeZone? {
        if offset.uppercased() == "Z" { return TimeZone(secondsFromGMT: 0) }
        let sign = offset.hasPrefix("-") ? -1 : 1
        let digits = offset.dropFirst().replacingOccurrences(of: ":", with: "")
        guard digits.count == 2 || digits.count == 4 else { return nil }
        let hours = Int(digits.prefix(2)) ?? 0
        let minutes = digits.count == 4 ? Int(digits.suffix(2)) ?? 0 : 0
        return TimeZone(secondsFromGMT: sign * (hours * 3600 + minutes * 60))
    }

    /// `new Date().toISOString()` — UTC with milliseconds and `Z`.
    static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}
