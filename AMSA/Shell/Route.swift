import Foundation

/// Every dashboard destination. Mirrors the web routes under `(dashboard)`.
enum Route: Hashable, Sendable {
    case profile(openUnansweredThreads: Bool = false)
    case feed
    case notifications
    case membership
    case places
    case placeDetail(abbr: String)
    case colleges
    case collegeDetail(id: Int)
    case compare
    case threads
    case network
    case memberProfile(id: Int)
    case inbox
    case blogs
    case settings
    case adminVerification
    case adminPosts
    case adminThreadApproval

    /// The web pathname (used for nav highlighting and the feedback `page` field).
    var webPath: String {
        switch self {
        case .profile: "/welcome"
        case .feed: "/dashboard/feed"
        case .notifications: "/dashboard/notifications"
        case .membership: "/verification"
        case .places: "/dashboard/places"
        case .placeDetail(let abbr): "/dashboard/places/\(abbr.lowercased())"
        case .colleges: "/dashboard/research"
        case .collegeDetail(let id): "/dashboard/research/college/\(id)"
        case .compare: "/dashboard/research/compare"
        case .threads: "/dashboard/threads"
        case .network: "/dashboard/network"
        case .memberProfile(let id): "/dashboard/network/\(id)"
        case .inbox: "/dashboard/inbox"
        case .blogs: "/dashboard/blogs"
        case .settings: "/dashboard/settings"
        case .adminVerification: "/dashboard/admin/verification"
        case .adminPosts: "/dashboard/admin/posts"
        case .adminThreadApproval: "/dashboard/admin/thread-approval"
        }
    }

    /// DashboardTopBar `TITLE_MAP` + dynamic segments.
    var title: String {
        switch self {
        case .profile: "Profile"
        case .feed: "Feed"
        case .notifications: "Notifications"
        case .membership: "Membership Form"
        case .places: "Places"
        case .placeDetail(let abbr): StaticData.stateName(abbr.uppercased()) ?? "Places"
        case .colleges, .collegeDetail: "Colleges"
        case .compare: "Compare"
        case .threads: "Threads"
        case .network: "Network"
        case .memberProfile: ""
        case .inbox: "Inbox"
        case .blogs: "Blogs"
        case .settings: "Settings"
        case .adminVerification: "Verification Queue"
        case .adminPosts: "Post Approval"
        case .adminThreadApproval: "Thread Approval"
        }
    }

    /// Detail pages are pushed; everything else replaces the root (like a sidebar link).
    var isDetail: Bool {
        switch self {
        case .placeDetail, .collegeDetail, .memberProfile: true
        default: false
        }
    }

    /// Maps notification `href`s (and other in-app links) to routes.
    init?(href: String) {
        guard let components = URLComponents(string: href) else { return nil }
        let parts = components.path.split(separator: "/").map(String.init)
        let query = Dictionary((components.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
        switch parts {
        case ["welcome"]: self = .profile(openUnansweredThreads: query["threads"] == "unanswered")
        case ["verification"]: self = .membership
        case ["dashboard", "feed"]: self = .feed
        case ["dashboard", "notifications"]: self = .notifications
        case ["dashboard", "places"]: self = .places
        case let p where p.count == 3 && p[0] == "dashboard" && p[1] == "places": self = .placeDetail(abbr: p[2])
        case ["dashboard", "research"]: self = .colleges
        case ["dashboard", "research", "compare"]: self = .compare
        case let p where p.count == 4 && p[0] == "dashboard" && p[1] == "research" && p[2] == "college":
            guard let id = Int(p[3]) else { return nil }
            self = .collegeDetail(id: id)
        case ["dashboard", "threads"]: self = .threads
        case ["dashboard", "network"]: self = .network
        case let p where p.count == 3 && p[0] == "dashboard" && p[1] == "network":
            guard let id = Int(p[2]) else { return nil }
            self = .memberProfile(id: id)
        case ["dashboard", "inbox"]: self = .inbox
        case ["dashboard", "blogs"]: self = .blogs
        case ["dashboard", "settings"]: self = .settings
        case ["dashboard", "admin", "verification"]: self = .adminVerification
        case ["dashboard", "admin", "posts"]: self = .adminPosts
        case ["dashboard", "admin", "thread-approval"]: self = .adminThreadApproval
        default: return nil
        }
    }
}

/// Navigation state for the dashboard shell.
@MainActor
@Observable
final class Router {
    var root: Route = .feed
    var path: [Route] = []
    var drawerOpen = false

    var current: Route { path.last ?? root }

    /// `router.push(href)` / `<Link href>`.
    func navigate(to route: Route) {
        drawerOpen = false
        if route.isDetail {
            path.append(route)
        } else {
            path = []
            root = route
        }
    }

    func navigate(href: String) {
        if let route = Route(href: href) { navigate(to: route) }
    }

    /// In-page "Back to X" links: pop when X is underneath, otherwise go to X.
    func back(to route: Route) {
        if !path.isEmpty {
            let below = path.count >= 2 ? path[path.count - 2] : root
            if below.webPath == route.webPath {
                path.removeLast()
                return
            }
        }
        navigate(to: route)
    }

    func reset() {
        root = .feed
        path = []
        drawerOpen = false
    }
}
