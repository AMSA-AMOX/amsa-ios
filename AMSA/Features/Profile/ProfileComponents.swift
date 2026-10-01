import SwiftUI

/// Profile / member-profile tab bar: `flex gap-8 border-b-2 border-gray-300 px-8`,
/// tabs `py-3.5 text-base font-semibold border-b-2 -mb-px` with an inline `borderRadius: 0`.
struct ProfileTabBar<Tab: Hashable>: View {
    let tabs: [(Tab, String)]
    @Binding var selection: Tab
    var onSelect: ((Tab) -> Void)? = nil

    var body: some View {
        HStack(spacing: 32) {
            ForEach(tabs, id: \.0) { tab, label in
                let active = selection == tab
                Button {
                    selection = tab
                    onSelect?(tab)
                } label: {
                    Text(label)
                        .tw(.base, .semibold)
                        .foregroundStyle(active ? Palette.navy : Palette.gray400)
                        .padding(.vertical, 14)
                        .overlay(alignment: .bottom) {
                            (active ? Palette.navy : Color.clear).frame(height: 2).offset(y: 1)
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .bottomBorder(Palette.gray300, width: 2)
    }
}

/// "Back to …" link: `inline-flex items-center gap-1.5 text-sm text-[#001049]` + chevron.
struct BackLink: View {
    let title: String
    var color: Color = Palette.navy
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Icon("chevron-left", size: 16)
                Text(title).tw(.sm)
            }
            .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }
}

/// `text-xs font-semibold px-2.5 py-0.5 rounded-full` role pill.
struct RolePill: View {
    let role: String
    var body: some View {
        if let style = RoleBadge.style(role) {
            Text(style.label)
                .tw(.xs, .semibold)
                .foregroundStyle(style.foreground)
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
                .background(Capsule().fill(style.background))
        }
    }
}

/// X / LinkedIn / Instagram / Facebook links in that order.
struct SocialLinksList: View {
    let x: String?
    let linkedin: String?
    let instagram: String?
    let facebook: String?
    @Environment(ExternalLinkPresenter.self) private var links

    var hasAny: Bool { [x, linkedin, instagram, facebook].contains { !($0 ?? "").isEmpty } }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row(x, icon: "brand-x", color: Palette.black, platform: .x)
            row(linkedin, icon: "brand-linkedin", color: Palette.blue700, platform: .linkedin)
            row(instagram, icon: "brand-instagram", color: Palette.pink500, platform: .instagram)
            row(facebook, icon: "brand-facebook", color: Palette.blue600, platform: .facebook)
        }
    }

    @ViewBuilder
    private func row(_ value: String?, icon: String, color: Color, platform: Social.Platform) -> some View {
        if let value, !value.isEmpty {
            Button { links.open(Social.href(value)) } label: {
                HStack(spacing: 8) {
                    Icon(icon, size: 16).foregroundStyle(color)
                    Text(Social.handle(value, platform: platform)).tw(.sm).foregroundStyle(Palette.gray600).lineLimit(1)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

/// Section with `py-6 border-b border-gray-200` and an `h2.text-lg.font-bold.text-gray-900`.
struct ProfileSection<Trailing: View, Content: View>: View {
    let title: String
    @ViewBuilder let trailing: Trailing
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title).tw(.lg, .bold).foregroundStyle(Palette.gray900)
                Spacer()
                trailing
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
        .bottomBorder(Palette.gray200, width: 1)
    }
}

extension ProfileSection where Trailing == EmptyView {
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = EmptyView()
        self.content = content()
    }
}

/// One work experience row (network profile / welcome).
struct ExperienceRow: View {
    let experience: Experience
    /// The web profile uses an en dash; the network profile a hyphen.
    var dash: String = "-"
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            LogoImage(domain: experience.logoDomain, name: experience.company, location: experience.location,
                      kind: .company, size: 12, radius: TW.radiusXl)
            VStack(alignment: .leading, spacing: 0) {
                Text(experience.jobTitle).tw(.sm, .bold, leading: .snug).foregroundStyle(Palette.gray900)
                (Text(experience.company)
                    + Text(experience.employmentType.map { " · \($0)" } ?? "").foregroundColor(Palette.gray400))
                    .tw(.sm)
                    .foregroundStyle(Palette.gray600)
                    .padding(.top, 2)
                Text(dateLine).tw(.xs).foregroundStyle(Palette.gray400).padding(.top, 2)
                if let description = experience.description, !description.isEmpty {
                    Text(description).tw(.sm, leading: .relaxed).foregroundStyle(Palette.gray500).padding(.top, 6)
                }
            }
            Spacer(minLength: 0)
            if let trailing { trailing }
        }
    }

    private var dateLine: String {
        var s = "\(experience.startMonth ?? "") \(experience.startYear?.value ?? "")"
        if experience.currentlyWorking {
            s += " \(dash) Present"
        } else if let endMonth = experience.endMonth, !endMonth.isEmpty, let endYear = experience.endYear?.value, !endYear.isEmpty {
            s += " \(dash) \(endMonth) \(endYear)"
        }
        if let location = experience.location, !location.isEmpty { s += " · \(location)" }
        return s
    }
}

/// `rounded-lg border-2 border-gray-300 text-sm font-medium text-gray-700` outline button (4px as a dashboard button).
struct OutlineButton: View {
    let title: String
    var fullWidth: Bool = false
    var horizontalPadding: CGFloat = 16
    var verticalPadding: CGFloat = 10
    var disabled: Bool = false
    var disabledOpacity: Double = 0.6
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .tw(.sm, .medium)
                .foregroundStyle(Palette.gray700)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).strokeBorder(Palette.gray300, lineWidth: 2))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? disabledOpacity : 1)
    }
}

/// Role badges on network cards/profiles.
enum RoleBadge {
    static func style(_ role: String) -> (label: String, background: Color, foreground: Color)? {
        switch role {
        case Role.boardMember: ("Board Member", Palette.purple50, Palette.purple600)
        case Role.ambassador: ("Ambassador", Palette.amber50, Palette.amber600)
        case Role.usMember: ("US Member", Palette.blue50, Palette.blue600)
        case Role.alum: ("Alum", Palette.emerald50, Palette.emerald600)
        default: nil
        }
    }
}
