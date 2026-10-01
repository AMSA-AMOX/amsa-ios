import Foundation
import Testing
@testable import AMSA

@Suite("ISODate — JS `new Date(string)` semantics")
struct ISODateTests {
    @Test func zuluAndOffsetsAreAbsolute() {
        #expect(ISODate.parse("2026-09-30T12:00:00Z")?.timeIntervalSince1970 == 1_790_769_600)
        #expect(ISODate.parse("2026-09-30T20:00:00+08:00") == ISODate.parse("2026-09-30T12:00:00Z"))
        #expect(ISODate.parse("2026-09-30T07:30:00-0430") == ISODate.parse("2026-09-30T12:00:00Z"))
        #expect(ISODate.parse("2026-09-30T13:00:00+01") == ISODate.parse("2026-09-30T12:00:00Z"))
    }

    /// `getTime()`: whole milliseconds since the epoch.
    private func millis(_ iso: String) -> Int64? {
        ISODate.parse(iso).map { Int64(($0.timeIntervalSince1970 * 1000).rounded()) }
    }

    @Test func millisecondsAreKeptAndExtraDigitsTruncated() {
        #expect(millis("2026-09-30T12:00:00.123Z") == 1_790_769_600_123)
        // Postgres timestamps carry microseconds; JS keeps milliseconds.
        #expect(millis("2026-09-30T12:00:00.123999+00:00") == 1_790_769_600_123)
        #expect(millis("2026-09-30T12:00:00.5Z") == 1_790_769_600_500)
    }

    @Test func dateTimeWithoutOffsetIsDeviceLocal() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let expected = calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 8, minute: 15))
        #expect(ISODate.parse("2026-09-30T08:15:00") == expected)
        #expect(ISODate.parse("2026-09-30 08:15") == expected)
    }

    @Test func dateOnlyIsUTCMidnight() {
        #expect(ISODate.parse("2026-09-30") == ISODate.parse("2026-09-30T00:00:00Z"))
    }

    @Test func invalidInputIsNil() {
        #expect(ISODate.parse(nil) == nil)
        #expect(ISODate.parse("") == nil)
        #expect(ISODate.parse("yesterday") == nil)
        #expect(ISODate.parse("2026/09/30") == nil)
    }

    @Test func toISOStringRoundTrip() {
        let date = ISODate.parse("2026-09-30T12:34:56.789Z")!
        #expect(ISODate.string(from: date) == "2026-09-30T12:34:56.789Z")
    }
}

@Suite("RelativeTime — the web's five hand-written helpers")
struct RelativeTimeTests {
    let now = Fixture.date("2026-09-30T12:00:00Z")

    private func ago(_ seconds: TimeInterval) -> Date { now.addingTimeInterval(-seconds) }

    @Test func justNowCapitalisationDiffers() {
        #expect(RelativeTime.post.format(ago(30), now: now) == "Just now")
        for variant in [RelativeTime.notification, .agoMonth, .shortMonth, .shortUnbounded] {
            #expect(variant.format(ago(30), now: now) == "just now")
        }
    }

    @Test func suffixes() {
        #expect(RelativeTime.post.format(ago(5 * 60), now: now) == "5m")
        #expect(RelativeTime.notification.format(ago(5 * 60), now: now) == "5m ago")
        #expect(RelativeTime.agoMonth.format(ago(3 * 3600), now: now) == "3h ago")
        #expect(RelativeTime.shortMonth.format(ago(3 * 3600), now: now) == "3h")
        #expect(RelativeTime.shortUnbounded.format(ago(2 * 86_400), now: now) == "2d")
    }

    @Test func boundariesFloor() {
        #expect(RelativeTime.notification.format(ago(59), now: now) == "just now")
        #expect(RelativeTime.notification.format(ago(60), now: now) == "1m ago")
        #expect(RelativeTime.notification.format(ago(3599), now: now) == "59m ago")
        #expect(RelativeTime.notification.format(ago(3600), now: now) == "1h ago")
        #expect(RelativeTime.notification.format(ago(86_399), now: now) == "23h ago")
        #expect(RelativeTime.notification.format(ago(86_400), now: now) == "1d ago")
    }

    @Test func dayCutoffsFallBackToDate() {
        let sixDays = ago(6 * 86_400), sevenDays = ago(7 * 86_400)
        #expect(RelativeTime.post.format(sixDays, now: now) == "6d")
        #expect(RelativeTime.post.format(sevenDays, now: now) == Formatters.localeDate(sevenDays))
        #expect(RelativeTime.notification.format(sevenDays, now: now) == Formatters.localeDate(sevenDays))
        #expect(RelativeTime.agoMonth.format(ago(29 * 86_400), now: now) == "29d ago")
        #expect(RelativeTime.agoMonth.format(ago(30 * 86_400), now: now) == Formatters.localeDate(ago(30 * 86_400)))
        #expect(RelativeTime.shortMonth.format(ago(30 * 86_400), now: now) == Formatters.localeDate(ago(30 * 86_400)))
        #expect(RelativeTime.shortUnbounded.format(ago(400 * 86_400), now: now) == "400d")
    }

    @Test func unparseableStringsReadAsJustNow() {
        #expect(RelativeTime.post.format(nil as String?, now: now) == "Just now")
        #expect(RelativeTime.agoMonth.format("garbage", now: now) == "just now")
    }
}

@Suite("JWT claims")
struct JWTTests {
    private func token(_ payload: String) -> String {
        let body = Data(payload.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.\(body).signature"
    }

    @Test func decodesUnpaddedBase64URL() throws {
        let claims = try #require(JWTClaims(token: token(#"{"id":42,"role":"board_member","iat":1790000000,"exp":1790604800}"#)))
        #expect(claims.id == 42)
        #expect(claims.role == "board_member")
        #expect(claims.exp == 1_790_604_800)
    }

    @Test func expiry() throws {
        let claims = try #require(JWTClaims(token: token(#"{"id":1,"role":"member","exp":1790604800}"#)))
        #expect(!claims.isExpired(at: Date(timeIntervalSince1970: 1_790_604_799)))
        #expect(claims.isExpired(at: Date(timeIntervalSince1970: 1_790_604_800)))
        let noExp = try #require(JWTClaims(token: token(#"{"id":1,"role":"member"}"#)))
        #expect(!noExp.isExpired())
    }

    @Test func malformedTokens() {
        #expect(JWTClaims(token: "") == nil)
        #expect(JWTClaims(token: "a.b") == nil)
        #expect(JWTClaims(token: "a.!!!.c") == nil)
        #expect(JWTClaims(token: token(#"{"role":"member"}"#)) == nil) // id is required
    }
}
