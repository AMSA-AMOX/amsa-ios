import SwiftUI

struct NotificationItem: Decodable, Sendable, Identifiable {
    let id: String
    let type: String
    let title: String
    let description: String?
    let happenedAt: String
    let href: String?
    let avatarUrl: String?
}

private struct NotificationsResponse: Decodable, Sendable { let notifications: [NotificationItem]? }

private enum NotificationsAPI {
    static func list() -> Endpoint<NotificationsResponse> { Endpoint(path: "/api/user/notifications") }
}

// Port of src/app/(dashboard)/dashboard/notifications/page.tsx
struct NotificationsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(ShellStore.self) private var shell
    @Environment(Router.self) private var router

    @State private var items: [NotificationItem] = []
    @State private var loadingItems = true

    private var grouped: (today: [NotificationItem], earlier: [NotificationItem]) {
        let startToday = Calendar.current.startOfDay(for: .now)
        var today: [NotificationItem] = []
        var earlier: [NotificationItem] = []
        for item in items {
            // `new Date(invalid).getTime()` is NaN, which fails `>=` → "Earlier".
            if let date = ISODate.parse(item.happenedAt), date >= startToday { today.append(item) } else { earlier.append(item) }
        }
        return (today, earlier)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if loadingItems {
                    skeleton
                } else if items.isEmpty {
                    VStack(spacing: 8) {
                        Text("No notifications yet").tw(.xl, .semibold).foregroundStyle(Palette.navy)
                        Text("New followers and event updates will show up here.")
                            .tw(.base).foregroundStyle(Palette.gray500).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 80)
                } else {
                    let groups = grouped
                    VStack(alignment: .leading, spacing: 32) {
                        section("Today", items: groups.today, empty: "No activity today.")
                        section("Earlier", items: groups.earlier, empty: "Nothing earlier.")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 40)
        }
        .task { await load() }
    }

    private func load() async {
        loadingItems = true
        do {
            let list = try await session.api.send(NotificationsAPI.list()).notifications ?? []
            items = list
            // Mark as seen with the newest server timestamp (not the client clock).
            let newest = list.compactMap { ISODate.parse($0.happenedAt) }.max()
            Preferences.notificationsSeen = ISODate.string(from: newest ?? .now)
            // `window.dispatchEvent(new Event("amsa-notif-seen"))` → refresh the badge now.
            shell.load(force: true)
        } catch {
            items = []
        }
        loadingItems = false
    }

    private var skeleton: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { i in
                if i > 0 { TWDivider() }
                HStack(spacing: 24) {
                    Circle().fill(Palette.gray200).frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 12) {
                        SkeletonBar(fraction: 1 / 3, height: 16, color: Palette.gray200)
                        SkeletonBar(fraction: 2 / 3, height: 16, color: Palette.gray200)
                    }
                }
                .padding(24)
            }
        }
        .twPulse()
    }

    private func section(_ title: String, items: [NotificationItem], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased()).tw(.sm, .semibold, tracking: .wide).foregroundStyle(Palette.gray400)
            if items.isEmpty {
                Text(empty).tw(.base).foregroundStyle(Palette.gray400).padding(.horizontal, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { TWDivider() }
                        NotificationRow(item: item) {
                            if let href = item.href { router.navigate(href: href) }
                        }
                    }
                }
            }
        }
    }
}

private struct NotificationRow: View {
    let item: NotificationItem
    let onTap: () -> Void

    var body: some View {
        let content = HStack(spacing: 16) {
            visual
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title).tw(.base, .semibold).foregroundStyle(Palette.gray900)
                Text(item.description ?? "").tw(.sm, leading: .snug).foregroundStyle(Palette.gray600).padding(.top, 2)
                Text(RelativeTime.notification.format(item.happenedAt)).tw(.xs).foregroundStyle(Palette.gray400).padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Palette.gray50)
        .contentShape(Rectangle())

        // Links to web-only pages (e.g. `/dashboard/events`) stay visible but aren't tappable.
        if let href = item.href, Route(href: href) != nil {
            Button(action: onTap) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }

    @ViewBuilder
    private var visual: some View {
        if let avatar = item.avatarUrl, !avatar.isEmpty {
            Avatar(imageURL: avatar, initials: "", size: 48)
        } else if item.type == "welcome" || item.type == "event" {
            Image("HeaderLogo").resizable().scaledToFit().frame(width: 48, height: 48)
        } else {
            ZStack {
                Circle().fill(Palette.navy.opacity(0.1))
                Icon(iconName, size: 24).foregroundStyle(Palette.navy)
            }
            .frame(width: 48, height: 48)
        }
    }

    private var iconName: String {
        switch item.type {
        case "follow": "user-plus"
        case "thread_question", "thread_answered": "chat-bubble"
        default: "bell"
        }
    }
}
