// Port of src/app/(dashboard)/dashboard/admin/posts/page.tsx
import SwiftUI

struct AdminPostsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(ShellStore.self) private var shell
    @Environment(Router.self) private var router

    @State private var status: ReviewFilter = .pending
    @State private var posts: [ModerationPost] = []
    @State private var notes: [Int: String] = [:]
    @State private var loadingPosts = true
    @State private var actionId: Int?
    @State private var deletingId: Int?
    @State private var error: String?

    private var allowed: Bool { session.role == Role.admin || session.role == Role.boardMember }
    private var pendingCount: Int { posts.filter { $0.reviewStatus == "pending" }.count }

    var body: some View {
        Group {
            if allowed {
                content
            } else {
                Color.clear
            }
        }
        .onAppear { if !allowed { router.navigate(to: .profile()) } }
        .task(id: status) { if allowed { await load(status) } }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Review US member posts and approve or reject before publishing to the feed.")
                    .tw(.sm).foregroundStyle(Palette.gray500)
                    .padding(.top, 4)
                    .padding(.bottom, 20)

                ReviewFilterTabs(selection: $status, pendingCount: pendingCount).padding(.bottom, 20)

                if let error { AdminErrorBox(message: error).padding(.bottom, 16) }

                if loadingPosts {
                    AdminLoadingBlocks(height: 112)
                } else if posts.isEmpty {
                    AdminEmptyCard(message: "No posts for this status.")
                } else {
                    VStack(spacing: 16) {
                        ForEach(posts) { post in postCard(post) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 32)
        }
    }

    private func postCard(_ post: ModerationPost) -> some View {
        let author = post.author.map { "\($0.firstName ?? "null") \($0.lastName ?? "null")" } ?? "Unknown user"
        let created = ISODate.parse(post.createdAt).map(Formatters.localeDateTime) ?? "Invalid Date"
        let pending = post.reviewStatus == "pending"
        return AdminCard(padding: 20) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    Text("By \(author) · \(created)").tw(.xs).foregroundStyle(Palette.gray500).padding(.top, 4)
                    Spacer(minLength: 0)
                    ReviewStatusPill(status: post.reviewStatus)
                }

                Text(post.body ?? "").tw(.sm).foregroundStyle(Palette.gray700)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)

                if !post.images.isEmpty {
                    Text("\(post.images.count) image(s) attached").tw(.xs).foregroundStyle(Palette.gray500).padding(.top, 8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    AdminFieldLabel(text: "Review note")
                    WebTextArea(placeholder: "",
                                text: Binding(get: { notes[post.id] ?? "" }, set: { notes[post.id] = $0 }),
                                style: .adminNote, rows: 2, disabled: !pending || actionId == post.id)
                }
                .padding(.top, 16)

                HStack(spacing: 8) {
                    if pending {
                        AdminSolidButton(title: "Approve", color: Palette.green600, disabled: actionId == post.id) {
                            Task { await review(post, status: "approved") }
                        }
                        AdminSolidButton(title: "Reject", color: Palette.red600, disabled: actionId == post.id) {
                            Task { await review(post, status: "rejected") }
                        }
                    }
                    Spacer(minLength: 0) // `ml-auto`
                    Button { Task { await delete(post.id) } } label: {
                        Text(deletingId == post.id ? "Deleting…" : "Delete").tw(.sm, .semibold).foregroundStyle(Palette.gray500)
                            .padding(.horizontal, 17).padding(.vertical, 9)
                            .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius)
                                .strokeBorder(Palette.gray200, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(deletingId == post.id)
                    .opacity(deletingId == post.id ? 0.5 : 1)
                }
                .padding(.top, 16)
            }
        }
    }

    // MARK: Data

    private func load(_ nextStatus: ReviewFilter) async {
        loadingPosts = true
        error = nil
        do {
            let rows = try await session.api.send(AdminAPI.posts(status: nextStatus.rawValue)).posts ?? []
            if Task.isCancelled { return }
            posts = rows
            for post in rows where notes[post.id] == nil { notes[post.id] = post.reviewNote ?? "" }
        } catch {
            // A newer tab selection cancelled this request; that load owns the state now.
            if Task.isCancelled { return }
            self.error = error.apiMessage ?? "Failed to load post queue."
            posts = []
        }
        loadingPosts = false
    }

    private func delete(_ postId: Int) async {
        deletingId = postId
        error = nil
        do {
            _ = try await session.api.send(PostsAPI.delete(postId))
            posts.removeAll { $0.id == postId }
        } catch {
            self.error = error.apiMessage ?? "Failed to delete post."
        }
        deletingId = nil
    }

    private func review(_ post: ModerationPost, status reviewStatus: String) async {
        actionId = post.id
        error = nil
        do {
            _ = try await session.api.send(AdminAPI.reviewPost(post.id, status: reviewStatus, note: notes[post.id] ?? ""))
            shell.invalidate()
            await load(status)
        } catch {
            self.error = error.apiMessage ?? "Failed to review post."
        }
        actionId = nil
    }
}
