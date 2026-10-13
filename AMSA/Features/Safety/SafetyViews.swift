import SwiftUI

// Reporting and blocking (App Store Review Guideline 1.2). Not ported from the web, which only
// reports feed posts; the server side is in website-changes/.

/// Pick a reason, add an optional note, submit; then offer to block the author.
struct ReportSheet: View {
    let request: ReportRequest

    @Environment(SafetyStore.self) private var safety
    @Environment(\.dismiss) private var dismiss

    @State private var reason: ReportReason?
    @State private var details = ""
    @State private var submitting = false
    @State private var sent = false
    @State private var blocking = false
    @State private var blocked = false
    @State private var error = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(sent ? "Report sent" : "Report this \(request.target.noun)").tw(.lg, .bold).foregroundStyle(Palette.gray900)
                Spacer(minLength: 0)
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.gray500)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Palette.gray100))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)

            ScrollView {
                if sent { confirmation } else { form }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Palette.white)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .interactiveDismissDisabled(submitting || blocking)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reports are private. AMSA moderators review them within 24 hours and remove anything that breaks the Terms of Use.")
                .tw(.sm).foregroundStyle(Palette.gray500)

            VStack(spacing: 0) {
                ForEach(ReportReason.allCases) { option in
                    if option != ReportReason.allCases.first { TWDivider(color: Palette.gray100, width: 1) }
                    Button { reason = option } label: {
                        HStack(spacing: 12) {
                            Text(option.label).tw(.base).foregroundStyle(Palette.gray900)
                            Spacer(minLength: 0)
                            Image(systemName: reason == option ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(reason == option ? Palette.navy : Palette.gray300)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(reason == option ? .isSelected : [])
                }
            }

            TextField("", text: $details, prompt: Text("Add details (optional)").foregroundStyle(Palette.gray400), axis: .vertical)
                .font(.custom(TW.Weight.normal.fontName, fixedSize: 15))
                .foregroundStyle(Palette.gray900)
                .lineLimit(3...6)
                .padding(12)
                .twBox(background: Palette.gray50, radius: TW.radiusXl, border: Palette.gray200, borderWidth: 1)

            if !error.isEmpty { Text(error).tw(.sm).foregroundStyle(Palette.red600) }

            Button(action: submit) {
                Text(submitting ? "Sending…" : "Submit report")
                    .tw(.base, .semibold).foregroundStyle(Palette.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Palette.red600))
            }
            .buttonStyle(.plain)
            .disabled(reason == nil || submitting)
            .opacity(reason == nil || submitting ? 0.5 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
    }

    private var confirmation: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Palette.green100)
                Image(systemName: "checkmark").font(.system(size: 24, weight: .bold)).foregroundStyle(Palette.green700)
            }
            .frame(width: 56, height: 56)
            .padding(.top, 16)
            Text("Thanks for letting us know. Our moderators will review this within 24 hours.")
                .tw(.base).foregroundStyle(Palette.gray700).multilineTextAlignment(.center)

            if let author = request.author {
                Button(action: { block(author) }) {
                    Text(blocked ? "\(author.firstName) is blocked" : blocking ? "Blocking…" : "Block \(author.firstName)")
                        .tw(.base, .semibold).foregroundStyle(blocked ? Palette.gray500 : Palette.red600)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(Capsule().strokeBorder(blocked ? Palette.gray200 : Palette.red500, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .disabled(blocking || blocked)
                Text("You won't see each other's posts, threads, comments or reviews, and they can't follow you or send you questions.")
                    .tw(.xs).foregroundStyle(Palette.gray400).multilineTextAlignment(.center)
            }
            if !error.isEmpty { Text(error).tw(.sm).foregroundStyle(Palette.red600) }

            Button { dismiss() } label: {
                Text("Done").tw(.base, .semibold).foregroundStyle(Palette.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Palette.navy))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
    }

    private func submit() {
        guard let reason else { return }
        submitting = true
        error = ""
        Task {
            do {
                try await safety.report(request, reason: reason, details: details)
                withAnimation(Chrome.spring) { sent = true }
            } catch let e {
                // Already reported counts as sent.
                if (e as? APIError)?.status == 409 {
                    withAnimation(Chrome.spring) { sent = true }
                } else {
                    error = e.apiMessage ?? "Couldn't send the report. Please try again."
                }
            }
            submitting = false
        }
    }

    private func block(_ author: BlockCandidate) {
        blocking = true
        error = ""
        Task {
            do {
                try await safety.block(author.id)
                blocked = true
            } catch let e {
                error = e.apiMessage ?? "Couldn't block \(author.firstName). Please try again."
            }
            blocking = false
        }
    }
}

extension View {
    /// Presents `ReportSheet` for the request.
    func reportSheet(_ request: Binding<ReportRequest?>) -> some View {
        sheet(item: request) { ReportSheet(request: $0) }
    }

    /// Asks before blocking, then blocks.
    func blockConfirmation(_ candidate: Binding<BlockCandidate?>, onBlocked: @escaping (Int) -> Void = { _ in }) -> some View {
        modifier(BlockConfirmation(candidate: candidate, onBlocked: onBlocked))
    }
}

private struct BlockConfirmation: ViewModifier {
    @Binding var candidate: BlockCandidate?
    let onBlocked: (Int) -> Void
    @Environment(SafetyStore.self) private var safety
    @State private var failure: String?

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                candidate.map { "Block \($0.name)?" } ?? "",
                isPresented: Binding(get: { candidate != nil }, set: { if !$0 { candidate = nil } }),
                titleVisibility: .visible,
                presenting: candidate
            ) { member in
                Button("Block", role: .destructive) {
                    Task {
                        do {
                            try await safety.block(member.id)
                            onBlocked(member.id)
                        } catch let e {
                            failure = e.apiMessage ?? "Couldn't block \(member.firstName). Please try again."
                        }
                    }
                }
            } message: { _ in
                Text("You won't see each other's posts, threads, comments or reviews, and they can't follow you or send you questions. You can unblock them in Settings.")
            }
            .alert(failure ?? "", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK", role: .cancel) {}
            }
    }
}

/// A "⋯" menu with Report and Block, for content that has no menu of its own.
struct SafetyMenu: View {
    let report: ReportRequest
    var onReport: (ReportRequest) -> Void
    var onBlock: ((BlockCandidate) -> Void)?
    var size: CGFloat = 16

    var body: some View {
        Menu {
            Button { onReport(report) } label: { Label("Report \(report.target.noun)", systemImage: "flag") }
            if let author = report.author, let onBlock {
                Button(role: .destructive) { onBlock(author) } label: {
                    Label("Block \(author.firstName)", systemImage: "hand.raised")
                }
            }
        } label: {
            Icon("ellipsis", size: size).foregroundStyle(Palette.gray400).padding(6).contentShape(Rectangle())
        }
        .accessibilityLabel("More")
    }
}

/// Settings › Blocked members.
struct BlockedMembersView: View {
    @Environment(SessionStore.self) private var session
    @Environment(SafetyStore.self) private var safety

    @State private var members: [BlockedMember] = []
    @State private var loading = true
    @State private var error = ""
    @State private var unblocking: Set<Int> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Blocked members can't see your posts, threads, comments or reviews, follow you, or send you questions, and you won't see theirs.")
                    .tw(.sm).foregroundStyle(Palette.gray500)
                if loading {
                    VStack(spacing: 12) { ForEach(0..<3, id: \.self) { _ in SkeletonBlock(height: 48) } }.twPulse()
                } else if !error.isEmpty {
                    Text(error).tw(.sm).foregroundStyle(Palette.red600)
                } else if members.isEmpty {
                    Text("You haven't blocked anyone.").tw(.base).foregroundStyle(Palette.gray400)
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                            if index > 0 { TWDivider() }
                            HStack(spacing: 12) {
                                Avatar(imageURL: member.profilePic, initials: member.initials, size: 40, fontSize: .xs)
                                Text(member.fullName.nilIfEmpty ?? "Member").tw(.base, .medium).foregroundStyle(Palette.gray900)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Button { unblock(member.id) } label: {
                                    Text(unblocking.contains(member.id) ? "Unblocking…" : "Unblock")
                                        .tw(.sm, .semibold).foregroundStyle(Palette.navy)
                                        .padding(.horizontal, 14).padding(.vertical, 6)
                                        .overlay(Capsule().strokeBorder(Palette.navy.opacity(0.3), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .disabled(unblocking.contains(member.id))
                            }
                            .padding(.vertical, 12)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .task { await load() }
    }

    private func load() async {
        loading = true
        do {
            members = try await session.api.send(SafetyAPI.blocks()).blocks ?? []
            error = ""
        } catch let e {
            error = e.apiMessage ?? "Couldn't load blocked members."
        }
        loading = false
    }

    private func unblock(_ id: Int) {
        unblocking.insert(id)
        Task {
            if (try? await safety.unblock(id)) != nil {
                withAnimation { members.removeAll { $0.id == id } }
            }
            unblocking.remove(id)
        }
    }
}
