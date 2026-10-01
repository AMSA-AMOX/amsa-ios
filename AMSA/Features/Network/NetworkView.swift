import SwiftUI

// Port of src/app/(dashboard)/dashboard/network/page.tsx
struct NetworkView: View {
    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router

    private static let pageSize = 8

    @State private var query = ""
    @State private var members: [NetworkMember] = []
    @State private var loadingMembers = true
    @State private var inFlightFollow: Set<Int> = []
    @State private var page = 1
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    private var totalPages: Int { max(1, Int(ceil(Double(members.count) / Double(Self.pageSize)))) }
    private var displayed: ArraySlice<NetworkMember> {
        let start = min((page - 1) * Self.pageSize, members.count)
        return members[start..<min(page * Self.pageSize, members.count)]
    }
    private var resultCountLabel: String {
        if loadingMembers { return "Searching..." }
        if members.isEmpty { return "0 results" }
        return "\((page - 1) * Self.pageSize + 1)–\(min(page * Self.pageSize, members.count)) of \(members.count)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 16) {
                    SearchField(placeholder: "Search by name or school...", text: $query, focused: $searchFocused)
                    Text(resultCountLabel).tw(.xs).foregroundStyle(Palette.gray400).fixedSize()
                }
                .padding(.bottom, 20)

                VStack(spacing: 16) {
                    if loadingMembers {
                        // The web wraps these in a `display: contents` element, so `animate-pulse` never applies.
                        ForEach(0..<Self.pageSize, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: TW.radiusLg).fill(Palette.white)
                                .overlay(RoundedRectangle(cornerRadius: TW.radiusLg).strokeBorder(Palette.gray200, lineWidth: 2))
                                .frame(height: 224)
                        }
                    } else if members.isEmpty {
                        VStack(spacing: 4) {
                            Text("No members found").tw(.base, .semibold).foregroundStyle(Palette.navy)
                            Text("Try a different name or school keyword.").tw(.sm).foregroundStyle(Palette.gray500)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .twBox(background: Palette.white, radius: TW.radiusLg, border: Palette.gray100)
                        .twShadow(.sm)
                    } else {
                        ForEach(displayed) { member in memberCard(member) }
                    }
                }

                if !loadingMembers, totalPages > 1 {
                    HStack(spacing: 12) {
                        pageButton("Previous", disabled: page == 1) { page = max(1, page - 1) }
                        (Text("Page ") + Text("\(page)").font(.custom(TW.Weight.semibold.fontName, fixedSize: 14))
                            .foregroundColor(Palette.gray900) + Text(" of ")
                            + Text("\(totalPages)").font(.custom(TW.Weight.semibold.fontName, fixedSize: 14))
                            .foregroundColor(Palette.gray900))
                            .tw(.sm)
                            .foregroundStyle(Palette.gray500)
                        pageButton("Next", disabled: page == totalPages) { page = min(totalPages, page + 1) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .task { await loadDiscovery() }
        .onChange(of: query) { _, newValue in queryChanged(newValue) }
    }

    private func memberCard(_ member: NetworkMember) -> some View {
        let badgeRole = RoleBadge.style(member.role ?? "") != nil ? member.role : (member.role == Role.admin ? Role.usMember : nil)
        return Button { router.navigate(to: .memberProfile(id: member.id)) } label: {
            VStack(spacing: 0) {
                Avatar(imageURL: member.profilePic, initials: .initials(member.firstName, member.lastName), size: 120,
                       fontSize: .x2l)
                Text("\(member.firstName ?? "") \(member.lastName ?? "")")
                    .tw(.xl, .bold, leading: .tight)
                    .foregroundStyle(Palette.gray900)
                    .lineLimit(1)
                    .padding(.top, 12)
                if let badgeRole { RolePill(role: badgeRole).padding(.top, 6) }
                HStack(spacing: 8) {
                    LogoImage(domain: member.logoDomain, name: member.schoolName, kind: .school, size: 7, radius: TW.radiusMd)
                    Text(member.schoolName?.nilIfEmpty ?? "School not added yet")
                        .tw(.sm).foregroundStyle(Palette.gray500).lineLimit(2).multilineTextAlignment(.center)
                }
                .frame(minHeight: 40)
                .padding(.top, 8)
                Group {
                    if member.mutualCount > 0 {
                        Text("\(member.mutualCount) mutual connection\(member.mutualCount == 1 ? "" : "s")")
                            .tw(.xs, .medium).foregroundStyle(Palette.navy.opacity(0.7))
                    }
                }
                .frame(minHeight: 20)
                .padding(.top, 2)
                Button { toggleFollow(member.id) } label: {
                    Text(member.isFollowing ? "Following" : "Follow")
                        .tw(.md, .semibold)
                        .foregroundStyle(Palette.gray700)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).strokeBorder(Palette.gray200, lineWidth: 2))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(inFlightFollow.contains(member.id))
                .opacity(inFlightFollow.contains(member.id) ? 0.6 : 1)
                .padding(.top, 16)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .twBox(background: Palette.white, radius: TW.radiusLg, border: Palette.gray200, borderWidth: 2)
            .twShadow(.sm)
        }
        .buttonStyle(.plain)
    }

    private func pageButton(_ title: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).tw(.sm, .medium).foregroundStyle(Palette.gray700)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).strokeBorder(Palette.gray200, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }

    // MARK: Data

    private func queryChanged(_ value: String) {
        searchTask?.cancel()
        // Only debounce while typing; clearing reloads discovery immediately.
        guard !value.trimmed.isEmpty else {
            searchTask = Task { await loadDiscovery() }
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await runSearch(value)
        }
    }

    private func loadDiscovery() async {
        loadingMembers = true
        do {
            members = try await session.api.send(NetworkAPI.discovery()).users ?? []
            page = 1
        } catch {
            members = []
        }
        loadingMembers = false
    }

    private func runSearch(_ text: String) async {
        loadingMembers = true
        do {
            let result = try await session.api.send(NetworkAPI.search(text.trimmed)).users ?? []
            guard !Task.isCancelled else { return }
            members = result
            page = 1
        } catch {
            if !Task.isCancelled { members = [] }
        }
        if !Task.isCancelled { loadingMembers = false }
    }

    private func toggleFollow(_ memberId: Int) {
        guard !inFlightFollow.contains(memberId), let index = members.firstIndex(where: { $0.id == memberId }) else { return }
        let wasFollowing = members[index].isFollowing
        inFlightFollow.insert(memberId)
        members[index].isFollowing = !wasFollowing
        members[index].followersCount = max(0, members[index].followersCount + (wasFollowing ? -1 : 1))
        Task {
            do {
                if wasFollowing { _ = try await session.api.send(FollowsAPI.unfollow(memberId)) }
                else { _ = try await session.api.send(FollowsAPI.follow(memberId)) }
            } catch {
                if let i = members.firstIndex(where: { $0.id == memberId }) {
                    members[i].isFollowing = wasFollowing
                    members[i].followersCount = max(0, members[i].followersCount + (wasFollowing ? 1 : -1))
                }
            }
            inFlightFollow.remove(memberId)
        }
    }
}

/// Search input: `pl-10 pr-4 py-2.5 border-2 border-gray-300 rounded-lg text-lg bg-gray-50
/// focus:border-gray-500 focus:bg-white` with a magnifier at `left-3`.
struct SearchField: View {
    let placeholder: String
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var icon: String = "search-lg"

    var body: some View {
        let isFocused = focused.wrappedValue
        HStack(spacing: 8) {
            Icon(icon, size: 20).foregroundStyle(Palette.gray400)
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder).tw(.lg).foregroundStyle(Palette.black.opacity(0.5)).lineLimit(1)
                }
                TextField("", text: $text)
                    .tw(.lg)
                    .foregroundStyle(Palette.black)
                    .focused(focused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: 448)
        .twBox(background: isFocused ? Palette.white : Palette.gray50, radius: TW.radiusLg,
               border: isFocused ? Palette.gray500 : Palette.gray300, borderWidth: 2)
    }
}
