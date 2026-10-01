import Foundation
import Testing
@testable import AMSA

@Suite("Route(href:) — notification and in-app links")
struct RouteTests {
    @Test(arguments: [
        ("/dashboard/feed", Route.feed),
        ("/dashboard/feed?reportedPostId=12", .feed),
        ("/dashboard/network/42", .memberProfile(id: 42)),
        ("/welcome?threads=unanswered", .profile(openUnansweredThreads: true)),
        ("/welcome", .profile(openUnansweredThreads: false)),
        ("/dashboard/inbox", .inbox),
        ("/verification", .membership),
        ("/dashboard/places/ca", .placeDetail(abbr: "ca")),
        ("/dashboard/research/college/7", .collegeDetail(id: 7)),
        ("/dashboard/research/compare", .compare),
        ("/dashboard/admin/thread-approval", .adminThreadApproval),
    ])
    func known(href: String, route: Route) {
        #expect(Route(href: href) == route)
    }

    @Test(arguments: [
        "/dashboard/admin/members", // web-only by decision
        "/dashboard/events", // web-only by decision
        "/dashboard/guide", // web-only by decision
        "/dashboard/network/abc",
        "/dashboard/research/college/x",
        "/threads/5",
        "/unauthorized",
        "",
    ])
    func unknown(href: String) {
        #expect(Route(href: href) == nil)
    }

    @Test func webPathsRoundTrip() {
        for route in [Route.feed, .compare, .threads, .memberProfile(id: 3), .collegeDetail(id: 9), .adminPosts] {
            #expect(Route(href: route.webPath) == route)
        }
    }
}

@Suite("Router")
@MainActor
struct RouterTests {
    @Test func detailsPushAndSidebarRoutesReplace() {
        let router = Router()
        router.drawerOpen = true
        router.navigate(to: .colleges)
        #expect(router.root == .colleges && router.path.isEmpty && !router.drawerOpen)
        router.navigate(to: .collegeDetail(id: 1))
        router.navigate(to: .memberProfile(id: 2))
        #expect(router.path == [.collegeDetail(id: 1), .memberProfile(id: 2)])
        #expect(router.current == .memberProfile(id: 2))
        router.navigate(to: .network)
        #expect(router.root == .network && router.path.isEmpty)
    }

    @Test func backPopsWhenTargetIsUnderneath() {
        let router = Router()
        router.navigate(to: .places)
        router.navigate(to: .placeDetail(abbr: "ca"))
        router.back(to: .places)
        #expect(router.root == .places && router.path.isEmpty)

        router.navigate(to: .placeDetail(abbr: "ny"))
        router.back(to: .network) // not underneath → behaves like a link
        #expect(router.root == .network && router.path.isEmpty)
    }

    @Test func reset() {
        let router = Router()
        router.navigate(to: .settings)
        router.navigate(to: .memberProfile(id: 1))
        router.reset()
        #expect(router.root == .feed && router.path.isEmpty)
    }
}

@Suite("Supabase upload paths (the server's account-deletion cleanup depends on them)")
struct UploadPathTests {
    let now = Date(timeIntervalSince1970: 1_790_769_600.1239)

    @Test func paths() {
        #expect(UploadPath.millis(now) == 1_790_769_600_123)
        #expect(UploadPath.avatar(userId: 7, now: now) == "7-1790769600123.jpg")
        #expect(UploadPath.post(userId: 7, index: 0, now: now) == "7/1790769600123-0.jpg")
        #expect(UploadPath.placeReview(userId: 7, index: 1, now: now) == "reviews/7/1790769600123-1.jpg")
        #expect(UploadPath.collegeReview(userId: 7, index: 2, now: now) == "reviews/colleges/7/1790769600123-2.jpg")
    }
}

@Suite("Bundled data (tools/extract-data.ts, tools/gen-us-map.ts)")
struct StaticDataTests {
    @Test func counts() {
        #expect(StaticData.states.count == 51)
        #expect(StaticData.statesByAbbr.count == 51)
        #expect(StaticData.usMap.states.count == 51)
        #expect(StaticData.constants.standardFields.count == 60)
        #expect(StaticData.constants.postTopics.count == 20)
        #expect(StaticData.constants.placeReviewPrompts.count == 6)
        #expect(StaticData.constants.collegeReviewPrompts.count == 6)
    }

    @Test func mapCoversEveryState() {
        let mapAbbrs = Set(StaticData.usMap.states.map(\.abbr))
        #expect(mapAbbrs == Set(StaticData.states.map(\.abbr)))
        #expect(USMapGeometry.states.allSatisfy { !$0.path.isEmpty })
        #expect(StaticData.stateName("DC") != nil)
        #expect(Route.placeDetail(abbr: "ca").title == StaticData.stateName("CA"))
    }
}
