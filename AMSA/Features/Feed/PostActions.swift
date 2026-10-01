import SwiftUI

/// The optimistic "helpful" toggle every page with PostCards implements identically:
/// mark liked (+1), reconcile with the server, roll back on failure.
@MainActor
func appreciatePost(_ postId: Int, posts: Binding<[PostItem]>, appreciating: Binding<Set<Int>>, api: APIClient) {
    guard !appreciating.wrappedValue.contains(postId),
          let current = posts.wrappedValue.first(where: { $0.id == postId }), !current.hasAppreciated else { return }
    func update(_ mutate: (inout PostItem) -> Void) {
        if let index = posts.wrappedValue.firstIndex(where: { $0.id == postId }) { mutate(&posts.wrappedValue[index]) }
    }
    appreciating.wrappedValue.insert(postId)
    update { $0.hasAppreciated = true; $0.appreciationCount = max(0, current.appreciationCount + 1) }
    Task {
        do {
            let data = try await api.send(PostsAPI.helpful(postId))
            update { post in
                post.hasAppreciated = data.hasAppreciated ?? false
                post.appreciationCount = data.appreciationCount ?? post.appreciationCount
            }
        } catch {
            update { $0.hasAppreciated = current.hasAppreciated; $0.appreciationCount = current.appreciationCount }
        }
        appreciating.wrappedValue.remove(postId)
    }
}
