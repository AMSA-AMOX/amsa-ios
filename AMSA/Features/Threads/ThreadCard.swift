import SwiftUI

// Port of `ThreadCard` in src/app/(dashboard)/dashboard/threads/page.tsx — expandable with inline comments.
struct ThreadCard: View {
    let thread: HubThread
    let isAdmin: Bool
    let onDeleted: (Int) -> Void

    @Environment(SessionStore.self) private var session
    @Environment(DropdownController.self) private var dropdown

    @State private var upvoteCount: Int
    @State private var hasUpvoted: Bool
    @State private var upvoting = false
    @State private var expanded = false
    @State private var deleting = false
    @State private var confirmDelete = false
    @State private var comments: [HubComment] = []
    @State private var commentsLoaded = false
    @State private var commentsLoading = false
    @State private var commentDraft = ""
    @State private var submitting = false
    @State private var submitMsg: (text: String, ok: Bool)?
    @State private var replyCount: Int
    @State private var replyingToId: Int?
    @State private var replyDraft = ""
    @State private var replySubmitting = false

    init(thread: HubThread, isAdmin: Bool, onDeleted: @escaping (Int) -> Void) {
        self.thread = thread
        self.isAdmin = isAdmin
        self.onDeleted = onDeleted
        _upvoteCount = State(initialValue: thread.upvoteCount)
        _hasUpvoted = State(initialValue: thread.hasUpvoted)
        _replyCount = State(initialValue: thread.commentCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.bottom, 12)
            VStack(alignment: .leading, spacing: 0) {
                Text(thread.title)
                    .tw(.lg, .medium, leading: .snug)
                    .foregroundStyle(Palette.gray800)
                    .padding(.bottom, 4)
                if let body = thread.body, !body.isEmpty {
                    Text(body).tw(.base, .light, leading: .relaxed).foregroundStyle(Palette.gray500)
                }
                if !thread.images.isEmpty {
                    ImageGrid(count: thread.images.count, columns: thread.images.count == 1 ? 1 : 2) { index in
                        NaturalRemoteImage(url: thread.images[index], maxHeight: 600, radius: TW.radius2xl)
                    }
                    .padding(.top, 16)
                }
                footer.padding(.top, 20)
                if expanded { commentList.padding(.top, 16) }
            }
            .padding(.leading, 56)

            commentForm.padding(.top, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 20)
        .bottomBorder(Palette.gray200, width: 1)
        .alert("Delete this thread and all its replies?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("OK", role: .destructive) { performDelete() }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            if thread.isAnon {
                AnonAvatar(size: 44, fontSize: .sm)
            } else {
                Avatar(imageURL: thread.asker?.profilePic, initials: thread.asker?.initials ?? "?", size: 44, fontSize: .xs)
            }
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(thread.askerName).tw(.sm, .semibold).foregroundStyle(Palette.gray900).lineLimit(1)
                    SchoolBadge(category: thread.category, categoryDomain: thread.categoryDomain)
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Text(RelativeTime.agoMonth.format(thread.approvedAt ?? thread.createdAt))
                        .tw(.xs).foregroundStyle(Palette.gray400)
                    if isAdmin { menuButton }
                }
                .fixedSize()
            }
        }
    }

    private var menuButton: some View {
        let id = "thread-menu-\(thread.id)"
        return Button {
            dropdown.toggle(id, placement: .belowTrailing(offset: 28)) {
                DropdownCard(width: 144) {
                    Button {
                        dropdown.close()
                        confirmDelete = true
                    } label: {
                        HStack(spacing: 10) {
                            Icon("trash", size: 16)
                            Text(deleting ? "Deleting…" : "Delete").tw(.sm)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(Palette.red500)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(deleting)
                    .opacity(deleting ? 0.5 : 1)
                }
            }
        } label: {
            Icon("ellipsis", size: 16).foregroundStyle(Palette.gray400).padding(4)
        }
        .buttonStyle(.plain)
        .dropdownAnchor(id)
        .accessibilityLabel("More")
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 16) {
            Button(action: upvote) {
                HStack(spacing: 6) {
                    Icon("upvote", size: 24)
                    Text("\(upvoteCount)").tw(.sm, .medium)
                }
                .foregroundStyle(hasUpvoted ? Palette.navy : Palette.gray400)
            }
            .buttonStyle(.plain)
            .disabled(upvoting)
            .opacity(upvoting ? 0.5 : 1)

            Button(action: toggleExpanded) {
                HStack(spacing: 6) {
                    Icon("comment", size: 24)
                    Text("\(replyCount)").tw(.sm, .medium)
                }
                .foregroundStyle(expanded ? Palette.navy : Palette.gray400)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Comments

    @ViewBuilder
    private var commentList: some View {
        VStack(alignment: .leading, spacing: 20) {
            if commentsLoading {
                VStack(spacing: 12) {
                    ForEach(0..<2, id: \.self) { _ in
                        HStack(spacing: 12) {
                            Circle().fill(Palette.gray100).frame(width: 32, height: 32)
                            RoundedRectangle(cornerRadius: TW.radiusXl).fill(Palette.gray100).frame(height: 56)
                        }
                        .twPulse()
                    }
                }
            }
            if !commentsLoading, commentsLoaded, comments.isEmpty {
                Text("No replies yet. Be the first!").tw(.sm).foregroundStyle(Palette.gray400)
            }
            if !commentsLoading, !comments.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(comments) { comment in commentView(comment) }
                }
            }
        }
    }

    private func commentView(_ c: HubComment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                commentAvatar(c, size: 32)
                VStack(alignment: .leading, spacing: 0) {
                    commentMeta(c).padding(.bottom, 2)
                    Text(c.content).tw(.sm, leading: .relaxed).foregroundStyle(Palette.gray700)
                    HStack(spacing: 16) {
                        commentUpvote(c)
                        Button {
                            replyingToId = replyingToId == c.id ? nil : c.id
                            replyDraft = ""
                        } label: {
                            Text("Reply").tw(.xs, .medium).foregroundStyle(Palette.gray400)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 6)

                    if replyingToId == c.id {
                        CommentInput(placeholder: "Reply to \(c.authorName)...", text: $replyDraft, size: .sm,
                                     verticalPadding: 8, iconSize: 16, submitting: replySubmitting, autoFocus: true) {
                            reply(to: c.id)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            if !c.replies.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(c.replies) { r in
                        HStack(alignment: .top, spacing: 12) {
                            commentAvatar(r, size: 28)
                            VStack(alignment: .leading, spacing: 0) {
                                commentMeta(r).padding(.bottom, 2)
                                Text(r.content).tw(.sm, leading: .relaxed).foregroundStyle(Palette.gray700)
                                commentUpvote(r).padding(.top, 6)
                            }
                        }
                    }
                }
                .padding(.leading, 16)
                .overlay(alignment: .leading) { Palette.gray300.frame(width: 2) }
                .padding(.leading, 44)
                .padding(.top, 12)
            }
        }
    }

    @ViewBuilder
    private func commentAvatar(_ c: HubComment, size: CGFloat) -> some View {
        if c.isAnon {
            AnonAvatar(size: size, fontSize: .xs)
        } else {
            Avatar(imageURL: c.author?.profilePic, initials: c.author?.initials ?? "?", size: size, fontSize: .xs)
        }
    }

    private func commentMeta(_ c: HubComment) -> some View {
        HStack(spacing: 8) {
            Text(c.authorName).tw(.sm, .semibold).foregroundStyle(Palette.gray800)
            Text(RelativeTime.agoMonth.format(c.createdAt)).tw(.xs).foregroundStyle(Palette.gray400)
        }
    }

    private func commentUpvote(_ c: HubComment) -> some View {
        Button { upvoteComment(c.id) } label: {
            HStack(spacing: 4) {
                Icon("upvote", size: 16)
                if c.upvoteCount > 0 { Text("\(c.upvoteCount)").tw(.xs, c.hasUpvoted ? .semibold : .normal) }
            }
            .foregroundStyle(c.hasUpvoted ? Palette.navy : Palette.gray400)
        }
        .buttonStyle(.plain)
    }

    private var commentForm: some View {
        let user = session.user
        let initials = user?.initials.nilIfEmpty ?? "?"
        return HStack(alignment: .top, spacing: 12) {
            Avatar(imageURL: user?.profilePic, initials: initials, size: 44, fontSize: .sm)
            VStack(alignment: .leading, spacing: 0) {
                if let submitMsg {
                    Text(submitMsg.text).tw(.sm).foregroundStyle(submitMsg.ok ? Palette.green600 : Palette.red500)
                        .padding(.bottom, 6)
                }
                Text("Comment").tw(.lg, .semibold).foregroundStyle(Palette.gray800).padding(.bottom, 8)
                CommentInput(placeholder: "Add a comment...", text: $commentDraft, size: .base, verticalPadding: 10,
                             iconSize: 20, submitting: submitting, autoFocus: false, action: submitComment)
            }
        }
    }

    // MARK: Actions

    private func upvote() {
        guard !upvoting else { return }
        upvoting = true
        let previous = (upvoteCount, hasUpvoted)
        upvoteCount += hasUpvoted ? -1 : 1
        hasUpvoted.toggle()
        Task {
            do {
                let data = try await session.api.send(HubThreadsAPI.upvote(thread.id))
                upvoteCount = data.upvoteCount
                hasUpvoted = data.hasUpvoted
            } catch {
                (upvoteCount, hasUpvoted) = previous
            }
            upvoting = false
        }
    }

    private func toggleExpanded() {
        expanded.toggle()
        guard expanded, !commentsLoaded else { return }
        commentsLoading = true
        Task {
            if let data = try? await session.api.send(HubThreadsAPI.detail(thread.id)) {
                comments = data.comments ?? []
                commentsLoaded = true
            }
            commentsLoading = false
        }
    }

    private func submitComment() {
        let content = commentDraft.trimmed
        guard !content.isEmpty, !submitting else { return }
        submitting = true
        Task {
            do {
                let data = try await session.api.send(HubThreadsAPI.comment(threadId: thread.id, content: content))
                comments.append(data.comment)
                commentDraft = ""
                replyCount += 1
                submitMsg = nil
                if !expanded { expanded = true }
            } catch let e {
                submitMsg = (e.apiMessage ?? "Failed to post comment.", false)
            }
            submitting = false
        }
    }

    private func reply(to parentId: Int) {
        let content = replyDraft.trimmed
        guard !content.isEmpty, !replySubmitting else { return }
        replySubmitting = true
        Task {
            do {
                let data = try await session.api.send(HubThreadsAPI.comment(threadId: thread.id, content: content,
                                                                            parentId: parentId))
                if let index = comments.firstIndex(where: { $0.id == parentId }) {
                    comments[index].replies.append(data.comment)
                }
                replyDraft = ""
                replyingToId = nil
                replyCount += 1
            } catch let e {
                submitMsg = (e.apiMessage ?? "Failed to post reply.", false)
            }
            replySubmitting = false
        }
    }

    private func upvoteComment(_ commentId: Int) {
        func toggle(_ list: inout [HubComment]) {
            for i in list.indices {
                if list[i].id == commentId {
                    list[i].upvoteCount += list[i].hasUpvoted ? -1 : 1
                    list[i].hasUpvoted.toggle()
                } else {
                    toggle(&list[i].replies)
                }
            }
        }
        func set(_ list: inout [HubComment], _ data: UpvoteResponse) {
            for i in list.indices {
                if list[i].id == commentId {
                    list[i].upvoteCount = data.upvoteCount
                    list[i].hasUpvoted = data.hasUpvoted
                } else {
                    set(&list[i].replies, data)
                }
            }
        }
        toggle(&comments)
        Task {
            do {
                let data = try await session.api.send(HubThreadsAPI.upvoteComment(threadId: thread.id, commentId: commentId))
                set(&comments, data)
            } catch {
                toggle(&comments) // revert
            }
        }
    }

    private func performDelete() {
        deleting = true
        Task {
            if (try? await session.api.send(HubThreadsAPI.delete(thread.id))) != nil { onDeleted(thread.id) }
            deleting = false
        }
    }
}

/// `bg-gray-200 text-gray-400 font-bold "?"` circle for anonymous authors.
struct AnonAvatar: View {
    let size: CGFloat
    var fontSize: TW.Size = .xs

    var body: some View {
        ZStack {
            Circle().fill(Palette.gray200)
            Text("?").tw(fontSize, .bold).foregroundStyle(Palette.gray400)
        }
        .frame(width: size, height: size)
    }
}

/// `GrowingTextarea` with an inline send button: `rounded-3xl pl-4 pr-12 … focus:ring-2 focus:ring-[#001049]/20`.
struct CommentInput: View {
    let placeholder: String
    @Binding var text: String
    let size: TW.Size
    let verticalPadding: CGFloat
    let iconSize: CGFloat
    let submitting: Bool
    var autoFocus: Bool = false
    let action: () -> Void

    var body: some View {
        WebTextArea(
            placeholder: placeholder, text: $text,
            style: InputStyle(size: size, horizontalPadding: 16, verticalPadding: verticalPadding, radius: TW.radius3xl,
                              border: Palette.gray200, focusBorder: nil, trailingInset: 32),
            rows: 1, maxLength: 2000, growing: true, autoFocus: autoFocus, submitOnReturn: true, onSubmit: action
        )
        .overlay(alignment: .bottomTrailing) {
            if !text.trimmed.isEmpty {
                Button(action: action) {
                    Icon("send", size: iconSize).foregroundStyle(Palette.navy)
                }
                .buttonStyle(.plain)
                .disabled(submitting)
                .opacity(submitting ? 0.5 : 1)
                .padding(.trailing, 12)
                .padding(.bottom, 12)
                .accessibilityLabel("Send")
            }
        }
    }
}
