import SwiftUI

// Port of src/app/(dashboard)/welcome/page.tsx (mobile layout; the lg sidebar is hidden).
struct ProfileView: View {
    var openUnansweredThreads: Bool = false

    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router

    enum Tab: Hashable { case profile, posts, threads }
    enum ThreadsView: Hashable { case answered, unanswered }

    @State private var profile: UserProfile?
    @State private var loadingProfile = true
    @State private var membershipStatus: String?
    @State private var experiences: [Experience] = []
    @State private var educations: [Education] = []
    @State private var followersCount = 0
    @State private var followingCount = 0

    @State private var editOpen = false
    @State private var expModal: ExperienceModalState?
    @State private var eduModal: EducationModalState?

    @State private var activeTab: Tab = .profile
    @State private var posts: [PostItem] = []
    @State private var loadingPosts = false
    @State private var postsLoaded = false
    @State private var appreciating: Set<Int> = []
    @State private var deletingPost: Set<Int> = []
    @State private var threads: [QAThread] = []
    @State private var loadingThreads = false
    @State private var threadsLoaded = false
    @State private var pendingThreads: [QAThread] = []
    @State private var pendingLoading = false
    @State private var pendingLoaded = false
    @State private var threadsView: ThreadsView = .answered
    @State private var answerDraft: [Int: String] = [:]
    @State private var submittingAnswer: Set<Int> = []
    @State private var deletingThread: Set<Int> = []
    @State private var threadErrors: [Int: String] = [:]
    @State private var dropdown = DropdownController()

    private var profileHeadline: String {
        let headline = (profile?.headline ?? "").trimmed
        if !headline.isEmpty { return headline }
        return [profile?.major?.nilIfEmpty, profile?.schoolName?.nilIfEmpty.map { "@ \($0)" }].compactMap { $0 }.joined(separator: " ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ProfileTabBar(tabs: [(.profile, "Profile"), (.posts, "Posts"), (.threads, "Threads")], selection: $activeTab) { tab in
                    if tab == .posts, !postsLoaded { loadOwnPosts() }
                    if tab == .threads, !threadsLoaded { loadOwnThreads() }
                }
                compactHeader
                switch activeTab {
                case .profile: profileTab
                case .posts: postsTab
                case .threads: threadsTab
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .environment(dropdown)
        .dropdownHost(dropdown)
        .task { await initialLoad() }
        .webModal(isPresented: $editOpen, backdropOpacity: 0.55, dismissOnBackdrop: { true }) {
            if let profile {
                EditProfileModal(profile: profile, isPresented: $editOpen) { updated in self.profile = updated }
            }
        }
        .webModal(item: $expModal) { state in
            ExperienceModal(state: state, isPresented: Binding(get: { expModal != nil }, set: { if !$0 { expModal = nil } })) { result in
                switch result {
                case .saved(let exp):
                    if let index = experiences.firstIndex(where: { $0.id == exp.id }) { experiences[index] = exp }
                    else { experiences.insert(exp, at: 0) }
                case .deleted(let id):
                    experiences.removeAll { $0.id == id }
                }
            }
        }
        .webModal(item: $eduModal) { state in
            EducationModal(state: state, isPresented: Binding(get: { eduModal != nil }, set: { if !$0 { eduModal = nil } })) { result in
                switch result {
                case .saved(let edu):
                    if let index = educations.firstIndex(where: { $0.id == edu.id }) { educations[index] = edu }
                    else { educations.insert(edu, at: 0) }
                case .deleted(let id):
                    educations.removeAll { $0.id == id }
                }
            }
        }
    }

    // MARK: Header — `lg:hidden px-6 py-5 border-b border-gray-200`

    private var compactHeader: some View {
        let user = session.user
        return HStack(alignment: .top, spacing: 16) {
            Avatar(imageURL: profile?.profilePic, initials: user?.initials ?? "", size: 64, fontSize: .xl)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(user?.firstName ?? "") \(user?.lastName ?? "")").tw(.lg, .bold).foregroundStyle(Palette.gray900)
                HStack(spacing: 12) {
                    count(followersCount, "followers")
                    Text("·")
                    count(followingCount, "following")
                }
                .tw(.sm)
                .foregroundStyle(Palette.gray500)
                .padding(.top, 4)
                if !profileHeadline.isEmpty {
                    Text(profileHeadline).tw(.sm).foregroundStyle(Palette.gray500).padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
            Button(action: openEdit) {
                Text("Edit").tw(.sm, .medium).foregroundStyle(Palette.gray700)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).strokeBorder(Palette.gray200, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .bottomBorder(Palette.gray200, width: 1)
    }

    private func count(_ n: Int, _ label: String) -> Text {
        Text("\(n)").font(.custom(TW.Weight.bold.fontName, fixedSize: 14)).foregroundColor(Palette.gray900) + Text(" \(label)")
    }

    // MARK: Profile tab

    private var profileTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileSection(title: "About") {
                if loadingProfile {
                    skeletonLines(2)
                } else if let bio = profile?.bio, !bio.isEmpty {
                    Text(bio).tw(.sm, leading: .relaxed).foregroundStyle(Palette.gray700)
                } else {
                    Button(action: openEdit) {
                        HStack(spacing: 8) {
                            Icon("plus", size: 16)
                            Text("Add a bio").tw(.sm, .medium)
                        }
                        .foregroundStyle(Palette.navy)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius)
                            .strokeBorder(Palette.gray300, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                    }
                    .buttonStyle(.plain)
                }
            }

            ProfileSection(title: "Education", trailing: { addButton { eduModal = EducationModalState(editing: nil) } }) {
                if loadingProfile {
                    skeletonLines(3)
                } else {
                    educationList
                }
            }

            ProfileSection(title: "Work Experience", trailing: { addButton { expModal = ExperienceModalState(editing: nil) } }) {
                if experiences.isEmpty {
                    Button { expModal = ExperienceModalState(editing: nil) } label: {
                        VStack(spacing: 6) {
                            Icon("briefcase", size: 28)
                            Text("Add work experience").tw(.sm, .medium)
                        }
                        .foregroundStyle(Palette.gray400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius)
                            .strokeBorder(Palette.gray200, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(experiences.enumerated()), id: \.element.id) { index, exp in
                            if index > 0 { TWDivider(color: Palette.gray100, width: 1) }
                            ExperienceRow(experience: exp, dash: "–", trailing: AnyView(pencil { expModal = ExperienceModalState(editing: exp) }))
                                .padding(.top, index == 0 ? 0 : 16)
                                .padding(.bottom, index == experiences.count - 1 ? 0 : 16)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var educationList: some View {
        let school = profile?.schoolName?.nilIfEmpty
        VStack(alignment: .leading, spacing: 0) {
            if let profile, let school {
                HStack(alignment: .top, spacing: 16) {
                    LogoImage(domain: profile.logoDomain, name: school, email: profile.schoolEmail, kind: .school, size: 12,
                              onTap: profile.collegeId.map { id in { router.navigate(to: .collegeDetail(id: id)) } })
                    educationText(
                        title: [profile.degreeLevel, profile.major].compactMap { $0?.nilIfEmpty }.joined(separator: ", ").nilIfEmpty ?? school,
                        school: school,
                        detail: [profile.schoolYear?.nilIfEmpty, profile.graduationYear?.value.nilIfEmpty.map { "Class of \($0)" }]
                            .compactMap { $0 }.joined(separator: " · "))
                    pencil(action: openEdit)
                }
                // `pb-4 border-b mb-4` unless it's the last child.
                .padding(.bottom, educations.isEmpty ? 0 : 16)
                .overlay(alignment: .bottom) { if !educations.isEmpty { Palette.gray100.frame(height: 1) } }
                .padding(.bottom, educations.isEmpty ? 0 : 16)
            }
            ForEach(Array(educations.enumerated()), id: \.element.id) { index, edu in
                let isLast = index == educations.count - 1
                HStack(alignment: .top, spacing: 16) {
                    LogoImage(name: edu.schoolName, kind: .school, size: 12)
                    educationText(
                        title: [edu.degreeLevel, edu.major].compactMap { $0?.nilIfEmpty }.joined(separator: ", ").nilIfEmpty ?? edu.schoolName,
                        school: edu.schoolName,
                        detail: edu.currentlyEnrolled ? "Currently enrolled"
                            : [edu.schoolYear?.nilIfEmpty, edu.graduationYear?.value.nilIfEmpty.map { "Class of \($0)" }]
                                .compactMap { $0 }.joined(separator: " · "))
                    pencil { eduModal = EducationModalState(editing: edu) }
                }
                .padding(.top, 16)
                .padding(.bottom, isLast ? 0 : 16)
                .overlay(alignment: .bottom) { if !isLast { Palette.gray100.frame(height: 1) } }
            }
            if school == nil, educations.isEmpty {
                Button { eduModal = EducationModalState(editing: nil) } label: {
                    Text("Add your education").tw(.sm).foregroundStyle(Palette.gray400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius)
                            .strokeBorder(Palette.gray200, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func educationText(title: String, school: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).tw(.sm, .bold).foregroundStyle(Palette.gray900)
            Text(school).tw(.sm).foregroundStyle(Palette.gray600)
            Text(detail).tw(.xs).foregroundStyle(Palette.gray400)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Hover-only on the web (`opacity-0 group-hover:opacity-100`); always visible on touch.
    private func pencil(action: @escaping () -> Void) -> some View {
        Button(action: action) { Icon("pencil", size: 16).foregroundStyle(Palette.gray300).padding(6) }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit")
    }

    private func addButton(action: @escaping () -> Void) -> some View {
        Button(action: action) { Icon("plus", size: 20).foregroundStyle(Palette.gray400).padding(6) }
            .buttonStyle(.plain)
            .accessibilityLabel("Add")
    }

    private func skeletonLines(_ count: Int) -> some View {
        VStack(spacing: 8) { ForEach(0..<count, id: \.self) { _ in SkeletonBar(height: 16) } }.twPulse()
    }

    // MARK: Posts tab

    private var postsTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            if loadingPosts {
                ForEach(0..<3, id: \.self) { _ in PostSkeleton(showImage: false) }
            } else if posts.isEmpty {
                EmptyState(image: "Leaves", title: "No posts yet", subtitle: "Posts you create will appear here.")
            } else {
                ForEach(posts) { post in
                    PostCard(post: post,
                             onAppreciate: { appreciatePost($0, posts: $posts, appreciating: $appreciating, api: session.api) },
                             appreciating: appreciating.contains(post.id), showAuthor: true, authorClickable: false,
                             onDelete: deletePost, deleting: deletingPost.contains(post.id))
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: Threads tab

    private var threadsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            segmented.frame(maxWidth: .infinity).padding(.vertical, 16)
            if threadsView == .answered { answeredList } else { unansweredList }
        }
        .padding(.horizontal, 16)
    }

    private var segmented: some View {
        HStack(spacing: 0) {
            segment("Answered", active: threadsView == .answered) { changeThreadsView(.answered) }
                .overlay(alignment: .trailing) { Palette.gray400.frame(width: 2) }
            segment("Unanswered", active: threadsView == .unanswered, badge: pendingThreads.isEmpty ? nil : pendingThreads.count) {
                changeThreadsView(.unanswered)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: TW.radiusLg))
        .overlay(RoundedRectangle(cornerRadius: TW.radiusLg).strokeBorder(Palette.gray400, lineWidth: 2))
        .fixedSize()
    }

    private func segment(_ title: String, active: Bool, badge: Int? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title).tw(.sm, .semibold)
                if let badge {
                    Text("\(badge)").tw(.xs, .bold).foregroundStyle(Palette.amber600)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Palette.amber100))
                }
            }
            .foregroundStyle(active ? Palette.gray900 : Palette.gray400)
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .background(active ? Palette.gray200 : .clear)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var answeredList: some View {
        if loadingThreads {
            threadSkeleton(bars: 3)
        } else if threads.isEmpty {
            EmptyState(image: "FallLeaves", title: "No answered threads yet", subtitle: "Questions you answer will appear here.")
        } else {
            ForEach(threads) { t in
                VStack(alignment: .leading, spacing: 4) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 12) {
                            Text(t.question).tw(.xl, .bold, leading: .snug).foregroundStyle(Palette.gray900)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ThreadDeleteButton(deleting: deletingThread.contains(t.id)) { deleteThread(t.id) }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                        Text(t.answer ?? "").tw(.md, leading: .relaxed).foregroundStyle(Palette.gray600)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                    }
                    .twBox(background: Palette.white, radius: TW.radiusXl, border: Palette.gray300, borderWidth: 2)
                    if let error = threadErrors[t.id], !error.isEmpty {
                        Text(error).tw(.xs).foregroundStyle(Palette.red500).padding(.horizontal, 4)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var unansweredList: some View {
        if pendingLoading {
            threadSkeleton(bars: 4)
        } else if pendingThreads.isEmpty {
            VStack(spacing: 12) {
                Image("Leaves").resizable().scaledToFit().frame(width: 96, height: 96).opacity(0.8)
                VStack(spacing: 4) {
                    Text("All caught up").tw(.sm, .semibold).foregroundStyle(Palette.gray500)
                    Text("No unanswered questions.").tw(.xs).foregroundStyle(Palette.gray400)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 64)
        } else {
            ForEach(pendingThreads) { t in
                VStack(alignment: .leading, spacing: 4) {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top, spacing: 12) {
                                Text(t.question).tw(.lg, .bold, leading: .snug).foregroundStyle(Palette.gray900)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                ThreadDeleteButton(deleting: deletingThread.contains(t.id)) { deleteThread(t.id) }
                            }
                            Text(RelativeTime.shortUnbounded.format(t.createdAt)).tw(.xs).foregroundStyle(Palette.gray400)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                        VStack(alignment: .trailing, spacing: 10) {
                            WebTextArea(placeholder: "Write your answer… (max 2000 chars)",
                                        text: Binding(get: { answerDraft[t.id] ?? "" }, set: { answerDraft[t.id] = $0 }),
                                        style: InputStyle(size: .sm, radius: TW.radiusXl, textColor: Palette.gray800, focusBorder: nil),
                                        rows: 3, maxLength: 2000)
                            let submitting = submittingAnswer.contains(t.id)
                            let disabled = submitting || (answerDraft[t.id] ?? "").trimmed.isEmpty
                            Button { answer(t.id) } label: {
                                Text(submitting ? "Saving…" : "Submit answer").tw(.sm, .semibold).foregroundStyle(Palette.white)
                                    .padding(.horizontal, 16).padding(.vertical, 6)
                                    .background(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).fill(Palette.navy))
                            }
                            .buttonStyle(.plain)
                            .disabled(disabled)
                            .opacity(disabled ? 0.5 : 1)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    }
                    .twBox(background: Palette.white, radius: TW.radiusXl, border: Palette.gray300, borderWidth: 2)
                    if let error = threadErrors[t.id], !error.isEmpty {
                        Text(error).tw(.xs).foregroundStyle(Palette.red500).padding(.horizontal, 4)
                    }
                }
            }
        }
    }

    private func threadSkeleton(bars: Int) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<2, id: \.self) { i in
                if i > 0 { TWDivider() }
                HStack(alignment: .top, spacing: 16) {
                    Circle().fill(Palette.gray200).frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBar(fraction: 1 / 3, height: 16, color: Palette.gray200)
                        SkeletonBar(height: 12, color: Palette.gray200)
                        SkeletonBar(fraction: 3 / 4, height: 12, color: Palette.gray200)
                        if bars > 3 { SkeletonBar(fraction: 1 / 2, height: 12, color: Palette.gray200) }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(Palette.gray50)
            }
        }
        .twPulse()
    }

    // MARK: Data

    private func initialLoad() async {
        if openUnansweredThreads {
            activeTab = .threads
            threadsView = .unanswered
            loadPendingThreads()
            loadOwnThreads()
        }
        let api = session.api
        // Five parallel requests, like the web's Promise.all; each failure is swallowed.
        let tasks: [Task<Void, Never>] = [
            Task { if let d = try? await api.send(AuthAPI.me()) { profile = d.user } },
            Task { if let d = try? await api.send(ProfileAPI.membershipStatus()) { membershipStatus = d.membership?.reviewStatus } },
            Task { if let d = try? await api.send(ProfileAPI.experiences()) { experiences = d.experiences ?? [] } },
            Task { if let d = try? await api.send(ProfileAPI.educations()) { educations = d.educations ?? [] } },
            Task {
                if let d = try? await api.send(FollowsAPI.mine()) {
                    followersCount = d.followersCount ?? 0
                    followingCount = d.followingCount ?? 0
                }
            },
        ]
        for task in tasks { await task.value }
        loadingProfile = false
    }

    private func openEdit() {
        guard profile != nil else { return }
        editOpen = true
    }

    private func loadOwnPosts() {
        guard !postsLoaded, !loadingPosts, let me = session.user?.id else { return }
        loadingPosts = true
        Task {
            do {
                posts = try await session.api.send(PostsAPI.list(limit: 40, creatorId: me, includeModeration: true)).posts ?? []
                postsLoaded = true
            } catch { posts = [] }
            loadingPosts = false
        }
    }

    private func loadOwnThreads() {
        guard !threadsLoaded, !loadingThreads, let me = session.user?.id else { return }
        loadingThreads = true
        Task {
            do {
                threads = try await session.api.send(QAThreadsAPI.profile(me)).threads ?? []
                threadsLoaded = true
            } catch { threads = [] }
            loadingThreads = false
        }
    }

    private func loadPendingThreads() {
        guard !pendingLoaded, !pendingLoading else { return }
        pendingLoading = true
        Task {
            do {
                pendingThreads = (try await session.api.send(QAThreadsAPI.inbox()).threads ?? []).filter { $0.status == "pending" }
                pendingLoaded = true
            } catch { pendingThreads = [] }
            pendingLoading = false
        }
    }

    private func changeThreadsView(_ view: ThreadsView) {
        threadsView = view
        if view == .unanswered, !pendingLoaded { loadPendingThreads() }
        if view == .answered, !threadsLoaded { loadOwnThreads() }
    }

    private func answer(_ id: Int) {
        let text = (answerDraft[id] ?? "").trimmed
        guard !text.isEmpty, !submittingAnswer.contains(id) else { return }
        submittingAnswer.insert(id)
        threadErrors[id] = ""
        Task {
            do {
                let data = try await session.api.send(QAThreadsAPI.answer(id, answer: text))
                pendingThreads.removeAll { $0.id == id }
                if let thread = data.thread { threads.insert(thread, at: 0) }
                answerDraft[id] = nil
            } catch let e {
                threadErrors[id] = e.apiMessage ?? "Failed to save answer."
            }
            submittingAnswer.remove(id)
        }
    }

    private func deleteThread(_ id: Int) {
        guard !deletingThread.contains(id) else { return }
        deletingThread.insert(id)
        Task {
            do {
                _ = try await session.api.send(QAThreadsAPI.delete(id))
                threads.removeAll { $0.id == id }
                pendingThreads.removeAll { $0.id == id }
            } catch let e {
                threadErrors[id] = e.apiMessage ?? "Failed to delete."
            }
            deletingThread.remove(id)
        }
    }

    private func deletePost(_ id: Int) {
        deletingPost.insert(id)
        Task {
            if (try? await session.api.send(PostsAPI.delete(id))) != nil { posts.removeAll { $0.id == id } }
            deletingPost.remove(id)
        }
    }
}

/// Trash icon → inline "Delete" / "Cancel" confirm.
private struct ThreadDeleteButton: View {
    let deleting: Bool
    let onDelete: () -> Void
    @State private var confirm = false

    var body: some View {
        if confirm {
            HStack(spacing: 8) {
                Button {
                    confirm = false
                    onDelete()
                } label: {
                    Text(deleting ? "Deleting…" : "Delete").tw(.xs, .semibold).foregroundStyle(Palette.red500)
                }
                .buttonStyle(.plain)
                .disabled(deleting)
                Button { confirm = false } label: { Text("Cancel").tw(.xs).foregroundStyle(Palette.gray400) }
                    .buttonStyle(.plain)
            }
            .fixedSize()
        } else {
            Button { confirm = true } label: {
                Icon("trash", size: 20).foregroundStyle(Palette.gray300).padding(4)
            }
            .buttonStyle(.plain)
            .disabled(deleting)
            .opacity(deleting ? 0.5 : 1)
            .padding(.trailing, -4)
            .accessibilityLabel("Delete thread")
        }
    }
}
