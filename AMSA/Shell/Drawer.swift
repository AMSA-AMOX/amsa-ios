import SwiftUI

// Port of src/components/DashboardSidebar.tsx — the mobile drawer.
struct DrawerOverlay: View {
    @Environment(Router.self) private var router

    var body: some View {
        ZStack(alignment: .leading) {
            // `absolute inset-0 bg-black/50`
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { router.drawerOpen = false }
            // `absolute left-0 top-0 bottom-0 w-64 bg-gray-100 border-r-2 border-gray-300`
            SidebarContent()
                .frame(width: 256)
                .frame(maxHeight: .infinity)
                .background(Palette.gray100.ignoresSafeArea())
                .overlay(alignment: .trailing) { Palette.gray300.frame(width: 2).ignoresSafeArea() }
        }
    }
}

private struct NavItem: Identifiable {
    enum Section { case top, social, tools }
    let label: String
    let route: Route
    let section: Section
    var allowedRoles: [String]? = nil
    var badgeKey: KeyPath<ShellData.Pending, Int>? = nil
    let icon: String
    var id: String { route.webPath }
}

/// `navItems` in declaration order.
@MainActor private let navItems: [NavItem] = [
    NavItem(label: "Profile", route: .profile(), section: .top, icon: "nav-profile"),
    NavItem(label: "Feed", route: .feed, section: .social, icon: "nav-feed"),
    NavItem(label: "Notifications", route: .notifications, section: .top, icon: "nav-notifications"),
    NavItem(label: "US Member Application", route: .membership, section: .top,
            allowedRoles: [Role.member, Role.boardMember], icon: "nav-membership"),
    NavItem(label: "Places", route: .places, section: .tools, icon: "nav-places"),
    NavItem(label: "Colleges", route: .colleges, section: .tools, icon: "nav-colleges"),
    NavItem(label: "Compare", route: .compare, section: .tools, icon: "nav-compare"),
    NavItem(label: "Threads", route: .threads, section: .social, icon: "nav-threads"),
    NavItem(label: "Network", route: .network, section: .social, icon: "nav-network"),
    NavItem(label: "Verification Queue", route: .adminVerification, section: .tools, allowedRoles: [Role.admin],
            badgeKey: \.verification, icon: "nav-verification"),
    NavItem(label: "Post Approval", route: .adminPosts, section: .tools, allowedRoles: [Role.admin, Role.boardMember],
            badgeKey: \.posts, icon: "nav-post-approval"),
    NavItem(label: "Thread Approval", route: .adminThreadApproval, section: .tools,
            allowedRoles: [Role.admin, Role.boardMember], badgeKey: \.threads, icon: "nav-thread-approval"),
]

struct SidebarContent: View {
    @Environment(Router.self) private var router
    @Environment(SessionStore.self) private var session
    @Environment(ShellStore.self) private var shell
    @State private var feedbackOpen = false

    var body: some View {
        let role = session.role
        let visible = navItems.filter { item in
            guard let allowed = item.allowedRoles else { return true }
            return role.map(allowed.contains) ?? false
        }
        let top = visible.filter { $0.section == .top }
        let social = visible.filter { $0.section == .social }
        let tools = visible.filter { $0.section == .tools && $0.allowedRoles == nil }
        let admin = visible.filter { $0.section == .tools && $0.allowedRoles != nil }
        let notifCount = shell.shell?.unseenNotifications ?? 0

        VStack(spacing: 0) {
            // Logo — `px-6 py-5`, `h-14`
            HStack {
                Image("Logo").resizable().scaledToFit().frame(width: 56, height: 56)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            // Nav — `flex-1 min-h-0 overflow-y-auto px-3 py-6`
            ScrollView {
                VStack(spacing: 0) {
                    section(top) { item in
                        item.route == .notifications && notifCount > 0 ? badgeText(notifCount) : nil
                    }
                    divider
                    section(social) { _ in nil }
                    divider
                    section(tools) { item in badge(for: item) }
                    if !admin.isEmpty {
                        divider
                        Text("ADMIN")
                            .tw(.xs, .semibold, tracking: .wider)
                            .foregroundStyle(Palette.gray500)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 4)
                        section(admin) { item in badge(for: item) }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 24)
            }

            footer
        }
        .webModal(isPresented: $feedbackOpen, dismissOnBackdrop: { true }) {
            FeedbackDialog(isPresented: $feedbackOpen)
        }
    }

    private var divider: some View {
        Palette.gray300.frame(height: 2).padding(.vertical, 16)
    }

    private func badge(for item: NavItem) -> String? {
        guard let key = item.badgeKey else { return nil }
        let count = shell.shell?.pending[keyPath: key] ?? 0
        return count > 0 ? badgeText(count) : nil
    }

    private func badgeText(_ count: Int) -> String { count > 9 ? "9+" : String(count) }

    @ViewBuilder
    private func section(_ items: [NavItem], badge: @escaping (NavItem) -> String?) -> some View {
        VStack(spacing: 2) {
            ForEach(items) { item in
                navLink(item, badge: badge(item))
            }
        }
    }

    /// `flex items-center gap-3 px-4 py-1.5 rounded-xl text-sm font-semibold`
    private func navLink(_ item: NavItem, badge: String?) -> some View {
        let active = router.current.webPath == item.route.webPath
        return Button { router.navigate(to: item.route) } label: {
            HStack(spacing: 12) {
                Icon(item.icon, size: 20)
                Text(item.label).tw(.sm, .semibold).lineLimit(1)
                Spacer(minLength: 0)
                if let badge {
                    Text(badge)
                        .font(.custom(TW.Weight.bold.fontName, fixedSize: 12))
                        .foregroundStyle(Palette.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Capsule().fill(Palette.red500))
                }
            }
            .foregroundStyle(active ? Palette.gray900 : Palette.gray700)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: TW.radiusXl).fill(active ? Palette.gray200 : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// User footer — `shrink-0 px-4 py-4 border-t-2 border-gray-300`
    private var footer: some View {
        let user = session.user
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                Avatar(imageURL: user?.profilePic, initials: user?.initials ?? "", size: 32, fontSize: .xs)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(user?.firstName ?? "") \(user?.lastName ?? "")")
                        .tw(.sm, .medium).foregroundStyle(Palette.gray800).lineLimit(1)
                    Text(user?.email ?? "")
                        .tw(.xs).foregroundStyle(Palette.gray500).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)

            footerButton(icon: "signout", label: "Sign out", active: false) {
                session.logout()
            }
            footerButton(icon: "feedback", label: "Send feedback", active: false) {
                feedbackOpen = true
            }
            footerButton(icon: "settings", label: "Settings", active: router.current == .settings,
                         radius: TW.radiusXl) {
                router.navigate(to: .settings)
            }
        }
        .padding(16)
        .topBorder(Palette.gray300, width: 2)
    }

    /// `w-full flex items-center gap-2 px-4 py-2 rounded-xl text-sm text-gray-700`
    private func footerButton(icon: String, label: String, active: Bool, radius: CGFloat = TW.dashboardButtonRadius,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Icon(icon, size: 16)
                Text(label).tw(.sm)
                Spacer(minLength: 0)
            }
            .foregroundStyle(active ? Palette.gray900 : Palette.gray700)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: radius).fill(active ? Palette.gray200 : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
