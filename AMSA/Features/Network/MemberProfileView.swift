import SwiftUI

// Port of src/app/(dashboard)/dashboard/network/[id]/page.tsx (mobile layout; the lg sidebar is hidden).
struct MemberProfileView: View {
    let memberId: Int

    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router

    enum Tab: Hashable { case profile, posts, threads }

    @State private var profile: NetworkProfileResponse.User?
    @State private var experiences: [Experience] = []
    @State private var loadingProfile = true
    @State private var error = ""
    @State private var followInFlight = false
    @State private var activeTab: Tab = .profile
    @State private var posts: [PostItem] = []
    @State private var loadingPosts = false
    @State private var postsLoaded = false
    @State private var appreciating: Set<Int> = []
    @State private var profileThreads: [QAThread] = []
    @State private var loadingThreads = false
    @State private var threadsLoaded = false
    @State private var askOpen = false
    @State private var questionMessage: (text: String, ok: Bool)?
    @State private var dropdown = DropdownController()

    private var visibleRoles: [String] {
        let roles = (profile?.roles?.isEmpty == false) ? profile?.roles ?? [] : [profile?.role ?? ""]
        return roles.filter { !$0.isEmpty && RoleBadge.style($0) != nil && $0 != Role.alum }
    }

    private var canAskQuestion: Bool {
        guard session.role == Role.member, let profile, profile.id != session.user?.id else { return false }
        return profile.roles?.contains { [Role.ambassador, Role.usMember, Role.boardMember].contains($0) } ?? false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ProfileTabBar(tabs: [(.profile, "Profile"), (.posts, "Posts"), (.threads, "Threads")],
                              selection: $activeTab) { tab in
                    if tab == .posts, !postsLoaded { loadPosts() }
                    if tab == .threads, !threadsLoaded { loadThreads() }
                }
                compactHeader
                if !loadingProfile, !error.isEmpty {
                    Text(error).tw(.base, .semibold).foregroundStyle(Palette.navy)
                        .frame(maxWidth: .infinity).padding(.horizontal, 32).padding(.vertical, 48)
                }
                switch activeTab {
                case .profile: profileTab
                case .posts: postsTab
                case .threads: threadsTab
                }
            }
        }
        .environment(dropdown)
        .dropdownHost(dropdown)
        .task { await loadProfile() }
        .webModal(isPresented: $askOpen, backdropOpacity: 0.4) {
            if let profile {
                AskQuestionModal(recipient: profile, isPresented: $askOpen) { message in
                    questionMessage = message
                    if message.ok {
                        Task {
                            try? await Task.sleep(for: .seconds(4))
                            questionMessage = nil
                        }
                    }
                }
            }
        }
    }

    // MARK: Header (mobile: `lg:hidden px-6 py-5 border-b border-gray-200`)

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            BackLink(title: "Back to Network") { router.back(to: .network) }
                .padding(.bottom, 12)
            if !loadingProfile, let profile {
                HStack(alignment: .top, spacing: 16) {
                    Avatar(imageURL: profile.profilePic, initials: .initials(profile.firstName, profile.lastName),
                           size: 64, fontSize: .xl)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(profile.displayName).tw(.lg, .bold).foregroundStyle(Palette.gray900)
                        if !visibleRoles.isEmpty {
                            FlowLayout(spacing: 4) { ForEach(visibleRoles, id: \.self) { RolePill(role: $0) } }
                                .padding(.top, 4)
                        }
                        HStack(spacing: 12) {
                            countLabel(profile.followersCount ?? 0, "followers")
                            Text("·")
                            countLabel(profile.followingCount ?? 0, "following")
                        }
                        .tw(.sm)
                        .foregroundStyle(Palette.gray500)
                        .padding(.top, 4)
                        if let school = profile.schoolName, !school.isEmpty {
                            Text(school).tw(.sm).foregroundStyle(Palette.gray500).padding(.top, 4)
                        }
                        if profile.id != session.user?.id {
                            OutlineButton(title: profile.isFollowing == true ? "Following" : "Follow",
                                          horizontalPadding: 12, verticalPadding: 6, disabled: followInFlight,
                                          action: toggleFollow)
                                .padding(.top, 8)
                        }
                    }
                }
                let social = SocialLinksList(x: profile.x, linkedin: profile.linkedin, instagram: profile.instagram,
                                             facebook: profile.facebook)
                if social.hasAny {
                    social
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 16)
                        .topBorder(Palette.gray100, width: 1)
                        .padding(.top, 16)
                }
                if canAskQuestion {
                    VStack(alignment: .leading, spacing: 8) {
                        OutlineButton(title: "Ask a Direct Question", fullWidth: true) {
                            askOpen = true
                            questionMessage = nil
                        }
                        // The web closes the modal before this message can show; surfaced here instead.
                        if let questionMessage, questionMessage.ok {
                            Text(questionMessage.text).tw(.sm).foregroundStyle(Palette.green600)
                        }
                    }
                    .padding(.top, 16)
                    .topBorder(Palette.gray100, width: 1)
                    .padding(.top, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .bottomBorder(Palette.gray200, width: 1)
    }

    private func countLabel(_ count: Int, _ label: String) -> Text {
        Text("\(count)").font(.custom(TW.Weight.bold.fontName, fixedSize: 14)).foregroundColor(Palette.gray900)
            + Text(" \(label)")
    }

    // MARK: Tabs

    private var profileTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileSection(title: "About") {
                if loadingProfile {
                    skeletonLines(2)
                } else if let bio = profile?.bio, !bio.isEmpty {
                    Text(bio).tw(.sm, leading: .relaxed).foregroundStyle(Palette.gray700)
                } else if profile?.id == session.user?.id {
                    Button { router.navigate(to: .profile()) } label: {
                        HStack(spacing: 8) {
                            Icon("plus", size: 16)
                            Text("Add a bio").tw(.sm, .medium)
                        }
                        .foregroundStyle(Palette.navy)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .overlay(RoundedRectangle(cornerRadius: TW.radiusLg)
                            .strokeBorder(Palette.gray300, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("No bio added yet.").tw(.sm).foregroundStyle(Palette.gray500)
                }
            }
            ProfileSection(title: "Education") {
                if loadingProfile {
                    skeletonLines(3)
                } else if let profile, let school = profile.schoolName, !school.isEmpty {
                    HStack(alignment: .top, spacing: 16) {
                        LogoImage(domain: profile.logoDomain, name: school, email: profile.schoolEmail, kind: .school,
                                  size: 12, onTap: profile.collegeId.map { id in { router.navigate(to: .collegeDetail(id: id)) } })
                        VStack(alignment: .leading, spacing: 2) {
                            let degree = [profile.degreeLevel, profile.major].compactMap { $0?.nilIfEmpty }.joined(separator: ", ")
                            Text(degree.isEmpty ? school : degree).tw(.sm, .bold).foregroundStyle(Palette.gray900)
                            Text(school).tw(.sm).foregroundStyle(Palette.gray600)
                            Text([profile.schoolYear?.nilIfEmpty, profile.graduationYear?.value.nilIfEmpty.map { "Class of \($0)" }]
                                .compactMap { $0 }.joined(separator: " · "))
                                .tw(.xs).foregroundStyle(Palette.gray400)
                        }
                    }
                } else {
                    Text("No education details added yet.").tw(.sm).foregroundStyle(Palette.gray500)
                }
            }
            ProfileSection(title: "Work Experience") {
                if loadingProfile {
                    skeletonLines(2)
                } else if experiences.isEmpty {
                    Text("No experience added yet.").tw(.sm).foregroundStyle(Palette.gray500)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(experiences.enumerated()), id: \.element.id) { index, exp in
                            if index > 0 { TWDivider(color: Palette.gray100, width: 1) }
                            ExperienceRow(experience: exp, dash: "-")
                                .padding(.top, index == 0 ? 0 : 16)
                                .padding(.bottom, index == experiences.count - 1 ? 0 : 16)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var postsTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            if loadingPosts {
                ForEach(0..<3, id: \.self) { _ in PostSkeleton(showImage: false) }
            } else if posts.isEmpty {
                EmptyState(image: "Leaves", title: "No posts yet", subtitle: "This member hasn't posted anything.")
            } else {
                ForEach(posts) { post in
                    PostCard(post: post, onAppreciate: appreciate, appreciating: appreciating.contains(post.id),
                             showAuthor: true, authorClickable: false)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var threadsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            if loadingThreads {
                VStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { i in
                        if i > 0 { TWDivider() }
                        HStack(alignment: .top, spacing: 16) {
                            Circle().fill(Palette.gray200).frame(width: 40, height: 40)
                            VStack(alignment: .leading, spacing: 8) {
                                SkeletonBar(fraction: 1 / 3, height: 16, color: Palette.gray200)
                                SkeletonBar(height: 12, color: Palette.gray200)
                                SkeletonBar(fraction: 3 / 4, height: 12, color: Palette.gray200)
                            }
                            .padding(.top, 4)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background(Palette.gray50)
                    }
                }
                .twPulse()
            } else if profileThreads.isEmpty {
                EmptyState(image: "FallLeaves", title: "No answered threads yet.", subtitle: "Answered questions will appear here.")
            } else {
                ForEach(profileThreads) { QAThreadCard(thread: $0) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private func skeletonLines(_ count: Int) -> some View {
        VStack(spacing: 8) { ForEach(0..<count, id: \.self) { _ in SkeletonBar(height: 16) } }.twPulse()
    }

    // MARK: Data

    private func loadProfile() async {
        loadingProfile = true
        do {
            let data = try await session.api.send(NetworkAPI.profile(memberId))
            profile = data.user
            experiences = data.experiences ?? []
            error = ""
        } catch {
            self.error = "Member profile unavailable"
        }
        loadingProfile = false
    }

    private func loadPosts() {
        guard !postsLoaded, !loadingPosts else { return }
        loadingPosts = true
        Task {
            do {
                posts = try await session.api.send(PostsAPI.list(limit: 20, creatorId: memberId)).posts ?? []
                postsLoaded = true
            } catch {
                posts = []
            }
            loadingPosts = false
        }
    }

    private func loadThreads() {
        guard !threadsLoaded, !loadingThreads else { return }
        loadingThreads = true
        Task {
            do {
                profileThreads = try await session.api.send(QAThreadsAPI.profile(memberId)).threads ?? []
                threadsLoaded = true
            } catch {
                profileThreads = []
            }
            loadingThreads = false
        }
    }

    private func appreciate(_ postId: Int) {
        guard !appreciating.contains(postId), let index = posts.firstIndex(where: { $0.id == postId }),
              !posts[index].hasAppreciated else { return }
        let current = posts[index]
        appreciating.insert(postId)
        posts[index].hasAppreciated = true
        posts[index].appreciationCount += 1
        Task {
            do {
                let data = try await session.api.send(PostsAPI.helpful(postId))
                if let i = posts.firstIndex(where: { $0.id == postId }) {
                    posts[i].hasAppreciated = data.hasAppreciated ?? false
                    posts[i].appreciationCount = data.appreciationCount ?? posts[i].appreciationCount
                }
            } catch {
                if let i = posts.firstIndex(where: { $0.id == postId }) {
                    posts[i].hasAppreciated = current.hasAppreciated
                    posts[i].appreciationCount = current.appreciationCount
                }
            }
            appreciating.remove(postId)
        }
    }

    private func toggleFollow() {
        guard var current = profile, !followInFlight, current.id != session.user?.id else { return }
        let wasFollowing = current.isFollowing ?? false
        followInFlight = true
        current.isFollowing = !wasFollowing
        current.followersCount = max(0, (current.followersCount ?? 0) + (wasFollowing ? -1 : 1))
        profile = current
        let id = current.id
        Task {
            do {
                if wasFollowing { _ = try await session.api.send(FollowsAPI.unfollow(id)) }
                else { _ = try await session.api.send(FollowsAPI.follow(id)) }
            } catch {
                if var p = profile {
                    p.isFollowing = wasFollowing
                    p.followersCount = max(0, (p.followersCount ?? 0) + (wasFollowing ? 1 : -1))
                    profile = p
                }
            }
            followInFlight = false
        }
    }
}

/// `py-16 flex flex-col items-center gap-3 text-center` + leaves + `text-sm font-semibold text-gray-500` / `text-xs text-gray-400`.
struct EmptyState: View {
    let image: String
    let title: String
    let subtitle: String
    var imageSize: CGFloat = 224

    var body: some View {
        VStack(spacing: 12) {
            Image(image).resizable().scaledToFit().frame(width: imageSize, height: imageSize)
            VStack(spacing: 4) {
                Text(title).tw(.sm, .semibold).foregroundStyle(Palette.gray500)
                Text(subtitle).tw(.xs).foregroundStyle(Palette.gray400)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

/// The network profile's answered-thread card.
struct QAThreadCard: View {
    let thread: QAThread

    var body: some View {
        let recipientName = thread.isAnonymous ? "Anonymous" : (thread.recipient.map { $0.fullName } ?? "Member")
        let initials = thread.recipient.map { $0.initials } ?? "M"
        VStack(alignment: .leading, spacing: 0) {
            Text(thread.question)
                .tw(.xl, .bold, leading: .snug)
                .foregroundStyle(Palette.gray900)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if thread.isAnonymous {
                        AnonAvatar(size: 28, fontSize: .xs)
                    } else {
                        Avatar(imageURL: thread.recipient?.profilePic, initials: initials, size: 28, fontSize: .xs)
                    }
                    Text(recipientName).tw(.sm, .semibold).foregroundStyle(Palette.gray700)
                }
                if let answer = thread.answer, !answer.isEmpty {
                    Text(answer).tw(.base, leading: .relaxed).foregroundStyle(Palette.gray600)
                } else {
                    Text("Awaiting answer…").tw(.base).italic().foregroundStyle(Palette.gray400)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .topBorder(Palette.gray200, width: 1)
        }
        .twBox(background: Palette.white, radius: TW.radiusXl, border: Palette.gray300, borderWidth: 2)
    }
}

private struct AskQuestionModal: View {
    let recipient: NetworkProfileResponse.User
    @Binding var isPresented: Bool
    let onResult: ((text: String, ok: Bool)) -> Void

    @Environment(SessionStore.self) private var session
    @State private var draft = ""
    @State private var submitting = false
    @State private var message: (text: String, ok: Bool)?

    var body: some View {
        VStack(spacing: 0) {
            WebTextArea(
                placeholder: "What would you like to ask \(recipient.firstName ?? "")?",
                text: $draft,
                style: InputStyle(size: .lg, horizontalPadding: 24, verticalPadding: 0, radius: 0, border: .clear,
                                  background: .clear, textColor: Palette.gray700, placeholderColor: Palette.gray400,
                                  focusBorder: nil, focusRing: nil),
                rows: 6, maxLength: 600, autoFocus: true
            )
            .padding(.top, 32)
            .padding(.bottom, 20)

            HStack(spacing: 12) {
                Spacer(minLength: 0)
                if let message {
                    Text(message.text).tw(.sm).foregroundStyle(message.ok ? Palette.green600 : Palette.red500)
                }
                let disabled = submitting || draft.trimmed.isEmpty
                Button(action: submit) {
                    Text(submitting ? "Sending…" : "Ask")
                        .tw(.base, .semibold)
                        .foregroundStyle(Palette.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).fill(Palette.navy))
                }
                .buttonStyle(.plain)
                .disabled(disabled)
                .opacity(disabled ? 0.4 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .topBorder(Palette.gray100, width: 1)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: close) { Icon("close", size: 20).foregroundStyle(Palette.gray300).padding(4) }
                .buttonStyle(.plain)
                .padding(12)
                .accessibilityLabel("Close")
        }
        .frame(maxWidth: 512)
        .background(RoundedRectangle(cornerRadius: TW.radius2xl).fill(Palette.white))
        .clipShape(RoundedRectangle(cornerRadius: TW.radius2xl))
        .twShadow(.x2l)
    }

    private func close() {
        draft = ""
        message = nil
        isPresented = false
    }

    private func submit() {
        let q = draft.trimmed
        guard !q.isEmpty, !submitting else { return }
        submitting = true
        Task {
            do {
                _ = try await session.api.send(QAThreadsAPI.ask(recipientId: recipient.id, question: q))
                draft = ""
                isPresented = false
                onResult(("Your question has been sent!", true))
            } catch let e {
                message = (e.apiMessage ?? "Failed to send question.", false)
            }
            submitting = false
        }
    }
}
