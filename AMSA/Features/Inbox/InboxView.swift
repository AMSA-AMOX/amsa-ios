import SwiftUI

// Port of src/app/(dashboard)/dashboard/inbox/page.tsx
struct InboxView: View {
    @Environment(SessionStore.self) private var session

    @State private var threads: [QAThread] = []
    @State private var pageLoading = true
    @State private var answerDraft: [Int: String] = [:]
    @State private var anonDraft: [Int: Bool] = [:]
    @State private var submitting: Set<Int> = []
    @State private var toggling: Set<Int> = []
    @State private var deleting: Set<Int> = []
    @State private var errors: [Int: String] = [:]

    /// The server treats ambassadors as recipients too (PATCH/DELETE allow them); the web client omitted
    /// them, which left ambassadors unable to answer here. Matches the server.
    private var isRecipient: Bool {
        [Role.usMember, Role.boardMember, Role.admin, Role.ambassador].contains(session.role ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(isRecipient ? "Questions asked directly to you." : "Questions you've sent to members.")
                    .tw(.sm).foregroundStyle(Palette.gray500)
                    .padding(.top, 4)
                    .padding(.bottom, 24)

                if pageLoading {
                    VStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { i in
                            if i > 0 { TWDivider(color: Palette.gray100, width: 1) }
                            HStack(alignment: .top, spacing: 12) {
                                Circle().fill(Palette.gray200).frame(width: 8, height: 8).padding(.top, 8)
                                Circle().fill(Palette.gray200).frame(width: 40, height: 40)
                                VStack(alignment: .leading, spacing: 8) {
                                    SkeletonBar(fraction: 1 / 3, height: 12, color: Palette.gray200)
                                    SkeletonBar(fraction: 2 / 3, height: 12, color: Palette.gray200)
                                }
                                .padding(.top, 4)
                            }
                            .padding(16)
                            .twPulse()
                        }
                    }
                    .background(Palette.white)
                } else if threads.isEmpty {
                    VStack(spacing: 4) {
                        Text(isRecipient ? "No questions yet." : "You haven't asked any questions yet.")
                            .tw(.sm, .semibold).foregroundStyle(Palette.gray500)
                        if !isRecipient {
                            Text("Visit a US member's profile and click \"Ask a Direct Question\".")
                                .tw(.xs).foregroundStyle(Palette.gray400)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 40)
                    .background(Palette.white)
                } else if isRecipient {
                    let pending = threads.filter { $0.status == "pending" }
                    let answered = threads.filter { $0.status == "answered" }
                    VStack(alignment: .leading, spacing: 24) {
                        if !pending.isEmpty { section("Pending (\(pending.count))", pending) }
                        if !answered.isEmpty { section("Answered (\(answered.count))", answered) }
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(threads.enumerated()), id: \.element.id) { index, thread in
                            if index > 0 { TWDivider(color: Palette.gray100, width: 1) }
                            SentThreadRow(thread: thread)
                        }
                    }
                    .background(Palette.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .task { await load() }
    }

    private func section(_ title: String, _ items: [QAThread]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).tw(.sm, .semibold, tracking: .wide).foregroundStyle(Palette.gray500).padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, thread in
                    if index > 0 { TWDivider(color: Palette.gray100, width: 1) }
                    VStack(alignment: .leading, spacing: 0) {
                        ReceivedThreadRow(
                            thread: thread,
                            answerDraft: Binding(get: { answerDraft[thread.id] ?? "" }, set: { answerDraft[thread.id] = $0 }),
                            isAnonDraft: Binding(get: { anonDraft[thread.id] ?? false }, set: { anonDraft[thread.id] = $0 }),
                            onSubmit: { answer(thread.id) },
                            onToggleAnon: { toggleAnon(thread.id) },
                            onDelete: { delete(thread.id) },
                            submitting: submitting.contains(thread.id),
                            toggling: toggling.contains(thread.id),
                            deleting: deleting.contains(thread.id)
                        )
                        if let error = errors[thread.id], !error.isEmpty {
                            Text(error).tw(.xs).foregroundStyle(Palette.red500).padding(.horizontal, 16).padding(.bottom, 12)
                        }
                    }
                }
            }
            .background(Palette.white)
        }
    }

    // MARK: Data

    private func load() async {
        pageLoading = true
        threads = (try? await session.api.send(QAThreadsAPI.inbox()))?.threads ?? []
        pageLoading = false
    }

    private func answer(_ id: Int) {
        let text = (answerDraft[id] ?? "").trimmed
        guard !text.isEmpty, !submitting.contains(id) else { return }
        submitting.insert(id)
        errors[id] = ""
        Task {
            do {
                let data = try await session.api.send(QAThreadsAPI.answer(id, answer: text, isAnonymous: anonDraft[id] ?? false))
                if let updated = data.thread, let index = threads.firstIndex(where: { $0.id == id }) { threads[index] = updated }
                answerDraft[id] = nil
                anonDraft[id] = nil
            } catch let e {
                errors[id] = e.apiMessage ?? "Failed to save answer."
            }
            submitting.remove(id)
        }
    }

    private func toggleAnon(_ id: Int) {
        guard !toggling.contains(id), let thread = threads.first(where: { $0.id == id }) else { return }
        toggling.insert(id)
        Task {
            do {
                _ = try await session.api.send(QAThreadsAPI.setAnonymous(id, !thread.isAnonymous))
                if let index = threads.firstIndex(where: { $0.id == id }) { threads[index].isAnonymous.toggle() }
            } catch let e {
                errors[id] = e.apiMessage ?? "Failed to update anonymity."
            }
            toggling.remove(id)
        }
    }

    private func delete(_ id: Int) {
        guard !deleting.contains(id) else { return }
        deleting.insert(id)
        Task {
            do {
                _ = try await session.api.send(QAThreadsAPI.delete(id))
                threads.removeAll { $0.id == id }
            } catch let e {
                errors[id] = e.apiMessage ?? "Failed to delete thread."
            }
            deleting.remove(id)
        }
    }
}

/// `Avatar` on the inbox page: gold circle, `text-sm font-bold`, "?" without a user.
private struct InboxAvatar: View {
    let user: ThreadUser?
    var size: CGFloat = 40
    var body: some View {
        Avatar(imageURL: user?.profilePic, initials: user.map { $0.initials } ?? "?", size: size, fontSize: .sm)
    }
}

private struct ReceivedThreadRow: View {
    let thread: QAThread
    @Binding var answerDraft: String
    @Binding var isAnonDraft: Bool
    let onSubmit: () -> Void
    let onToggleAnon: () -> Void
    let onDelete: () -> Void
    let submitting: Bool
    let toggling: Bool
    let deleting: Bool

    @State private var confirmDelete = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(thread.status == "pending" ? Palette.navy : .clear).frame(width: 8, height: 8).padding(.top, 8)
            InboxAvatar(user: thread.asker)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(thread.asker.map { $0.fullName } ?? "Member").tw(.sm, .semibold).foregroundStyle(Palette.gray900)
                    Spacer(minLength: 0)
                    Text(RelativeTime.shortMonth.format(thread.createdAt)).tw(.xs).foregroundStyle(Palette.gray400)
                }
                .padding(.bottom, 2)
                Text(thread.question).tw(.sm, leading: .snug).foregroundStyle(Palette.gray700)

                Group {
                    if thread.status == "answered" { answeredBlock } else { answerForm }
                }
                .padding(.top, 12)
            }
        }
        .padding(16)
    }

    private var answeredBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                InboxAvatar(user: thread.recipient, size: 24)
                Text(thread.recipient.map { $0.fullName } ?? "You").tw(.xs, .medium).foregroundStyle(Palette.gray500)
            }
            .padding(.bottom, 6)
            Text(thread.answer ?? "").tw(.sm, leading: .relaxed).foregroundStyle(Palette.gray600)
            HStack(spacing: 12) {
                Button(action: onToggleAnon) {
                    Text(toggling ? "Updating…" : thread.isAnonymous ? "Make public" : "Go anonymous")
                        .tw(.xs, .medium).foregroundStyle(Palette.gray400)
                }
                .buttonStyle(.plain)
                .disabled(toggling || deleting)
                .opacity(toggling || deleting ? 0.5 : 1)
                if thread.isAnonymous {
                    Text("Anonymous").tw(.xs, .medium).foregroundStyle(Palette.gray400)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(Palette.gray100))
                }
                Spacer(minLength: 0)
                if confirmDelete {
                    HStack(spacing: 8) {
                        Text("Delete this thread?").tw(.xs).foregroundStyle(Palette.gray500)
                        Button {
                            confirmDelete = false
                            onDelete()
                        } label: {
                            Text(deleting ? "Deleting…" : "Yes, delete").tw(.xs, .semibold).foregroundStyle(Palette.red500)
                        }
                        .buttonStyle(.plain)
                        .disabled(deleting)
                        Button { confirmDelete = false } label: {
                            Text("Cancel").tw(.xs).foregroundStyle(Palette.gray400)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button { confirmDelete = true } label: {
                        Text("Delete").tw(.xs, .medium).foregroundStyle(Palette.red400)
                    }
                    .buttonStyle(.plain)
                    .disabled(deleting || toggling)
                    .opacity(deleting || toggling ? 0.5 : 1)
                }
            }
            .padding(.top, 12)
        }
    }

    private var answerForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            WebTextArea(placeholder: "Write your answer… (max 2000 chars)", text: $answerDraft,
                        style: InputStyle(size: .sm, radius: TW.radiusXl, textColor: Palette.gray800, focusBorder: nil),
                        rows: 3, maxLength: 2000)
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    WebCheckbox(isOn: $isAnonDraft)
                    Text("Post anonymously").tw(.xs).foregroundStyle(Palette.gray500)
                        .onTapGesture { isAnonDraft.toggle() }
                }
                Spacer(minLength: 0)
                let disabled = submitting || answerDraft.trimmed.isEmpty
                Button(action: onSubmit) {
                    Text(submitting ? "Saving…" : "Submit answer")
                        .tw(.sm, .semibold)
                        .foregroundStyle(Palette.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).fill(Palette.navy))
                }
                .buttonStyle(.plain)
                .disabled(disabled)
                .opacity(disabled ? 0.5 : 1)
            }
            if isAnonDraft {
                Text("Your name won't appear on your profile or the public feed for this answer.")
                    .tw(.xs).foregroundStyle(Palette.gray400)
            }
        }
    }
}

private struct SentThreadRow: View {
    let thread: QAThread

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(thread.status == "pending" ? Palette.navy : .clear).frame(width: 8, height: 8).padding(.top, 8)
            InboxAvatar(user: thread.recipient)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(thread.recipient.map { $0.fullName } ?? "Someone").tw(.sm, .semibold).foregroundStyle(Palette.gray900)
                    Spacer(minLength: 0)
                    Text(RelativeTime.shortMonth.format(thread.createdAt)).tw(.xs).foregroundStyle(Palette.gray400)
                }
                .padding(.bottom, 2)
                Text(thread.question).tw(.sm, leading: .snug).foregroundStyle(Palette.gray700)
                Group {
                    if let answer = thread.answer, !answer.isEmpty {
                        Text(answer).tw(.sm, leading: .relaxed).foregroundStyle(Palette.gray600)
                    } else {
                        Text("Awaiting answer…").tw(.sm).italic().foregroundStyle(Palette.gray400)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
    }
}
