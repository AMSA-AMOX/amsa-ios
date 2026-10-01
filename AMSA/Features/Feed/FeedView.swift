import SwiftUI

// Port of src/app/(dashboard)/dashboard/feed/page.tsx
struct FeedView: View {
    @Environment(SessionStore.self) private var session

    @State private var posts: [PostItem] = []
    @State private var loadingPosts = true
    @State private var error = ""
    @State private var postingMessage = ""
    @State private var appreciating: Set<Int> = []
    @State private var postOpen = false
    @State private var followingIds: Set<Int> = []
    @State private var followingInProgress: Set<Int> = []
    @State private var deleting: Set<Int> = []
    @State private var reportedIds: Set<Int> = []
    @State private var selectedTopics: Set<String> = []
    @State private var filterOpen = false
    @State private var dropdown = DropdownController()

    private var role: String? { session.role }
    private var canPost: Bool { role == Role.usMember || role == Role.admin || role == Role.boardMember }
    private var canSeeTopActions: Bool { role != Role.member }

    private var filteredPosts: [PostItem] {
        guard !selectedTopics.isEmpty else { return posts }
        return posts.filter { post in
            (post.topic ?? "").split(separator: ",").map { String($0).trimmed }.contains { selectedTopics.contains($0) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topicFilter.padding(.bottom, 20)

                if canSeeTopActions {
                    ComposerTrigger(text: "Share something with the community...") { postOpen = true }
                        .padding(.bottom, 24)
                }

                if !error.isEmpty {
                    Banner(text: error, style: .error).padding(.bottom, 16)
                }
                if !postingMessage.isEmpty {
                    Banner(text: postingMessage, style: .info).padding(.bottom, 16)
                }

                postList
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 32)
        }
        .environment(dropdown)
        .dropdownHost(dropdown)
        .task {
            let posts = Task { await loadPosts() }
            let following = Task { await loadFollowing() }
            await posts.value
            await following.value
        }
        .webModal(isPresented: $postOpen) {
            PostComposer(canPost: canPost,
                         cannotPostMessage: "Only US members, board members, and admins can post.",
                         onCreated: onCreated,
                         onClose: { postOpen = false })
        }
    }

    @ViewBuilder
    private var postList: some View {
        if loadingPosts {
            ForEach(0..<4, id: \.self) { _ in PostSkeleton() }
        } else if filteredPosts.isEmpty {
            EmptyLeaves(image: "Leaves",
                        text: selectedTopics.isEmpty ? "No posts yet" : "No posts match the selected filters")
        } else {
            ForEach(filteredPosts) { post in postCard(post) }
        }
    }

    private func postCard(_ post: PostItem) -> PostCard {
        let me = session.user?.id
        let isMine = post.author?.id == me
        let canDelete = isMine || role == Role.admin || role == Role.boardMember
        let onFollow: ((Int) -> Void)? = isMine ? nil : { follow($0) }
        let onDelete: ((Int) -> Void)? = canDelete ? { delete($0) } : nil
        let onReport: ((Int) -> Void)? = isMine ? nil : { report($0) }
        return PostCard(
            post: post,
            onAppreciate: { appreciate($0) },
            appreciating: appreciating.contains(post.id),
            showAuthor: true,
            onFollow: onFollow,
            isFollowing: post.author.map { followingIds.contains($0.id) } ?? false,
            followingInProgress: post.author.map { followingInProgress.contains($0.id) } ?? false,
            onDelete: onDelete,
            deleting: deleting.contains(post.id),
            onReport: onReport
        )
    }

    // MARK: Filter

    private var topicFilter: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { filterOpen.toggle() } label: {
                HStack(spacing: 6) {
                    Icon("adjustments", size: 24).foregroundStyle(Palette.gray500)
                    if !selectedTopics.isEmpty {
                        Text("· \(selectedTopics.count)").tw(.sm, .semibold).foregroundStyle(Palette.gray700)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .twBox(background: Palette.white, radius: TW.dashboardButtonRadius, border: Palette.gray300, borderWidth: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Filter topics")

            if filterOpen {
                FlowLayout(spacing: 8) {
                    FilterChip(label: "All", selected: selectedTopics.isEmpty) { selectedTopics = [] }
                    ForEach(StaticData.constants.postTopics, id: \.self) { topic in
                        FilterChip(label: topic, selected: selectedTopics.contains(topic)) {
                            if selectedTopics.contains(topic) { selectedTopics.remove(topic) } else { selectedTopics.insert(topic) }
                        }
                    }
                }
            }
        }
    }

    // MARK: Data

    private func loadPosts() async {
        loadingPosts = true
        error = ""
        do {
            posts = try await session.api.send(PostsAPI.list(limit: 40)).posts ?? []
        } catch let e {
            error = e.apiMessage ?? "Failed to load posts."
            posts = []
        }
        loadingPosts = false
    }

    private func loadFollowing() async {
        let ids = (try? await session.api.send(FollowsAPI.mine()))?.followingIds ?? []
        followingIds = Set(ids)
    }

    private func appreciate(_ postId: Int) {
        guard !appreciating.contains(postId),
              let current = posts.first(where: { $0.id == postId }), !current.hasAppreciated else { return }
        appreciating.insert(postId)
        update(postId) { $0.hasAppreciated = true; $0.appreciationCount = max(0, current.appreciationCount + 1) }
        Task {
            do {
                let data = try await session.api.send(PostsAPI.helpful(postId))
                update(postId) { post in
                    post.hasAppreciated = data.hasAppreciated ?? false
                    post.appreciationCount = data.appreciationCount ?? post.appreciationCount
                }
            } catch {
                update(postId) { $0.hasAppreciated = current.hasAppreciated; $0.appreciationCount = current.appreciationCount }
            }
            appreciating.remove(postId)
        }
    }

    private func follow(_ authorId: Int) {
        guard !followingInProgress.contains(authorId) else { return }
        let isFollowing = followingIds.contains(authorId)
        followingInProgress.insert(authorId)
        if isFollowing { followingIds.remove(authorId) } else { followingIds.insert(authorId) }
        Task {
            do {
                if isFollowing {
                    _ = try await session.api.send(FollowsAPI.unfollow(authorId))
                } else {
                    _ = try await session.api.send(FollowsAPI.follow(authorId))
                }
            } catch {
                if isFollowing { followingIds.insert(authorId) } else { followingIds.remove(authorId) }
            }
            followingInProgress.remove(authorId)
        }
    }

    private func delete(_ postId: Int) {
        deleting.insert(postId)
        Task {
            if (try? await session.api.send(PostsAPI.delete(postId))) != nil {
                posts.removeAll { $0.id == postId }
            }
            // leave post in list on failure
            deleting.remove(postId)
        }
    }

    private func report(_ postId: Int) {
        guard !reportedIds.contains(postId) else { return }
        reportedIds.insert(postId)
        Task {
            do {
                _ = try await session.api.send(PostsAPI.report(postId))
                postingMessage = "Post reported. Thank you for keeping AMSA safe."
            } catch {
                reportedIds.remove(postId)
                postingMessage = "Failed to submit report. Please try again."
            }
            try? await Task.sleep(for: .seconds(4))
            postingMessage = ""
        }
    }

    private func onCreated(_ post: PostItem) {
        if post.isApproved {
            posts.insert(post, at: 0)
            postingMessage = "Post published."
        } else {
            postingMessage = "Post submitted for approval. It will appear on feed once approved."
        }
        postOpen = false
    }

    private func update(_ id: Int, _ mutate: (inout PostItem) -> Void) {
        if let index = posts.firstIndex(where: { $0.id == id }) { mutate(&posts[index]) }
    }
}

// MARK: - Shared pieces

/// Filter chip: `shrink-0 px-3.5 py-1.5 rounded-lg text-sm font-semibold border-2` (a dashboard button → 4px).
struct FilterChip: View {
    let label: String
    let selected: Bool
    var radius: CGFloat = TW.dashboardButtonRadius
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .tw(.sm, .semibold)
                .foregroundStyle(selected ? Palette.black : Palette.gray600)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .twBox(background: selected ? Palette.gray200 : Palette.white, radius: radius,
                       border: selected ? Palette.gray500 : Palette.gray300, borderWidth: 2)
        }
        .buttonStyle(.plain)
    }
}

/// The "Share something…" / "Ask something…" trigger bar.
struct ComposerTrigger: View {
    let text: String
    let action: () -> Void
    @Environment(SessionStore.self) private var session

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Avatar(imageURL: session.user?.profilePic, initials: session.user?.initials ?? "", size: 48, fontSize: .lg)
                Text(text).tw(.lg).foregroundStyle(Palette.gray400).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .twBox(background: Palette.white, radius: TW.dashboardButtonRadius, border: Palette.gray300, borderWidth: 2)
        }
        .buttonStyle(.plain)
    }
}

struct Banner: View {
    enum Style { case error, info, success }
    let text: String
    let style: Style

    var body: some View {
        let colors: (Color, Color, Color) = switch style {
        case .error: (Palette.red50, Palette.red200, Palette.red600)
        case .info: (Palette.blue50, Palette.blue100, Palette.blue700)
        case .success: (Palette.green50, Palette.green100, Palette.green700)
        }
        Text(text)
            .tw(.sm)
            .foregroundStyle(colors.2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .twBox(background: colors.0, radius: TW.radiusXl, border: colors.1)
    }
}

/// `flex flex-col items-center gap-3 py-16` + leaves illustration + `text-lg font-medium text-gray-400`.
struct EmptyLeaves: View {
    let image: String
    let text: String
    var imageSize: CGFloat = 224

    var body: some View {
        VStack(spacing: 12) {
            Image(image).resizable().scaledToFit().frame(width: imageSize, height: imageSize)
            Text(text).tw(.lg, .medium).foregroundStyle(Palette.gray400).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

/// Feed/thread skeleton row.
struct PostSkeleton: View {
    var showImage: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle().fill(Palette.gray100).frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonBar(fraction: 1 / 3, height: 14)
                    SkeletonBar(fraction: 1 / 4, height: 12)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBar(height: 16)
                SkeletonBar(fraction: 4 / 5, height: 16)
                if showImage { RoundedRectangle(cornerRadius: TW.radiusXl).fill(Palette.gray100).frame(height: 208) }
            }
            .padding(.leading, 56)
        }
        .padding(.vertical, 20)
        .bottomBorder(Palette.gray200, width: 1)
        .twPulse()
    }
}
