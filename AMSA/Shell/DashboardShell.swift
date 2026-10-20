import SwiftUI
import UIKit

/// The signed-in app: a tab root (the selected tab + the bottom tab bar) with every other screen pushed on top.
struct DashboardShell: View {
    @Environment(Router.self) private var router
    @Environment(ShellStore.self) private var shell
    @Environment(SafetyStore.self) private var safety
    @Environment(PushNotifications.self) private var push
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            TabRoot()
                .navigationDestination(for: Route.self) { PushedScreen(route: $0) }
        }
        .termsGate()
        .onAppear {
            shell.load()
            safety.load()
        }
        .task { await push.start() }
        // A tapped notification, including one that launched the app or arrived while signed out.
        .onChange(of: push.pendingHref, initial: true) { _, href in
            guard let href else { return }
            push.pendingHref = nil
            router.navigate(href: href)
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { shell.load() } }
        .onChange(of: router.tab) { _, _ in shell.load() }
        .onChange(of: router.path.count) { _, _ in screenChanged() }
        .onChange(of: router.inboxOpen) { _, _ in screenChanged() }
    }

    private func screenChanged() {
        // Like a tab switch: drop the keyboard, or a top-bar search field keeps focus under the
        // pushed screen and comes back with the keyboard up and the tab bar hidden.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        shell.load()
    }
}

/// The four tabs. Each is created on first visit and then kept alive, so switching tabs keeps
/// scroll positions, loaded data and in-progress searches.
private struct TabRoot: View {
    @Environment(Router.self) private var router
    @State private var visited: Set<Router.Tab> = []
    @State private var keyboardVisible = false

    var body: some View {
        ZStack {
            ForEach(Router.Tab.allCases, id: \.self) { tab in
                if visited.contains(tab) || router.tab == tab {
                    let isCurrent = router.tab == tab
                    screen(tab)
                        .opacity(isCurrent ? 1 : 0)
                        .allowsHitTesting(isCurrent)
                        .accessibilityHidden(!isCurrent)
                }
            }
        }
        // Above each tab's own top bar, whose background runs up behind it.
        .safeAreaInset(edge: .top, spacing: 0) { MembershipReminderBanner() }
        // Hidden while typing, as a system tab bar sits under the keyboard, rather than riding up on top of it.
        .floatingBottomBar { if !keyboardVisible { TabBar() } }
        .accessibilityHidden(router.inboxOpen)
        .overlay {
            ZStack {
                if router.inboxOpen { InboxPanel().transition(.move(edge: .leading)) }
            }
            .animation(.smooth(duration: 0.35), value: router.inboxOpen)
        }
        .background(Palette.gray50)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: router.tab, initial: true) { _, tab in visited.insert(tab) }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
    }

    @ViewBuilder
    private func screen(_ tab: Router.Tab) -> some View {
        switch tab {
        case .home: HomeView()
        case .network: NetworkView()
        case .colleges: CollegesView()
        case .places: PlacesView()
        }
    }
}

/// A screen pushed over the tabs, under a back-button header.
private struct PushedScreen: View {
    let route: Route
    @Environment(Router.self) private var router
    @Environment(SessionStore.self) private var session
    @Environment(ShellStore.self) private var shell

    var body: some View {
        RouteView(route: route)
            .pinnedTopBar {
                ScreenHeader(title: headerTitle) {
                    if case .profile = route {
                        ChromeCircleButton(systemImage: "gearshape", label: "Settings", size: Chrome.navHeight,
                                           badge: shell.pendingReviewCount(role: session.role)) {
                            router.navigate(to: .settings)
                        }
                    }
                }
            }
    }

    /// Detail pages and Profile title themselves in their content.
    private var headerTitle: String {
        if route.isDetail { return "" }
        if case .profile = route { return "" }
        return route.title
    }
}

/// Notifications, over the tabs and their bars. They slide in from the left, the side the bell is
/// on, and close with Back or a swipe from the right edge, mirroring a pushed screen's edge swipe.
private struct InboxPanel: View {
    @Environment(Router.self) private var router
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        PushedScreen(route: .notifications)
            .background(Palette.gray50.ignoresSafeArea())
            .offset(x: dragOffset)
            // Stays put while the panel follows the finger; as wide as the content's side padding.
            .overlay(alignment: .trailing) {
                Color.clear
                    .frame(width: 16)
                    .contentShape(Rectangle())
                    .gesture(swipeBack)
            }
    }

    private var swipeBack: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { dragOffset = min(0, $0.translation.width) }
            .onEnded { value in
                if value.translation.width < -100 || value.predictedEndTranslation.width < -200 {
                    router.pop()
                } else {
                    withAnimation(.smooth(duration: 0.25)) { dragOffset = 0 }
                }
            }
    }
}

// Port of src/components/MembershipReminderBanner.tsx
private struct MembershipReminderBanner: View {
    @Environment(SessionStore.self) private var session
    @Environment(ShellStore.self) private var shell
    @Environment(Router.self) private var router

    var body: some View {
        let isBoardMember = session.role == Role.boardMember
        let hasSubmitted: Bool? = shell.shell.map { $0.membershipStatus != nil }
        if isBoardMember, hasSubmitted == false, router.current != .membership {
            VStack(alignment: .leading, spacing: 8) {
                (Text("Action needed:").font(.custom(TW.Weight.semibold.fontName, fixedSize: 14))
                    + Text(" board members must also complete the US Member application."))
                    .tw(.sm)
                    .foregroundStyle(Palette.navy)
                Button { router.navigate(to: .membership) } label: {
                    Text("Open application →")
                        .tw(.sm, .semibold)
                        .underline()
                        .foregroundStyle(Palette.navy)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Palette.gold.opacity(0.2))
            .bottomBorder(Palette.gold, width: 2)
        }
    }
}

/// Maps a pushed route to its screen.
struct RouteView: View {
    let route: Route

    var body: some View {
        Group {
            switch route {
            case .profile(let openUnanswered): ProfileView(openUnansweredThreads: openUnanswered)
            case .notifications: NotificationsView()
            case .membership: MembershipFormView()
            case .placeDetail(let abbr): PlaceDetailView(abbr: abbr)
            case .collegeDetail(let id): CollegeDetailView(collegeId: id)
            case .compare: CompareView()
            // Tab routes switch tabs (Router.navigate) and are never pushed.
            case .feed, .threads, .network, .colleges, .places: EmptyView()
            case .memberProfile(let id): MemberProfileView(memberId: id)
            case .inbox: InboxView()
            case .blogs: BlogsView()
            case .settings: SettingsView()
            case .blockedMembers: BlockedMembersView()
            case .adminVerification: AdminVerificationView()
            case .adminPosts: AdminPostsView()
            case .adminThreadApproval: AdminThreadApprovalView()
            case .adminReports: AdminReportsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.gray50)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
    }
}

/// Keeps the edge swipe-back gesture working while the system navigation bar is hidden.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
