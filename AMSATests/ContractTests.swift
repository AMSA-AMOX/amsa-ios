import Foundation
import Testing
@testable import AMSA

/// Set `AMSA_TEST_EMAIL` / `AMSA_TEST_PASSWORD` in the scheme's Test environment to enable.
enum LiveAPI {
    static var credentials: (email: String, password: String)? {
        let env = ProcessInfo.processInfo.environment
        guard let email = env["AMSA_TEST_EMAIL"], !email.isEmpty,
              let password = env["AMSA_TEST_PASSWORD"], !password.isEmpty else { return nil }
        return (email, password)
    }
}

/// Decodes every GET the app makes against production to catch schema drift. Read-only apart from
/// the login itself (which, like the website's, may apply the server's automatic role upgrades).
@Suite("Live API contract", .enabled(if: LiveAPI.credentials != nil), .serialized)
struct ContractTests {
    @Test func everyReadEndpointDecodes() async throws {
        let (email, password) = try #require(LiveAPI.credentials)
        let api = APIClient(baseURL: AppConfig.current.apiBaseURL)
        let auth = try await api.send(AuthAPI.login(email: email, password: password))
        api.credentials.set(auth.token)
        let me = auth.user

        func check<R>(_ name: String, _ endpoint: Endpoint<R>) async {
            do { _ = try await api.send(endpoint) } catch { Issue.record("\(name) failed: \(error)") }
        }

        await check("auth/me", AuthAPI.me())
        await check("me/shell", ShellAPI.shell(seenAfter: ""))
        await check("posts", PostsAPI.list(limit: 40))
        await check("posts (own, with moderation)", PostsAPI.list(limit: 40, creatorId: me.id, includeModeration: true))
        await check("user/follows", FollowsAPI.mine())
        await check("user/college", UserCollegeAPI.mine())
        await check("hub-threads", HubThreadsAPI.list())
        await check("user/network", NetworkAPI.discovery())
        await check("user/network/search", NetworkAPI.search("a"))
        await check("threads inbox", QAThreadsAPI.inbox())
        await check("threads/profile", QAThreadsAPI.profile(me.id))
        await check("user/experience", ProfileAPI.experiences())
        await check("user/education", ProfileAPI.educations())
        await check("user/verification", ProfileAPI.membershipStatus())
        await check("places/student-counts", PlacesAPI.studentCounts())

        if me.role == Role.admin {
            await check("admin/verification", AdminAPI.verification(status: ReviewFilter.all.rawValue))
        }
        if me.role == Role.admin || me.role == Role.boardMember {
            await check("admin/posts", AdminAPI.posts(status: ReviewFilter.all.rawValue))
            await check("hub-threads pending", HubThreadsAPI.pending())
        }

        do {
            let raw = try await api.sendRaw(path: "/api/colleges")
            let catalog = try JSONDecoder().decode(CollegesResponse.self, from: raw)
            #expect((catalog.colleges?.count ?? 0) > 0)
        } catch {
            Issue.record("colleges failed: \(error)")
        }
    }
}
