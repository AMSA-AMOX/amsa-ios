import Foundation

/// JavaScript formatting calls used across the web pages.
enum Formatters {
    private static let enUS = Locale(identifier: "en_US")

    /// `Math.round(n)` — rounds half toward +∞ (Swift's default rounds half away from zero).
    static func jsRound(_ n: Double) -> Double { (n + 0.5).rounded(.down) }

    /// `n.toLocaleString("en-US")` for integers: "12,345".
    static func grouped(_ n: Double) -> String {
        n.formatted(.number.locale(enUS).precision(.fractionLength(0)).grouping(.automatic))
    }

    /// `n.toLocaleString()` with the device locale (up to 3 fraction digits, like JS).
    static func localeNumber(_ n: Double) -> String {
        n.formatted(.number.precision(.fractionLength(0...3)))
    }

    /// `fmt` on research/college/compare pages: `"$" + Math.round(n).toLocaleString("en-US")`.
    static func money(_ n: Double) -> String { "$" + grouped(jsRound(n)) }

    /// `pct` on the college detail page: `Math.round(n) + "%"`.
    static func percent(_ n: Double) -> String { JSNumber.string(jsRound(n)) + "%" }

    /// `String(n)` for a raw number, e.g. `{college.internationalPercent}%` renders "12.3%".
    static func raw(_ n: Double) -> String { JSNumber.string(n) }

    /// `new Date(iso).toLocaleDateString()` — numeric date in the device locale ("9/30/2026" in en-US).
    static func localeDate(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.defaultDigits).day(.defaultDigits))
    }

    /// `new Date(iso).toLocaleString()` — numeric date + time with seconds in the device locale.
    static func localeDateTime(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.defaultDigits).day(.defaultDigits).hour().minute().second()).browserSpaces
    }

    /// `toLocaleDateString(undefined, { month: "long", year: "numeric" })` — "September 2026".
    static func monthYear(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }

    /// `toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })`.
    static func hourMinute(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .abbreviated)).minute(.twoDigits)).browserSpaces
    }
}

extension String {
    /// Browsers print a regular space before AM/PM where Apple's ICU emits U+202F.
    var browserSpaces: String { replacingOccurrences(of: "\u{202F}", with: " ") }

    /// Uppercased first letters of first and last name — the web's `initials` pattern.
    static func initials(_ first: String?, _ last: String?) -> String {
        "\(first?.first.map(String.init) ?? "")\(last?.first.map(String.init) ?? "")".uppercased()
    }

    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension Optional where Wrapped == String {
    /// JS truthiness for a nullable string: nil for null, undefined and "".
    var nilIfEmpty: String? { self?.nilIfEmpty }
}

/// `onChange` with the text trimmed to a max length (`maxLength` attribute).
extension String {
    func limited(to max: Int) -> String { count > max ? String(prefix(max)) : self }

    /// `maxLength` semantics: the DOM counts UTF-16 code units.
    func limitedUTF16(to max: Int) -> String {
        guard utf16.count > max else { return self }
        var result = ""
        var units = 0
        for character in self {
            let n = character.utf16.count
            if units + n > max { break }
            result.append(character)
            units += n
        }
        return result
    }
}
