import Foundation
import Testing
@testable import AMSA

@Suite("Formatters — JS number/string semantics")
struct FormattersTests {
    @Test func mathRoundRoundsHalfTowardPositiveInfinity() {
        #expect(Formatters.jsRound(2.5) == 3)
        #expect(Formatters.jsRound(-2.5) == -2)
        #expect(Formatters.jsRound(2.4999) == 2)
    }

    @Test func money() {
        #expect(Formatters.money(58_000) == "$58,000")
        #expect(Formatters.money(1234.5) == "$1,235")
        #expect(Formatters.money(0) == "$0")
        #expect(Formatters.money(1_250_000.49) == "$1,250,000")
    }

    @Test func percentAndRaw() {
        #expect(Formatters.percent(12.5) == "13%")
        #expect(Formatters.raw(12.3) == "12.3")
        #expect(Formatters.raw(7) == "7")
    }

    @Test func stringHelpers() {
        #expect("9:05\u{202F}AM".browserSpaces == "9:05 AM")
        #expect(String.initials("telmen", "bayar") == "TB")
        #expect(String.initials(nil, "b") == "B")
        #expect("  a b \n".trimmed == "a b")
        #expect("".nilIfEmpty == nil)
        #expect((nil as String?).nilIfEmpty == nil)
        #expect(("x" as String?).nilIfEmpty == "x")
    }

    @Test func maxLengthCountsUTF16Units() {
        #expect("ab😀c".limitedUTF16(to: 3) == "ab") // the emoji is two units and would overflow
        #expect("ab😀c".limitedUTF16(to: 4) == "ab😀")
        #expect("abc".limitedUTF16(to: 5) == "abc")
    }
}

@Suite("Social — expected values from src/lib/social.ts")
struct SocialTests {
    @Test(arguments: [
        ("instagram.com/x", "https://instagram.com/x"),
        ("https://a.com/p", "https://a.com/p"),
        ("@john", "john"),
        ("  http://b.com  ", "http://b.com"),
        ("HTTPS://C.COM", "HTTPS://C.COM"),
    ])
    func href(value: String, expected: String) {
        #expect(Social.href(value) == expected)
    }

    @Test(arguments: [
        (nil, Social.Platform.x, "X"),
        ("", .instagram, "Instagram"),
        ("@john", .instagram, "@john"),
        ("john.doe", .linkedin, "john.doe"),
        ("@jd", .x, "@jd"),
        ("https://instagram.com/john.doe/", .instagram, "@john.doe"),
        ("linkedin.com/in/jane-doe", .linkedin, "jane-doe"),
        ("https://www.linkedin.com/company/acme/about", .linkedin, "acme"),
        ("https://www.facebook.com/profile.php?id=1", .facebook, "Facebook"),
        ("facebook.com/jane.d", .facebook, "jane.d"),
        ("https://x.com/@elon", .x, "@elon"),
        ("https://instagram.com/", .instagram, "Instagram"),
        ("john.com", .x, "X"),
        ("https://instagram.com/j%C3%B6rg", .instagram, "@j%C3%B6rg"),
        ("linkedin.com/pub/a/b", .linkedin, "a"),
    ] as [(String?, Social.Platform, String)])
    func handle(value: String?, platform: Social.Platform, expected: String) {
        #expect(Social.handle(value, platform: platform) == expected)
    }
}

@Suite("Post topics — `new RegExp(`#${t}(?=[^\\w]|$)`, \"i\")`, first 3 in POST_TOPICS order")
struct PostTopicsTests {
    static let topics = [
        "School", "Classes", "Dorm", "Dining", "Campus Life", "Social Life", "Clubs", "Sports", "Health", "Housing",
        "Admission", "Internships", "Jobs", "Research", "Finance", "Study Abroad", "Events", "Tips", "Fun", "Weather",
    ]

    @Test(arguments: [
        ("Love #dorm life and #Dining! #Tips #Fun", ["Dorm", "Dining", "Tips"]),
        ("#Dormitory #Schoolwork #school_ #SCHOOL.", ["School"]),
        ("#Campus Life rocks", ["Campus Life"]),
        ("#Campus", []),
        ("no tags", []),
        ("#Weather#Fun", ["Fun", "Weather"]),
        ("#Études #Fun", ["Fun"]),
    ])
    func derived(body: String, expected: [String]) {
        #expect(PostTopics.derived(from: body, topics: Self.topics) == expected)
    }
}

@Suite("Logo lookup — expected values from src/lib/logo-lookup.ts")
struct LogoLookupTests {
    @Test(arguments: [
        ("a@terpmail.umd.edu", "umd.edu"),
        ("x@stanford.edu", "stanford.edu"),
        ("y@gmail.com", "gmail.com"),
        ("bad", nil),
        ("z@edu", nil),
    ] as [(String, String?)])
    func schoolEmailDomain(email: String, expected: String?) {
        #expect(LogoLookup.extractSchoolEmailDomain(email) == expected)
    }

    @Test(arguments: [
        ("Stanford University", "stanford.edu"),
        ("University of Maryland, College Park", "umd.edu"),
        ("MIT", "mit.edu"),
        ("Massachusetts Institute of Technology", "mit.edu"),
        ("Harvard", "harvard.edu"),
        ("Unknown Tiny College", nil),
    ] as [(String, String?)])
    func knownSchoolDomain(name: String, expected: String?) {
        #expect(LogoLookup.knownSchoolDomain(name) == expected)
    }

    @Test(arguments: [
        ("Google", nil, ["google.com", "google.mn"]),
        ("Goldman Sachs & Co.", "New York", ["goldmansachsand.com", "goldmansachsand.mn"]),
        ("Acme Widgets LLC", "Ulaanbaatar, Mongolia", ["acmewidgets.mn", "acmewidgets.com"]),
        ("Khan Bank", nil, ["khanbank.com", "khanbank.mn"]),
    ] as [(String, String?, [String])])
    func employerCandidates(name: String, location: String?, expected: [String]) {
        #expect(LogoLookup.employerDomainCandidates(name: name, location: location) == expected)
    }

    @Test func urls() {
        #expect(LogoLookup.logoURL(domain: "mit.edu", token: "pk_a+b")?.absoluteString
            == "https://img.logo.dev/mit.edu?fallback=404&token=pk_a%2Bb")
        #expect(LogoLookup.badgeURL(domain: "mit.edu", token: "pk_a+b")?.absoluteString
            == "https://img.logo.dev/mit.edu?token=pk_a%2Bb")
        #expect(LogoLookup.badgeURL(domain: "mit.edu", token: "")?.absoluteString == "https://img.logo.dev/mit.edu")
    }
}
