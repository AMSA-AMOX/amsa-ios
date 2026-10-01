import SwiftUI

// Port of src/app/(dashboard)/dashboard/threads/page.tsx
struct ThreadsView: View {
    @Environment(SessionStore.self) private var session

    @State private var threads: [HubThread] = []
    @State private var pageLoading = true
    @State private var nextCursor: String?
    @State private var loadingMore = false
    @State private var postOpen = false
    @State private var submitMsg: (text: String, ok: Bool)?
    @State private var activeCategory = "all"
    @State private var dropdown = DropdownController()
    @State private var messageTask: Task<Void, Never>?

    private var categoryTabs: [(cat: String, domain: String?)] {
        var seen: [String] = []
        var domains: [String: String?] = [:]
        for thread in threads where domains[thread.category] == nil {
            seen.append(thread.category)
            domains[thread.category] = .some(thread.categoryDomain)
        }
        return seen.map { ($0, domains[$0] ?? nil) }
    }

    private var visibleThreads: [HubThread] {
        activeCategory == "all" ? threads : threads.filter { $0.category == activeCategory }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ComposerTrigger(text: "Ask something from the community...") {
                    postOpen = true
                    submitMsg = nil
                }
                .padding(.bottom, 24)

                if let submitMsg {
                    Text(submitMsg.text)
                        .tw(.sm)
                        .foregroundStyle(submitMsg.ok ? Palette.green700 : Palette.red700)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .twBox(background: submitMsg.ok ? Palette.green50 : Palette.red50, radius: TW.radiusXl,
                               border: submitMsg.ok ? Palette.green100 : Palette.red100)
                        .padding(.bottom, 16)
                }

                if !pageLoading, categoryTabs.count > 1 { tabs.padding(.bottom, 16) }

                if pageLoading {
                    ForEach(0..<3, id: \.self) { _ in ThreadSkeleton() }
                } else if visibleThreads.isEmpty {
                    EmptyLeaves(image: "FallLeaves", text: "No threads yet...")
                } else {
                    VStack(spacing: 12) {
                        ForEach(visibleThreads) { thread in
                            ThreadCard(thread: thread, isAdmin: session.role == Role.admin) { id in
                                threads.removeAll { $0.id == id }
                            }
                        }
                        if nextCursor != nil, activeCategory == "all" {
                            Button(action: loadMore) {
                                Text(loadingMore ? "Loading…" : "Load more")
                                    .tw(.sm, .medium)
                                    .foregroundStyle(Palette.gray600)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius)
                                        .strokeBorder(Palette.gray200, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(loadingMore)
                            .opacity(loadingMore ? 0.5 : 1)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .environment(dropdown)
        .dropdownHost(dropdown)
        .task { await load() }
        .webModal(isPresented: $postOpen) {
            ThreadComposer(onCreated: {
                postOpen = false
                submitMsg = ("Your post has been submitted for review. It will appear once a board member approves it.", true)
                messageTask?.cancel()
                messageTask = Task {
                    try? await Task.sleep(for: .seconds(6))
                    if !Task.isCancelled { submitMsg = nil }
                }
            }, onClose: { postOpen = false })
        }
    }

    private var tabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                tab(label: "All", cat: "all", domain: nil)
                ForEach(categoryTabs, id: \.cat) { item in
                    tab(label: item.cat == "general" ? "General" : item.cat, cat: item.cat, domain: item.domain)
                }
            }
            .padding(.bottom, 4)
        }
    }

    /// `px-4 py-2 rounded-full text-sm font-semibold` (a dashboard button → 4px).
    private func tab(label: String, cat: String, domain: String?) -> some View {
        let active = activeCategory == cat
        return Button { activeCategory = cat } label: {
            HStack(spacing: 6) {
                if cat != "general", cat != "all", let domain, !active,
                   let url = LogoLookup.badgeURL(domain: domain, token: AppConfig.current.logoDevToken)
                {
                    RemoteImage(url: url) { phase in
                        if let image = phase.image {
                            Image(uiImage: image).resizable().scaledToFit().frame(width: 16, height: 16)
                        } else if !phase.isFailure {
                            Color.clear.frame(width: 16, height: 16)
                        }
                    }
                }
                Text(label).tw(.sm, .semibold).lineLimit(1)
            }
            .foregroundStyle(active ? Palette.white : Palette.gray600)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .twBox(background: active ? Palette.navy : Palette.white, radius: TW.dashboardButtonRadius,
                   border: active ? nil : Palette.gray200)
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        pageLoading = true
        do {
            let data = try await session.api.send(HubThreadsAPI.list())
            threads = data.threads ?? []
            nextCursor = data.nextCursor
        } catch {
            threads = []
        }
        pageLoading = false
    }

    private func loadMore() {
        guard let cursor = nextCursor, !loadingMore else { return }
        loadingMore = true
        Task {
            if let data = try? await session.api.send(HubThreadsAPI.list(cursor: cursor)) {
                threads += data.threads ?? []
                nextCursor = data.nextCursor
            }
            loadingMore = false
        }
    }
}

private struct ThreadSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle().fill(Palette.gray100).frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonBar(fraction: 1 / 3, height: 14)
                    SkeletonBar(fraction: 1 / 4, height: 12)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBar(fraction: 3 / 4, height: 16)
                SkeletonBar(height: 16)
                SkeletonBar(fraction: 4 / 5, height: 16)
            }
            .padding(.leading, 56)
        }
        .padding(.vertical, 20)
        .bottomBorder(Palette.gray200, width: 1)
        .twPulse()
    }
}
