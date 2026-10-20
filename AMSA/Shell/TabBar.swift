import SwiftUI
import UIKit

/// The pill bar under every tab: notifications, the four tabs, profile avatar. The selected tab
/// expands to show its name; Profile opens as a pushed screen, Notifications as a panel from the left.
struct TabBar: View {
    @Environment(Router.self) private var router
    @Environment(SessionStore.self) private var session
    @Environment(ShellStore.self) private var shell
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 6) {
            ChromeCircleButton(systemImage: "bell", label: "Notifications", size: Chrome.navHeight,
                               badge: shell.shell?.unseenNotifications ?? 0) {
                router.navigate(to: .notifications)
            }
            ForEach(Router.Tab.allCases, id: \.self) { tab in
                pill(tab)
            }
            avatar.padding(.leading, 4)
        }
    }

    private var avatar: some View {
        let user = session.user
        return Button { router.navigate(to: .profile()) } label: {
            Avatar(imageURL: user?.profilePic, initials: user?.initials ?? "", size: Chrome.navHeight - 4, fontSize: .sm)
                .padding(2)
                .overlay(Circle().stroke(Palette.gray200, lineWidth: 1))
        }
        .buttonStyle(ChromePressStyle())
        .overlay(alignment: .topTrailing) {
            if shell.pendingReviewCount(role: session.role) > 0 {
                Circle().fill(Palette.red500).frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Palette.gray50, lineWidth: 2))
                    .allowsHitTesting(false)
            }
        }
        .accessibilityLabel("Profile")
    }

    private func pill(_ tab: Router.Tab) -> some View {
        let selected = router.tab == tab
        return Button { select(tab) } label: {
            HStack(spacing: 6) {
                Image(systemName: selected ? tab.selectedSymbol : tab.symbol)
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 20)
                if selected {
                    Text(tab.title)
                        .tw(.px(15), .semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
                }
            }
            .foregroundStyle(selected ? Palette.white : Palette.gray700)
            .padding(.horizontal, selected ? 12 : 0)
            .frame(width: selected ? nil : Chrome.navHeight, height: Chrome.navHeight)
            .frame(maxWidth: selected ? .infinity : nil)
            .background {
                if selected {
                    Capsule().fill(Palette.navy).matchedGeometryEffect(id: "selected-tab", in: selection)
                }
            }
            .chromeSurface(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(ChromePressStyle())
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func select(_ tab: Router.Tab) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        guard router.tab != tab else { return }
        withAnimation(Chrome.spring) { router.tab = tab }
    }
}

extension Router.Tab {
    var title: String {
        switch self {
        case .home: "Home"
        case .network: "Network"
        case .colleges: "Colleges"
        case .places: "Places"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .network: "person.2"
        case .colleges: "building.columns"
        case .places: "map"
        }
    }

    var selectedSymbol: String { symbol + ".fill" }
}

extension ShellStore {
    /// Items waiting in the moderation queues this role can open (Settings › Admin).
    func pendingReviewCount(role: String?) -> Int {
        guard let pending = shell?.pending else { return 0 }
        switch role {
        case Role.admin: return pending.verification + pending.posts + pending.threads + (pending.reports ?? 0)
        case Role.boardMember: return pending.posts + pending.threads + (pending.reports ?? 0)
        default: return 0
        }
    }
}

/// The bar on top of every pushed screen: back on the left, an optional action on the right.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: Trailing
    @Environment(Router.self) private var router

    var body: some View {
        HStack(spacing: 12) {
            ChromeCircleButton(systemImage: "chevron.left", label: "Back", size: Chrome.navHeight) { router.pop() }
            Spacer(minLength: 0)
            trailing
        }
        .overlay {
            Text(title)
                .tw(.base, .semibold)
                .foregroundStyle(Palette.gray900)
                .lineLimit(1)
                .padding(.horizontal, Chrome.navHeight + 24)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}
