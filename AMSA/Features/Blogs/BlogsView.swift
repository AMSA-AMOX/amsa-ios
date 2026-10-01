import SwiftUI

// Port of src/app/(dashboard)/dashboard/blogs/page.tsx
struct BlogsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router

    @State private var posts: [PostItem] = []
    @State private var loadingPosts = true
    @State private var error = ""
    @State private var appreciating: Set<Int> = []
    @State private var dropdown = DropdownController()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                (Text("Review your posts and track moderation status. Create new posts from ")
                    + Text("Feed").font(.custom(TW.Weight.medium.fontName, fixedSize: 14)).foregroundColor(Palette.navy)
                    + Text("."))
                    .tw(.sm)
                    .foregroundStyle(Palette.gray500)
                    .onTapGesture { router.navigate(to: .feed) }

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Your posts").tw(.lg, .bold).foregroundStyle(Palette.navy)
                        Spacer()
                        Text("\(posts.count) total").tw(.xs).foregroundStyle(Palette.gray500)
                    }
                    if !error.isEmpty { Banner(text: error, style: .error) }
                    if loadingPosts {
                        ForEach(0..<2, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: 12) {
                                SkeletonBar(fraction: 2 / 3, height: 20)
                                SkeletonBar(height: 16)
                                RoundedRectangle(cornerRadius: TW.radiusXl).fill(Palette.gray100).frame(height: 176)
                            }
                            .padding(20)
                            .twBox(background: Palette.white, radius: TW.radius2xl, border: Palette.gray100)
                            .twShadow(.sm)
                            .twPulse()
                        }
                    } else if posts.isEmpty {
                        VStack(spacing: 4) {
                            Text("No posts yet").tw(.base, .semibold).foregroundStyle(Palette.navy)
                            Text("Your posts will appear here right after publishing.").tw(.sm).foregroundStyle(Palette.gray500)
                        }
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(32)
                        .twBox(background: Palette.white, radius: TW.radius2xl, border: Palette.gray100)
                        .twShadow(.sm)
                    } else {
                        VStack(spacing: 16) {
                            ForEach(posts) { post in
                                PostCard(post: post, onAppreciate: { id in
                                    appreciatePost(id, posts: $posts, appreciating: $appreciating, api: session.api)
                                }, appreciating: appreciating.contains(post.id), showAuthor: false)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 32)
        }
        .environment(dropdown)
        .task { await load() }
    }

    private func load() async {
        guard let me = session.user?.id else { return }
        loadingPosts = true
        error = ""
        do {
            posts = try await session.api.send(PostsAPI.list(limit: 30, creatorId: me, includeModeration: true)).posts ?? []
        } catch let e {
            error = e.apiMessage ?? "Failed to load your posts."
            posts = []
        }
        loadingPosts = false
    }
}
