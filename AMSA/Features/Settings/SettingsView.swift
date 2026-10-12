import SwiftUI

// Port of src/app/(dashboard)/dashboard/settings/page.tsx
struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(ShellStore.self) private var shell
    @Environment(Router.self) private var router
    @Environment(ExternalLinkPresenter.self) private var links

    /// Must match CONFIRMATION_WORD in src/app/api/user/account/route.ts.
    static let confirmationWord = "DELETE"

    @State private var me: UserProfile?
    @State private var loadingMe = true
    @State private var loadError = ""
    @State private var confirmOpen = false
    @State private var feedbackOpen = false
    @State private var signOutConfirm = false

    var body: some View {
        ScrollView {
            // The app's own actions stay reachable when the account details fail to load.
            VStack(alignment: .leading, spacing: 40) {
                if loadingMe { skeleton }
                if !loadingMe, !loadError.isEmpty {
                    Text(loadError).tw(.sm).foregroundStyle(Palette.red600)
                }
                if !loadingMe, let me { content(me) }
                linkSections
                signOutButton
                dangerZone
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .task { await load() }
        .webModal(isPresented: $confirmOpen, dismissOnBackdrop: { true }) {
            DeleteAccountDialog(isPresented: $confirmOpen) { session.logout() }
        }
        .webModal(isPresented: $feedbackOpen, dismissOnBackdrop: { true }) {
            FeedbackDialog(isPresented: $feedbackOpen)
        }
        .confirmationDialog("Sign out of AMSA?", isPresented: $signOutConfirm, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { session.logout() }
        }
    }

    // MARK: Links

    @ViewBuilder
    private var linkSections: some View {
        let role = session.role ?? ""
        let pending = shell.shell?.pending
        if [Role.member, Role.boardMember].contains(role) {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Membership")
                LinkRows(rows: [
                    LinkRow(symbol: "doc.text", label: "US Member Application") { router.navigate(to: .membership) },
                ])
            }
        }
        if [Role.admin, Role.boardMember].contains(role) {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Admin")
                LinkRows(rows: (role == Role.admin ? [
                    LinkRow(symbol: "checkmark.shield", label: "Verification Queue", badge: pending?.verification ?? 0) {
                        router.navigate(to: .adminVerification)
                    },
                ] : []) + [
                    LinkRow(symbol: "square.text.square", label: "Post Approval", badge: pending?.posts ?? 0) {
                        router.navigate(to: .adminPosts)
                    },
                    LinkRow(symbol: "text.bubble", label: "Thread Approval", badge: pending?.threads ?? 0) {
                        router.navigate(to: .adminThreadApproval)
                    },
                    LinkRow(symbol: "flag", label: "Reports", badge: pending?.reports ?? 0) {
                        router.navigate(to: .adminReports)
                    },
                ])
            }
        }
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Safety")
            LinkRows(rows: [
                LinkRow(symbol: "person.crop.circle.badge.xmark", label: "Blocked members") {
                    router.navigate(to: .blockedMembers)
                },
            ])
        }
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Support")
            LinkRows(rows: [
                LinkRow(symbol: "bubble.left.and.exclamationmark.bubble.right", label: "Send feedback") { feedbackOpen = true },
                LinkRow(symbol: "hand.raised", label: "Privacy Policy", external: true) {
                    links.open(AppConfig.current.privacyPolicyURL)
                },
                LinkRow(symbol: "doc.plaintext", label: "Terms & Conditions", external: true) {
                    links.open(AppConfig.current.termsURL)
                },
            ])
        }
    }

    private var signOutButton: some View {
        Button { signOutConfirm = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 15, weight: .medium))
                Text("Sign out").tw(.sm, .semibold)
            }
            .foregroundStyle(Palette.gray700)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).strokeBorder(Palette.gray300, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        loadingMe = true
        loadError = ""
        do {
            me = try await session.api.send(AuthAPI.me()).user
        } catch {
            loadError = error.apiMessage ?? "Couldn't load your account."
        }
        loadingMe = false
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 16) {
            GeometryReader { proxy in
                SkeletonBlock(color: Palette.gray200, width: proxy.size.width / 4, height: 16)
            }
            .frame(height: 16)
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { i in
                    if i > 0 { TWDivider() }
                    GeometryReader { proxy in
                        HStack {
                            SkeletonBlock(color: Palette.gray200, width: proxy.size.width / 5, height: 16)
                            Spacer()
                            SkeletonBlock(color: Palette.gray200, width: proxy.size.width * 2 / 5, height: 16)
                        }
                    }
                    .frame(height: 16)
                    .padding(.vertical, 16)
                }
            }
        }
        .twPulse()
    }

    @ViewBuilder
    private func content(_ me: UserProfile) -> some View {
        let user = session.user
        let location = [me.city, me.state].compactMap { $0?.nilIfEmpty }.joined(separator: ", ")
        let memberSince = ISODate.parse(me.createdAt).map(Formatters.monthYear) ?? "—"

        VStack(alignment: .leading, spacing: 40) {
            // Identity
            HStack(spacing: 16) {
                Avatar(imageURL: me.profilePic, initials: user?.initials ?? "", size: 64, fontSize: .lg)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(me.firstName ?? "") \(me.lastName ?? "")")
                        .tw(.base, .semibold).foregroundStyle(Palette.gray900).lineLimit(1)
                    Text(me.email ?? "").tw(.sm).foregroundStyle(Palette.gray500).lineLimit(1)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Account")
                InfoRows(rows: [
                    ("Name", "\(me.firstName ?? "") \(me.lastName ?? "")".trimmed),
                    ("Email", me.email),
                    ("Role", Role.label(me.role)),
                    ("Member since", memberSince),
                ])
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionLabel("Profile")
                    Spacer()
                    Button { router.back(to: .profile()) } label: {
                        Text("Edit profile").tw(.sm, .semibold).foregroundStyle(Palette.navy)
                    }
                    .buttonStyle(.plain)
                }
                InfoRows(rows: [
                    ("Headline", me.headline),
                    ("School", me.schoolName),
                    ("School email", me.schoolEmail),
                    ("Major", me.major),
                    ("Degree", me.degreeLevel),
                    ("Year", me.schoolYear),
                    ("Graduation year", me.graduationYear?.value),
                    ("Location", location),
                    ("Phone", me.phoneNumber),
                    ("Personal email", me.personalEmail),
                ])
            }
        }
    }

    private var dangerZone: some View {
        let isAdmin = session.user?.role == Role.admin
        return VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Danger zone", color: Palette.red500)
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Delete account").tw(.base, .semibold).foregroundStyle(Palette.gray900)
                    Text(isAdmin
                         ? "Admin accounts can't be deleted from settings. Ask another admin to change your role first."
                         : "Permanently removes your profile, posts, questions, comments, reviews, and event reservations. This can't be undone.")
                        .tw(.sm).foregroundStyle(Palette.gray500)
                }
                // `flex flex-col` stretches the button to full width on mobile.
                Button { confirmOpen = true } label: {
                    Text("Delete account")
                        .tw(.sm, .semibold)
                        .foregroundStyle(Palette.red600)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius)
                            .strokeBorder(Palette.red500, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .disabled(isAdmin)
                .opacity(isAdmin ? 0.4 : 1)
            }
            .padding(.top, 16)
            .topBorder(Palette.gray300, width: 2)
        }
    }

    private func sectionLabel(_ text: String, color: Color = Palette.gray400) -> some View {
        Text(text.uppercased()).tw(.sm, .semibold, tracking: .wide).foregroundStyle(color)
    }
}

private struct LinkRow {
    let symbol: String
    let label: String
    var badge = 0
    var external = false
    let action: () -> Void
}

/// Tappable rows in the same divided style as `InfoRows`.
private struct LinkRows: View {
    let rows: [LinkRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { TWDivider() }
                Button(action: row.action) {
                    HStack(spacing: 12) {
                        Image(systemName: row.symbol)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Palette.gray500)
                            .frame(width: 24)
                        Text(row.label).tw(.sm).foregroundStyle(Palette.gray900)
                        Spacer(minLength: 0)
                        if row.badge > 0 { CountBadge(count: row.badge) }
                        Image(systemName: row.external ? "arrow.up.right" : "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.gray400)
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct InfoRows: View {
    let rows: [(String, String?)]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { TWDivider() }
                let value = row.1?.nilIfEmpty
                HStack(alignment: .top, spacing: 24) {
                    Text(row.0).tw(.sm).foregroundStyle(Palette.gray500).fixedSize()
                    Spacer(minLength: 0)
                    Text(value ?? "Not set")
                        .tw(.sm)
                        .foregroundStyle(value == nil ? Palette.gray400 : Palette.gray900)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 12)
            }
        }
    }
}

/// Portaled dialog (outside `.dashboard`, so class radii apply).
private struct DeleteAccountDialog: View {
    @Binding var isPresented: Bool
    let onDeleted: () -> Void
    @Environment(SessionStore.self) private var session

    @State private var typed = ""
    @State private var deleting = false
    @State private var error = ""

    var body: some View {
        let confirmed = typed == SettingsView.confirmationWord
        VStack(spacing: 0) {
            HStack {
                Text("Delete your account?").tw(.lg, .bold).foregroundStyle(Palette.gray900)
                Spacer()
                Button(action: close) {
                    Icon("close", size: 20).foregroundStyle(Palette.gray400).padding(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .bottomBorder(Palette.gray100, width: 1)

            VStack(alignment: .leading, spacing: 16) {
                Text("This permanently deletes your account and everything tied to it — profile, posts, questions and comments, reviews, and event reservations. There is no way to recover it afterwards.")
                    .tw(.sm).foregroundStyle(Palette.gray700)

                VStack(alignment: .leading, spacing: 4) {
                    (Text("Type ") + Text(SettingsView.confirmationWord).font(.system(size: 14, weight: .semibold, design: .monospaced))
                        + Text(" to confirm"))
                        .tw(.sm, .semibold)
                        .foregroundStyle(Palette.gray700)
                    WebTextField(
                        placeholder: SettingsView.confirmationWord, text: $typed,
                        style: InputStyle(focusBorder: Palette.red500, focusRing: Palette.red500.opacity(0.2),
                                          monospaced: true),
                        autocapitalization: .characters,
                        autoFocus: true
                    )
                }

                if !error.isEmpty { Text(error).tw(.sm).foregroundStyle(Palette.red600) }

                HStack(spacing: 8) {
                    Spacer()
                    Button(action: close) {
                        Text("Cancel").tw(.sm, .semibold).foregroundStyle(Palette.gray600)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(deleting)
                    .opacity(deleting ? 0.5 : 1)

                    Button(action: submit) {
                        Text(deleting ? "Deleting…" : "Delete my account").tw(.sm, .semibold).foregroundStyle(Palette.white)
                            .padding(.horizontal, 20).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: TW.radiusLg).fill(Palette.red600))
                    }
                    .buttonStyle(.plain)
                    .disabled(!confirmed || deleting)
                    .opacity(!confirmed || deleting ? 0.4 : 1)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .frame(maxWidth: 448)
        .background(RoundedRectangle(cornerRadius: TW.radiusXl).fill(Palette.white))
        .clipShape(RoundedRectangle(cornerRadius: TW.radiusXl))
        .twShadow(.x2l)
    }

    private func close() {
        if deleting { return }
        isPresented = false
    }

    private func submit() {
        guard typed == SettingsView.confirmationWord else { return }
        deleting = true
        error = ""
        Task {
            do {
                _ = try await session.api.send(UserAPI.deleteAccount(confirmation: typed))
                isPresented = false
                onDeleted()
            } catch let e {
                error = e.apiMessage ?? "Something went wrong. Please try again."
                deleting = false
            }
        }
    }
}
