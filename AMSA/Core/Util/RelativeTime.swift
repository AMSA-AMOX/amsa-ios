import Foundation

/// The web has several hand-written "time ago" helpers that differ in wording and
/// cutoffs. Each case reproduces one of them exactly.
enum RelativeTime {
    /// components/posts/PostCard.tsx — "Just now", "5m", "3h", "2d" (<7d), then date.
    case post
    /// dashboard/notifications — "just now", "5m ago", "3h ago", "2d ago" (<7d), then date.
    case notification
    /// threads, reviews (places/college), admin thread approval — "just now", "5m ago" … "2d ago" (<30d), then date.
    case agoMonth
    /// dashboard/inbox — "just now", "5m", "3h", "2d" (<30d), then date.
    case shortMonth
    /// welcome (profile) unanswered threads — "just now", "5m", "3h", "2d" with no date fallback.
    case shortUnbounded

    func format(_ iso: String?, now: Date = .now) -> String {
        guard let date = ISODate.parse(iso) else {
            // `new Date(undefined)` → Invalid Date; every helper then yields "just now"
            // except the date fallback, which prints "Invalid Date".
            return self == .post ? "Just now" : "just now"
        }
        return format(date, now: now)
    }

    func format(_ date: Date, now: Date = .now) -> String {
        let diffMs = now.timeIntervalSince(date) * 1000
        let minutes = Int(floor(diffMs / 60000))
        let justNow = self == .post ? "Just now" : "just now"
        let suffix: String
        let dayCutoff: Int?
        switch self {
        case .post: suffix = ""; dayCutoff = 7
        case .notification: suffix = " ago"; dayCutoff = 7
        case .agoMonth: suffix = " ago"; dayCutoff = 30
        case .shortMonth: suffix = ""; dayCutoff = 30
        case .shortUnbounded: suffix = ""; dayCutoff = nil
        }
        if minutes < 1 { return justNow }
        if minutes < 60 { return "\(minutes)m\(suffix)" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h\(suffix)" }
        let days = hours / 24
        if let dayCutoff, days >= dayCutoff { return Formatters.localeDate(date) }
        return "\(days)d\(suffix)"
    }
}
