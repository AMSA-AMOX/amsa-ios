import SwiftUI
import UIKit

// Port of src/app/(dashboard)/layout.tsx — mobile layout.
struct DashboardShell: View {
    @Environment(Router.self) private var router
    @Environment(ShellStore.self) private var shell
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var router = router
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                MobileTopBar()
                    .zIndex(1)
                VStack(spacing: 0) {
                    TitleBar(title: router.current.title)
                    MembershipReminderBanner()
                    NavigationStack(path: $router.path) {
                        RouteView(route: router.root)
                            .id(router.root)
                            .navigationDestination(for: Route.self) { RouteView(route: $0) }
                    }
                }
                // The fixed top bar is 74px tall but the column only offsets `pt-16` (64px),
                // so the bar covers the title bar's top 10px — reproduced here.
                .padding(.top, -10)
            }
            .background(Palette.gray50)

            if router.drawerOpen {
                DrawerOverlay()
            }
        }
        .onAppear { shell.load() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { shell.load() } }
        .onChange(of: router.drawerOpen) { _, open in if open { shell.load() } }
    }
}

/// `md:hidden fixed top-0 … bg-gray-100 flex items-center justify-between px-4 py-3 border-b-2 border-gray-300`
private struct MobileTopBar: View {
    @Environment(Router.self) private var router

    var body: some View {
        HStack(spacing: 0) {
            Button { router.navigate(to: .profile()) } label: {
                Image("Logo").resizable().scaledToFit().frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("AMSA")
            Spacer(minLength: 0)
            Button { router.drawerOpen.toggle() } label: {
                Icon(router.drawerOpen ? "close" : "menu", size: 24)
                    .foregroundStyle(Palette.gray600)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(router.drawerOpen ? "Close menu" : "Open menu")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Palette.gray100)
        .bottomBorder(Palette.gray300, width: 2)
        .background(Palette.gray100.ignoresSafeArea(edges: .top))
    }
}

// Port of src/components/DashboardTopBar.tsx
private struct TitleBar: View {
    let title: String

    var body: some View {
        Group {
            if title.isEmpty {
                // An empty <h1> has no line box.
                Color.clear.frame(height: 0)
            } else {
                Text(title)
                    .tw(.lg, .bold)
                    .foregroundStyle(Palette.gray900)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Palette.gray50)
        .bottomBorder(Palette.gray300, width: 2)
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

/// Maps a route to its screen.
struct RouteView: View {
    let route: Route

    var body: some View {
        Group {
            switch route {
            case .profile(let openUnanswered): ProfileView(openUnansweredThreads: openUnanswered)
            case .feed: FeedView()
            case .notifications: NotificationsView()
            case .membership: MembershipFormView()
            case .places: PlacesView()
            case .placeDetail(let abbr): PlaceDetailView(abbr: abbr)
            case .colleges: CollegesView()
            case .collegeDetail(let id): CollegeDetailView(collegeId: id)
            case .compare: CompareView()
            case .threads: ThreadsView()
            case .network: NetworkView()
            case .memberProfile(let id): MemberProfileView(memberId: id)
            case .inbox: InboxView()
            case .blogs: BlogsView()
            case .settings: SettingsView()
            case .adminVerification: AdminVerificationView()
            case .adminPosts: AdminPostsView()
            case .adminThreadApproval: AdminThreadApprovalView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.gray50)
        .toolbar(.hidden, for: .navigationBar)
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
