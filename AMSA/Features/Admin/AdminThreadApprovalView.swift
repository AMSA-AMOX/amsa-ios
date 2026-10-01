// Port of src/app/(dashboard)/dashboard/admin/thread-approval/page.tsx
import SwiftUI

struct AdminThreadApprovalView: View {
    @Environment(SessionStore.self) private var session
    @Environment(ShellStore.self) private var shell
    @Environment(Router.self) private var router

    @State private var threads: [HubThread] = []
    @State private var pageLoading = true
    @State private var alertMessage: String?

    private var isBoardPlus: Bool { session.role == Role.boardMember || session.role == Role.admin }

    var body: some View {
        Group {
            if isBoardPlus {
                content
            } else {
                Color.clear
            }
        }
        .onAppear { if !isBoardPlus { router.navigate(to: .threads) } }
        .task { if isBoardPlus { await loadPending() } }
        .alert(alertMessage ?? "", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Review and approve community posts before they appear on the public feed.")
                    .tw(.sm).foregroundStyle(Palette.gray500)
                    .padding(.top, 4)
                    .padding(.bottom, 24)

                if pageLoading {
                    VStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { _ in
                            Color.clear.frame(height: 112)
                                .twBox(background: Palette.white, radius: TW.radius2xl, border: Palette.gray100)
                                .twShadow(.sm)
                                .twPulse()
                        }
                    }
                } else if threads.isEmpty {
                    AdminCard(padding: 40) {
                        VStack(spacing: 4) {
                            Text("No pending posts.").tw(.sm, .semibold).foregroundStyle(Palette.gray500)
                            Text("All posts have been reviewed.").tw(.xs).foregroundStyle(Palette.gray400)
                        }
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        // `mb-1` beats `space-y-3` (a zero-specificity `:where()` margin), so 4pt here.
                        Text("\(threads.count) post\(threads.count != 1 ? "s" : "") awaiting review")
                            .tw(.xs).foregroundStyle(Palette.gray500)
                            .padding(.bottom, 4 - 12)
                        ForEach(threads) { thread in
                            PendingThreadCard(thread: thread) {
                                Task { await moderate(thread.id, status: "approved") }
                            } onReject: {
                                Task { await moderate(thread.id, status: "rejected") }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
    }

    private func loadPending() async {
        pageLoading = true
        threads = (try? await session.api.send(HubThreadsAPI.pending()))?.threads ?? []
        pageLoading = false
    }

    private func moderate(_ id: Int, status: String) async {
        do {
            _ = try await session.api.send(HubThreadsAPI.moderate(id, status: status))
            threads.removeAll { $0.id == id }
            shell.invalidate()
        } catch {
            alertMessage = error.apiMessage ?? "Failed to moderate thread."
        }
    }
}

/// `PendingCard`
private struct PendingThreadCard: View {
    let thread: HubThread
    let onApprove: () -> Void
    let onReject: () -> Void

    private var askerName: String {
        if thread.isAnon { return "Anonymous" }
        return thread.asker.map(\.fullName) ?? "Member"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                FlowLayout(spacing: 8, alignment: .leading) {
                    SchoolBadge(category: thread.category, categoryDomain: thread.categoryDomain)
                    if thread.isAnon {
                        Text("?").font(.custom(TW.Weight.bold.fontName, fixedSize: 8)).foregroundStyle(Palette.gray400)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Palette.gray200))
                    } else {
                        Avatar(imageURL: thread.asker?.profilePic, initials: thread.asker?.initials ?? "?", size: 20,
                               fontSize: .px(9))
                    }
                    Text("\(askerName) · \(RelativeTime.agoMonth.format(thread.createdAt))")
                        .tw(.xs).foregroundStyle(Palette.gray400)
                }
                .padding(.bottom, 8)

                Text(thread.title).tw(.base, .semibold, leading: .snug).foregroundStyle(Palette.gray900)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let body = thread.body, !body.isEmpty {
                    Text(body).tw(.sm).foregroundStyle(Palette.gray500).lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }

                if !thread.images.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(thread.images.prefix(3).enumerated()), id: \.offset) { _, url in
                            RemoteImage(url) { phase in
                                if let image = phase.image { Image(uiImage: image).resizable().scaledToFill() } else { Color.clear }
                            }
                            .frame(width: 56, height: 56)
                            .background(Palette.gray100)
                            .clipShape(RoundedRectangle(cornerRadius: TW.radiusLg))
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            HStack(spacing: 8) {
                Text("Pending review").tw(.xs, .medium).foregroundStyle(Palette.amber700)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onApprove) {
                    Text("Approve").tw(.xs, .semibold).foregroundStyle(Palette.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).fill(Palette.navy))
                }
                .buttonStyle(.plain)
                Button(action: onReject) {
                    Text("Reject").tw(.xs, .semibold).foregroundStyle(Palette.red600)
                        .padding(.horizontal, 13).padding(.vertical, 7)
                        .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius)
                            .strokeBorder(Palette.red200, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .padding(.top, 1) // `border-t` sits outside the padding
            .background(Palette.amber50.opacity(0.5))
            .topBorder(Palette.amber100, width: 1)
        }
        .padding(1)
        .twBox(background: Palette.white, radius: TW.radius2xl, border: Palette.amber100)
        .twShadow(.sm)
    }
}
