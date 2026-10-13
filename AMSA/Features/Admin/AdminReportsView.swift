// The reports queue (website-changes/src/app/(dashboard)/dashboard/admin/reports/page.tsx).
import SwiftUI

struct ContentReport: Decodable, Sendable, Identifiable, Equatable {
    struct Person: Decodable, Sendable, Equatable {
        let id: Int
        let firstName: String?
        let lastName: String?
        let profilePic: String?

        var fullName: String { "\(firstName ?? "") \(lastName ?? "")".trimmed.nilIfEmpty ?? "Member" }
    }

    let id: Int
    let targetType: String
    let targetLabel: String
    let targetId: String
    let reasonLabel: String
    let details: String?
    let createdAt: String
    let reporter: Person?
    let author: Person?
    /// nil when the content was already deleted.
    let preview: String?
    let href: String?
}

enum AdminReportsAPI {
    struct ListResponse: Decodable, Sendable { let reports: [ContentReport]? }

    static func list() -> Endpoint<ListResponse> { Endpoint(path: "/api/admin/reports") }

    static func resolve(_ id: Int, action: String) -> Endpoint<Empty> {
        Endpoint(method: .patch, path: "/api/admin/reports/\(id)", body: ["action": .string(action)])
    }
}

struct AdminReportsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(ShellStore.self) private var shell
    @Environment(Router.self) private var router

    @State private var reports: [ContentReport] = []
    @State private var pageLoading = true
    @State private var busy: Set<Int> = []
    @State private var confirmRemove: ContentReport?
    @State private var alertMessage: String?

    private var isModerator: Bool { session.role == Role.boardMember || session.role == Role.admin }

    var body: some View {
        Group {
            if isModerator { content } else { Color.clear }
        }
        .onAppear { if !isModerator { router.redirect(to: .profile()) } }
        .task { if isModerator { await load() } }
        .refreshable { await load() }
        .confirmationDialog(
            confirmRemove?.targetType == "user" ? "Clear this member's photo, headline and bio?" : "Delete this content for everyone?",
            isPresented: Binding(get: { confirmRemove != nil }, set: { if !$0 { confirmRemove = nil } }),
            titleVisibility: .visible,
            presenting: confirmRemove
        ) { report in
            Button(report.targetType == "user" ? "Clear profile" : "Remove", role: .destructive) {
                Task { await resolve(report, action: "remove") }
            }
        } message: { _ in
            Text("This can't be undone. Every open report on it is closed.")
        }
        .alert(alertMessage ?? "", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Reports from members. The Terms promise action within 24 hours: remove content that breaks the rules, or dismiss the report.")
                    .tw(.sm).foregroundStyle(Palette.gray500)
                    .padding(.bottom, 12)

                if pageLoading {
                    ForEach(0..<3, id: \.self) { _ in
                        Color.clear.frame(height: 112)
                            .twBox(background: Palette.white, radius: TW.radius2xl, border: Palette.gray100)
                            .twPulse()
                    }
                } else if reports.isEmpty {
                    AdminCard(padding: 40) {
                        VStack(spacing: 4) {
                            Text("No open reports.").tw(.sm, .semibold).foregroundStyle(Palette.gray500)
                            Text("Everything has been reviewed.").tw(.xs).foregroundStyle(Palette.gray400)
                        }
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    Text("\(reports.count) open report\(reports.count != 1 ? "s" : "")").tw(.xs).foregroundStyle(Palette.gray500)
                    ForEach(reports) { report in card(report) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    private func card(_ report: ContentReport) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                FlowLayout(spacing: 6, lineSpacing: 4) {
                    Text(report.targetLabel).tw(.xs, .semibold).foregroundStyle(Palette.red700)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(Palette.red50))
                    Text(report.reasonLabel).tw(.xs, .semibold).foregroundStyle(Palette.gray700)
                    Text("· by \(report.reporter?.fullName ?? "Unknown") · \(RelativeTime.agoMonth.format(report.createdAt))")
                        .tw(.xs).foregroundStyle(Palette.gray400)
                }
                if let author = report.author {
                    Text("Posted by \(author.fullName)").tw(.xs).foregroundStyle(Palette.gray500)
                }
                if let preview = report.preview {
                    Text(preview.nilIfEmpty ?? "(no text)").tw(.sm, leading: .relaxed).foregroundStyle(Palette.gray800)
                } else {
                    Text("This content was already deleted.").tw(.sm).italic().foregroundStyle(Palette.gray400)
                }
                if let details = report.details?.nilIfEmpty {
                    (Text("Note: ").font(.custom(TW.Weight.semibold.fontName, fixedSize: 14)) + Text(details))
                        .tw(.sm).foregroundStyle(Palette.gray600)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            HStack(spacing: 8) {
                if let href = report.href, let route = Route(href: href) {
                    Button { router.navigate(to: route) } label: {
                        Text("View in context").tw(.xs, .medium).foregroundStyle(Palette.navy)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
                let isBusy = busy.contains(report.id)
                Button { Task { await resolve(report, action: "dismiss") } } label: {
                    Text("Dismiss").tw(.xs, .semibold).foregroundStyle(Palette.gray600)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).strokeBorder(Palette.gray200, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                Button { confirmRemove = report } label: {
                    Text(report.targetType == "user" ? "Clear profile" : "Remove").tw(.xs, .semibold).foregroundStyle(Palette.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).fill(Palette.red600))
                }
                .buttonStyle(.plain)
                .disabled(isBusy || report.preview == nil)
                .opacity(isBusy || report.preview == nil ? 0.5 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Palette.red50.opacity(0.4))
            .topBorder(Palette.red100, width: 1)
        }
        .twBox(background: Palette.white, radius: TW.radius2xl, border: Palette.red100)
        .twShadow(.sm)
    }

    private func load() async {
        pageLoading = reports.isEmpty
        do {
            reports = try await session.api.send(AdminReportsAPI.list()).reports ?? []
        } catch let e {
            alertMessage = e.apiMessage ?? "Failed to load reports."
        }
        pageLoading = false
    }

    private func resolve(_ report: ContentReport, action: String) async {
        busy.insert(report.id)
        do {
            _ = try await session.api.send(AdminReportsAPI.resolve(report.id, action: action))
            // Every open report on the same item is closed together.
            withAnimation {
                reports.removeAll { $0.targetType == report.targetType && $0.targetId == report.targetId }
            }
            shell.invalidate()
        } catch let e {
            alertMessage = e.apiMessage ?? "Failed to update report."
        }
        busy.remove(report.id)
    }
}
