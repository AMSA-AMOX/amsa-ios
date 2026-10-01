// Port of src/app/(dashboard)/dashboard/admin/verification/page.tsx
import SwiftUI

struct AdminVerificationView: View {
    @Environment(SessionStore.self) private var session
    @Environment(ShellStore.self) private var shell
    @Environment(Router.self) private var router

    @State private var status: ReviewFilter = .pending
    @State private var submissions: [VerificationSubmission] = []
    @State private var selectedRoles: [String: String] = [:]
    @State private var adminNotes: [String: String] = [:]
    @State private var loadingSubmissions = true
    @State private var actionId: String?
    @State private var error: String?
    @State private var expandedId: String?

    private var isAdmin: Bool { session.role == Role.admin }
    private var pendingCount: Int { submissions.filter { $0.reviewStatus == "pending" }.count }

    var body: some View {
        Group {
            if isAdmin {
                content
            } else {
                Color.clear
            }
        }
        .onAppear { if !isAdmin { router.navigate(to: .profile()) } }
        .task(id: status) { if isAdmin { await load(status) } }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Review verification forms, assign role, and approve or reject users.")
                    .tw(.sm).foregroundStyle(Palette.gray500)
                    .padding(.top, 4)
                    .padding(.bottom, 20)

                ReviewFilterTabs(selection: $status, pendingCount: pendingCount).padding(.bottom, 20)

                if let error { AdminErrorBox(message: error).padding(.bottom, 16) }

                if loadingSubmissions {
                    AdminLoadingBlocks(height: 96)
                } else if submissions.isEmpty {
                    AdminEmptyCard(message: "No submissions for this status.")
                } else {
                    VStack(spacing: 16) {
                        ForEach(submissions) { submission in submissionCard(submission) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 32)
        }
    }

    // MARK: Card

    private func submissionCard(_ s: VerificationSubmission) -> some View {
        let expanded = expandedId == s.id
        let locked = s.reviewStatus != "pending" || actionId == s.id
        return AdminCard(padding: 20) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 16) {
                    Button { toggle(s.id) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(s.fullName ?? "").tw(.lg, .semibold).foregroundStyle(Palette.navy).lineLimit(1)
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("User ID \(s.userId)").tw(.xs).foregroundStyle(Palette.gray500)
                                if let role = s.user?.role, !role.isEmpty, role != Role.member {
                                    // Inline `<span className="ml-2 px-2 py-0.5 rounded-full bg-gray-100 text-gray-600
                                    // font-medium">` — its padding paints outside the 16pt line box.
                                    Text(Self.roleLabels[role] ?? role)
                                        .tw(.xs, .medium)
                                        .foregroundStyle(Palette.gray600)
                                        .padding(.horizontal, 8)
                                        .background(Capsule().fill(Palette.gray100).padding(.vertical, -1.2))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button { toggle(s.id) } label: {
                        HStack(spacing: 4) {
                            Text(expanded ? "Collapse" : "Expand").tw(.sm, .medium)
                            Icon("chevron-down", size: 16).rotationEffect(.degrees(expanded ? 180 : 0))
                        }
                        .foregroundStyle(Palette.gray600)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).fill(Palette.gray100))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                }

                if expanded { details(s, locked: locked).padding(.top, 16) }
            }
        }
    }

    @ViewBuilder
    private func details(_ s: VerificationSubmission, locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                Text("Submitted \(ISODate.parse(s.createdAt).map(Formatters.localeDateTime) ?? "Invalid Date")")
                    .tw(.xs).foregroundStyle(Palette.gray500)
                Spacer(minLength: 0)
                ReviewStatusPill(status: s.reviewStatus)
            }

            VStack(alignment: .leading, spacing: 12) {
                VerificationInfo(label: "Email", value: s.email)
                VerificationInfo(label: "Phone", value: s.phone)
                VerificationInfo(label: "Pronouns", value: s.pronouns.nilIfEmpty ?? "-")
                VerificationInfo(label: "University", value: s.enrolledUniversity)
                VerificationInfo(label: "Year in School", value: s.yearInSchool)
                VerificationInfo(label: "Major", value: s.major)
                VerificationInfo(label: "Expected Graduation", value: s.expectedGraduation)
                VerificationInfo(label: "Location", value: "\(s.city ?? "null"), \(s.state ?? "null")")
                VerificationInfo(label: "Mentorship Interest", value: s.mentorshipInterest)
            }

            VStack(alignment: .leading, spacing: 12) {
                VerificationInfo(label: "Career Interests",
                                 value: Self.joined(s.careerInterests.joined(separator: ", "), other: s.careerInterestsOther))
                VerificationInfo(label: "AMSA Interests",
                                 value: Self.joined(s.amsaInterests.joined(separator: ", "), other: s.amsaInterestsOther))
                VerificationInfo(label: "Heard About AMSA",
                                 value: Self.joined(s.heardAboutAmsa ?? "", other: s.heardAboutAmsaOther))
                VerificationInfo(label: "Instagram", value: s.socialMedia,
                                 href: s.socialMedia.nilIfEmpty.map(Self.instagramURL))
            }

            if let ideas = s.eventIdeas, !ideas.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    AdminFieldLabel(text: "Event Ideas")
                    Text(ideas).tw(.sm).foregroundStyle(Palette.gray700)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    AdminFieldLabel(text: "Assign Role")
                    WebSelect(
                        options: [("Member", Role.member), ("US Member", Role.usMember)],
                        selection: Binding(get: { selectedRoles[s.id] ?? Role.member },
                                           set: { selectedRoles[s.id] = $0 }),
                        style: .adminNote,
                        showsChevron: true,
                        disabled: locked
                    )
                }
                VStack(alignment: .leading, spacing: 4) {
                    AdminFieldLabel(text: "Admin Note")
                    WebTextArea(placeholder: "",
                                text: Binding(get: { adminNotes[s.id] ?? "" }, set: { adminNotes[s.id] = $0 }),
                                style: .adminNote, rows: 2, disabled: locked)
                }
            }

            FlowLayout(spacing: 8) {
                AdminSolidButton(title: "Approve", color: Palette.green600, disabled: locked) {
                    Task { await review(s, status: "approved") }
                }
                AdminSolidButton(title: "Reject", color: Palette.red600, disabled: locked) {
                    Task { await review(s, status: "rejected") }
                }
            }
        }
    }

    // MARK: Data

    private func toggle(_ id: String) { expandedId = expandedId == id ? nil : id }

    private func load(_ nextStatus: ReviewFilter) async {
        loadingSubmissions = true
        error = nil
        do {
            let rows = try await session.api.send(AdminAPI.verification(status: nextStatus.rawValue)).submissions ?? []
            if Task.isCancelled { return }
            submissions = rows
            if let current = expandedId, !rows.contains(where: { $0.id == current }) { expandedId = nil }
            for row in rows {
                if selectedRoles[row.id] == nil { selectedRoles[row.id] = row.assignedRole ?? Role.member }
                if adminNotes[row.id] == nil { adminNotes[row.id] = row.adminNote ?? "" }
            }
        } catch {
            // A newer tab selection cancelled this request; that load owns the state now.
            if Task.isCancelled { return }
            self.error = error.apiMessage ?? "Failed to load submissions"
            submissions = []
        }
        loadingSubmissions = false
    }

    private func review(_ s: VerificationSubmission, status reviewStatus: String) async {
        actionId = s.id
        error = nil
        do {
            _ = try await session.api.send(AdminAPI.reviewVerification(
                s.id, status: reviewStatus,
                assignedRole: reviewStatus == "approved" ? selectedRoles[s.id] ?? Role.member : nil,
                adminNote: adminNotes[s.id] ?? ""))
            shell.invalidate()
            await load(status)
        } catch {
            self.error = error.apiMessage ?? "Failed to update submission"
        }
        actionId = nil
    }

    // MARK: Helpers

    private static let roleLabels: [String: String] = [
        Role.admin: "Admin", Role.boardMember: "Board Member", Role.ambassador: "Ambassador",
        Role.usMember: "US Member", Role.alum: "Alum", Role.member: "Member",
    ]

    /// `[main, other ? `Other: ${other}` : ""].filter(Boolean).join(" | ")`
    private static func joined(_ main: String, other: String?) -> String {
        [main, other.nilIfEmpty.map { "Other: \($0)" } ?? ""].filter { !$0.isEmpty }.joined(separator: " | ")
    }

    /// `instagramUrl` in src/lib/membership.ts.
    private static func instagramURL(_ handle: String) -> String {
        "https://instagram.com/\(handle.hasPrefix("@") ? String(handle.dropFirst()) : handle)"
    }
}

/// `Info`: uppercase label + value (`value || "-"`), or an underlined link when `href` is set.
private struct VerificationInfo: View {
    @Environment(ExternalLinkPresenter.self) private var links
    let label: String
    let value: String?
    var href: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            AdminFieldLabel(text: label)
            if let href, let value, !value.isEmpty {
                Button { links.open(href) } label: {
                    Text(value).tw(.sm).foregroundStyle(Palette.navy)
                        .underline()
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
            } else {
                Text(value.nilIfEmpty ?? "-").tw(.sm).foregroundStyle(Palette.gray700)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
