import SwiftUI

/// The Home tab: Feed and Threads, switched from the top bar, with filter (left) and compose (right).
struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(SessionStore.self) private var session
    @Namespace private var modeSelection

    @State private var feedTopics: Set<String> = []
    @State private var threadCategory = "all"
    @State private var feedFilterOpen = false
    @State private var threadsFilterOpen = false
    @State private var feedComposeOpen = false
    @State private var threadsComposeOpen = false
    @State private var threadsVisited = false

    private var mode: Router.HomeMode { router.homeMode }
    /// The feed's "Share something…" trigger is hidden from `member`s (`canSeeTopActions`).
    private var canComposeHere: Bool { mode == .threads || session.role != Role.member }
    private var filterActive: Bool { mode == .feed ? !feedTopics.isEmpty : threadCategory != "all" }

    var body: some View {
        ZStack {
            FeedView(selectedTopics: $feedTopics, filterOpen: $feedFilterOpen, composeOpen: $feedComposeOpen)
                .modifier(ModeVisibility(visible: mode == .feed))
            if threadsVisited || mode == .threads {
                ThreadsView(activeCategory: $threadCategory, filterOpen: $threadsFilterOpen,
                            composeOpen: $threadsComposeOpen)
                    .modifier(ModeVisibility(visible: mode == .threads))
            }
        }
        .pinnedTopBar { bar }
        .onChange(of: router.homeMode, initial: true) { _, newMode in
            if newMode == .threads { threadsVisited = true }
        }
    }

    private var bar: some View {
        HStack(spacing: 10) {
            ChromeCircleButton(systemImage: "line.3.horizontal.decrease", label: "Filters", active: filterActive) {
                if mode == .feed { feedFilterOpen = true } else { threadsFilterOpen = true }
            }
            modeSwitch
            if canComposeHere {
                ChromeCircleButton(systemImage: "square.and.pencil", label: mode == .feed ? "New post" : "Ask a question") {
                    if mode == .feed { feedComposeOpen = true } else { threadsComposeOpen = true }
                }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
    }

    private var modeSwitch: some View {
        HStack(spacing: 4) {
            segment(.feed, title: "Feed", symbol: "newspaper")
            segment(.threads, title: "Threads", symbol: "bubble.left.and.bubble.right")
        }
        .padding(4)
        .frame(height: Chrome.toolbarHeight)
        .frame(maxWidth: .infinity)
        .chromeSurface(Capsule())
    }

    private func segment(_ target: Router.HomeMode, title: String, symbol: String) -> some View {
        let selected = mode == target
        return Button {
            guard !selected else { return }
            withAnimation(Chrome.spring) { router.homeMode = target }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 14, weight: .semibold))
                Text(title).tw(.px(15), .semibold).lineLimit(1)
            }
            .foregroundStyle(selected ? Palette.white : Palette.gray600)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if selected {
                    Capsule().fill(Palette.navy).matchedGeometryEffect(id: "home-mode", in: modeSelection)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Keeps a hidden screen alive but invisible and inert.
struct ModeVisibility: ViewModifier {
    let visible: Bool

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
    }
}
