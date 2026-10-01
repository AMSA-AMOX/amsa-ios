import SwiftUI

// Port of src/components/threads/ThreadComposer.tsx (inside `.dashboard`: buttons use 4px radii).
struct ThreadComposer: View {
    let onCreated: () -> Void
    let onClose: () -> Void

    @Environment(SessionStore.self) private var session
    @Environment(\.supabaseStorage) private var storage

    private static let maxTitle = 150
    private static let maxBody = 2000
    private static let maxImages = 1
    private static let maxFileSize = 5 * 1024 * 1024

    @State private var step = 1
    @State private var title = ""
    @State private var text = ""
    @State private var categoryName = "general"
    @State private var categoryDomain: String?
    @State private var files: [PickedImage] = []
    @State private var isAnon = false
    @State private var submitting = false
    @State private var error = ""
    @State private var popups = DropdownController()

    private var canGoNext: Bool {
        let trimmed = title.trimmed
        return !trimmed.isEmpty && trimmed.count <= Self.maxTitle && files.count <= Self.maxImages
    }
    private var canSubmit: Bool { canGoNext && !submitting }

    var body: some View {
        VStack(spacing: 0) {
            header
            if step == 1 { stepOne } else { stepTwo }
        }
        .background(Palette.white)
        .clipShape(RoundedRectangle(cornerRadius: TW.radiusXl))
        .twShadow(.xl)
        // The school dropdown is `position: fixed`, so it may extend past the panel.
        .dropdownHost(popups)
        .frame(maxWidth: 672)
        .maxHeight(viewportFraction: 0.9)
    }

    private var header: some View {
        let user = session.user
        return HStack(alignment: .top, spacing: 12) {
            Avatar(imageURL: user?.profilePic, initials: user?.initials ?? "", size: 48, fontSize: .sm)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(user?.firstName ?? "") \(user?.lastName ?? "")").tw(.base, .semibold).foregroundStyle(Palette.gray900)
                HStack(spacing: 4) {
                    Icon("check-circle", size: 14).foregroundStyle(Palette.gray400)
                    Text("Reviewed before publishing").tw(.xs).foregroundStyle(Palette.gray400)
                }
            }
            Spacer(minLength: 0)
            Button(action: onClose) { Icon("close", size: 20).foregroundStyle(Palette.gray400).padding(6) }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: Step 1

    private var stepOne: some View {
        VStack(spacing: 0) {
            FittingScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        ZStack(alignment: .leading) {
                            if title.isEmpty {
                                Text("Give your post a title…").tw(.xl, .light, leading: .snug).foregroundStyle(Palette.gray300)
                            }
                            TextField("", text: $title)
                                .tw(.xl, .semibold, leading: .snug)
                                .foregroundStyle(Palette.gray900)
                                .onChange(of: title) { _, v in if v.utf16.count > Self.maxTitle { title = v.limitedUTF16(to: Self.maxTitle) } }
                        }
                        if !title.isEmpty {
                            Text("\(title.utf16.count)/\(Self.maxTitle)").tw(.xs).foregroundStyle(Palette.gray300)
                        }
                    }

                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Add more details… (optional)").tw(.base, .light, leading: .relaxed).foregroundStyle(Palette.gray300)
                        }
                        TextField("", text: $text, axis: .vertical)
                            .tw(.base, .light, leading: .relaxed)
                            .foregroundStyle(Palette.gray700)
                            .onChange(of: text) { _, v in if v.utf16.count > Self.maxBody { text = v.limitedUTF16(to: Self.maxBody) } }
                    }
                    .frame(minHeight: 96, alignment: .topLeading)

                    if !files.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(Array(files.enumerated()), id: \.element.id) { index, file in
                                Image(uiImage: file.image).resizable().scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: TW.radiusLg))
                                    .overlay(alignment: .topTrailing) {
                                        Button { files.remove(at: index) } label: {
                                            Text("×").tw(.xs).foregroundStyle(Palette.white)
                                                .frame(width: 24, height: 24)
                                                .background(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius)
                                                    .fill(Color.black.opacity(0.6)))
                                        }
                                        .buttonStyle(.plain)
                                        .padding(8)
                                    }
                            }
                        }
                        .padding(.top, 12)
                        .topBorder(Palette.gray100, width: 1)
                    }

                    if !error.isEmpty { Text(error).tw(.sm).foregroundStyle(Palette.red500) }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            HStack(spacing: 0) {
                Text("\(text.utf16.count)/\(Self.maxBody)").tw(.xs).foregroundStyle(Palette.gray400)
                    .frame(width: 64, alignment: .leading)
                HStack(spacing: 4) {
                    let canAdd = files.count < Self.maxImages
                    ImagePickerButton(disabled: !canAdd, onPick: pick) {
                        Icon("photo", size: 20).foregroundStyle(canAdd ? Palette.gray500 : Palette.gray400)
                            .padding(8).opacity(canAdd ? 1 : 0.4)
                    }
                    .accessibilityLabel(canAdd ? "Add image" : "Max 1 image")
                    if !files.isEmpty {
                        Text("\(files.count)/\(Self.maxImages)").tw(.xs).foregroundStyle(Palette.gray400)
                    }
                }
                .frame(maxWidth: .infinity)
                primaryButton("Next", enabled: canGoNext) { step = 2 }
                    .frame(width: 64, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .topBorder(Palette.gray100, width: 1)
        }
    }

    // MARK: Step 2

    private var stepTwo: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Where should this go?").tw(.base, .semibold).foregroundStyle(Palette.gray900)
                    Text("Pick a school community or post it generally.").tw(.sm).foregroundStyle(Palette.gray400)
                }
                SchoolSearch(selectedName: categoryName, selectedDomain: categoryDomain, popups: popups) { name, domain in
                    categoryName = name
                    categoryDomain = domain
                }
                HStack(spacing: 12) {
                    // Only the switch toggles (the <label> wraps no input).
                    Button { isAnon.toggle() } label: {
                        ZStack(alignment: .leading) {
                            Capsule().fill(isAnon ? Palette.navy : Palette.gray200).frame(width: 40, height: 24)
                            Circle().fill(Palette.white).frame(width: 16, height: 16)
                                .shadow(color: .black.opacity(0.1), radius: 1.5, y: 1)
                                .offset(x: isAnon ? 20 : 4)
                        }
                        .animation(.easeInOut(duration: 0.15), value: isAnon)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Post anonymously")
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Post anonymously").tw(.sm, .semibold).foregroundStyle(Palette.gray700)
                        Text("Your name won't be shown publicly").tw(.xs).foregroundStyle(Palette.gray400)
                    }
                }
                .padding(.top, 16)
                .topBorder(Palette.gray100, width: 1)

                if !error.isEmpty { Text(error).tw(.sm).foregroundStyle(Palette.red500) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)

            HStack {
                Button {
                    step = 1
                    error = ""
                } label: {
                    Text("← Back").tw(.sm, .semibold).foregroundStyle(Palette.gray600).padding(.horizontal, 16).padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                Spacer()
                primaryButton(submitting ? "Submitting…" : "Submit for Review", enabled: canSubmit, action: submit)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .topBorder(Palette.gray100, width: 1)
        }
    }

    private func primaryButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .tw(.sm, .semibold)
                .foregroundStyle(enabled ? Palette.white : Palette.gray500)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).fill(enabled ? Palette.navy : Palette.gray200))
                .opacity(enabled ? 1 : 0.4)
                .fixedSize()
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func pick(_ image: PickedImage) {
        if image.byteCount > Self.maxFileSize { error = "\"Image\" exceeds 5 MB."; return }
        error = ""
        files = Array((files + [image]).prefix(Self.maxImages))
    }

    private func submit() {
        guard canSubmit, let user = session.user else { return }
        submitting = true
        error = ""
        let files = self.files
        Task {
            do {
                var urls: [String] = []
                for (index, file) in files.enumerated() {
                    do {
                        urls.append(try await storage.upload(file.data, bucket: .postImages,
                                                             path: UploadPath.post(userId: user.id, index: index),
                                                             contentType: "image/jpeg"))
                    } catch {
                        throw SupabaseStorage.UploadError(message: "Image upload failed: \(error.localizedDescription)")
                    }
                }
                _ = try await session.api.send(HubThreadsAPI.create(
                    title: title.trimmed, body: text.trimmed, category: categoryName, categoryDomain: categoryDomain,
                    images: urls, isAnon: isAnon))
                onCreated()
                title = ""; text = ""; categoryName = "general"; categoryDomain = nil
                self.files = []; isAnon = false; step = 1
                onClose()
            } catch let e as SupabaseStorage.UploadError {
                error = e.message
            } catch let e {
                error = e.apiMessage ?? "Failed to submit post."
            }
            submitting = false
        }
    }
}

// MARK: - School search (Clearbit autocomplete, exactly like the web)

private struct SchoolResult: Decodable, Hashable {
    let name: String?
    let domain: String?
}

private struct School: Hashable, Sendable {
    let name: String
    let domain: String
}

private enum Clearbit {
    static func suggestions(_ query: String) async -> [School] {
        let q = query.trimmed
        guard !q.isEmpty else { return [] }
        let encoded = q.addingPercentEncoding(withAllowedCharacters: .jsURIComponent) ?? q
        guard let url = URL(string: "https://autocomplete.clearbit.com/v1/companies/suggest?query=\(encoded)"),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let results = try? JSONDecoder().decode([SchoolResult].self, from: data)
        else { return [] }
        return results.compactMap { r in
            guard let name = r.name, !name.isEmpty, let domain = r.domain, domain.hasSuffix(".edu") else { return nil }
            return School(name: name, domain: domain)
        }.prefix(5).map { $0 }
    }
}

private struct SchoolSearch: View {
    let selectedName: String
    let selectedDomain: String?
    let popups: DropdownController
    let onSelect: (String, String?) -> Void

    @State private var query: String
    @State private var results: [School] = []
    @State private var searching = false
    @State private var open = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    init(selectedName: String, selectedDomain: String?, popups: DropdownController,
         onSelect: @escaping (String, String?) -> Void) {
        self.selectedName = selectedName
        self.selectedDomain = selectedDomain
        self.popups = popups
        self.onSelect = onSelect
        let isGeneral = selectedName.isEmpty || selectedName.lowercased() == "general"
        _query = State(initialValue: isGeneral ? "" : selectedName)
    }

    private var isGeneral: Bool { selectedName.isEmpty || selectedName.lowercased() == "general" }
    private var showGeneral: Bool { query.trimmed.isEmpty || "general".hasPrefix(query.trimmed.lowercased()) }

    var body: some View {
        HStack(spacing: 0) {
            leadingIcon.frame(width: 20, height: 20).padding(.leading, 12)
            TextField("", text: $query, prompt: Text("Search schools…").foregroundStyle(Palette.black.opacity(0.5)))
                .tw(.sm)
                .foregroundStyle(Palette.black)
                .focused($focused)
                .autocorrectionDisabled()
                .padding(.leading, 4)
            trailing.frame(width: 16, height: 16).padding(.trailing, 12)
        }
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: TW.radiusXl).fill(Palette.white))
        .overlay(RoundedRectangle(cornerRadius: TW.radiusXl).strokeBorder(Palette.gray200, lineWidth: 1))
        .overlay {
            if focused { RoundedRectangle(cornerRadius: TW.radiusXl).inset(by: -1).stroke(Palette.navy.opacity(0.2), lineWidth: 2) }
        }
        .dropdownAnchor("school-search")
        .onChange(of: focused) { _, isFocused in if isFocused { showDropdown() } }
        .onChange(of: query) { _, _ in scheduleSearch(); showDropdown() }
        .onChange(of: results.map(\.domain)) { _, _ in refreshDropdown() }
        .onChange(of: searching) { _, _ in refreshDropdown() }
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if isGeneral, query.isEmpty {
            Icon("globe", size: 16).foregroundStyle(Palette.gray400)
        } else if let selectedDomain, query.isEmpty,
                  let url = LogoLookup.badgeURL(domain: selectedDomain, token: AppConfig.current.logoDevToken) {
            RemoteImage(url: url) { phase in
                if let image = phase.image { Image(uiImage: image).resizable().scaledToFit().frame(width: 16, height: 16) }
            }
        } else {
            Icon("search", size: 16).foregroundStyle(Palette.gray300)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if searching {
            Spinner(size: 16).foregroundStyle(Palette.gray400)
        } else if !query.isEmpty {
            Button {
                query = ""
                results = []
                onSelect("general", nil)
            } label: {
                Icon("close", size: 16).foregroundStyle(Palette.gray400)
            }
            .buttonStyle(.plain)
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let q = query.trimmed
        guard !q.isEmpty else { results = []; searching = false; return }
        searching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let found = await Clearbit.suggestions(q)
            guard !Task.isCancelled else { return }
            results = found
            searching = false
        }
    }

    private func showDropdown() {
        open = true
        refreshDropdown()
    }

    private func refreshDropdown() {
        guard open else { return }
        if showGeneral || !results.isEmpty || searching {
            // `fixed … top: r.bottom + 6` under the input, same width.
            popups.open("school-search", placement: .belowLeading(offset: 44 + 6)) { dropdown }
        } else {
            popups.close()
        }
    }

    private var dropdown: some View {
        VStack(spacing: 0) {
            if showGeneral {
                Button {
                    onSelect("general", nil)
                    query = ""
                    close()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: TW.radiusLg).fill(Palette.navy.opacity(0.1))
                            Icon("globe", size: 16).foregroundStyle(Palette.navy)
                        }
                        .frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("General").tw(.sm, .semibold).foregroundStyle(Palette.gray800)
                            Text("Not college-specific").tw(.xs).foregroundStyle(Palette.gray400)
                        }
                        Spacer(minLength: 0)
                        if isGeneral, query.isEmpty { Icon("check-25", size: 16).foregroundStyle(Palette.navy) }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(isGeneral && query.isEmpty ? Palette.gray50 : Palette.white)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if showGeneral, !results.isEmpty {
                Palette.gray100.frame(height: 1).padding(.horizontal, 16)
            }
            ForEach(results, id: \.domain) { school in
                let isSelected = selectedName == school.name
                Button {
                    onSelect(school.name, school.domain)
                    query = school.name
                    close()
                    results = []
                } label: {
                    HStack(spacing: 12) {
                        SchoolLogo(domain: school.domain, name: school.name).frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(school.name).tw(.sm, .semibold).foregroundStyle(Palette.gray800).lineLimit(1)
                            Text(school.domain).tw(.xs).foregroundStyle(Palette.gray400).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if isSelected { Icon("check-25", size: 16).foregroundStyle(Palette.navy) }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(isSelected ? Palette.gray50 : Palette.white)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if !query.trimmed.isEmpty, !searching, results.isEmpty, !showGeneral {
                Text("No schools found").tw(.sm).foregroundStyle(Palette.gray400)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 12)
            }
        }
        .frame(width: UIScreen.main.bounds.width - 32 - 48)
        .background(RoundedRectangle(cornerRadius: TW.radiusXl).fill(Palette.white))
        .clipShape(RoundedRectangle(cornerRadius: TW.radiusXl))
        .overlay(RoundedRectangle(cornerRadius: TW.radiusXl).strokeBorder(Palette.gray100, lineWidth: 1))
        .twShadow(.xl)
    }

    private func close() {
        open = false
        focused = false
        popups.close()
    }
}

private struct SchoolLogo: View {
    let domain: String
    let name: String
    @State private var failed = false

    var body: some View {
        if failed {
            Text(String(name.prefix(1))).tw(.xs, .bold).foregroundStyle(Palette.gray400)
        } else if let url = LogoLookup.badgeURL(domain: domain, token: AppConfig.current.logoDevToken) {
            RemoteImage(url: url) { phase in
                switch phase {
                case .success(let image): Image(uiImage: image).resizable().scaledToFit().frame(width: 24, height: 24)
                case .failure: Color.clear.onAppear { failed = true }
                case .loading: Color.clear.frame(width: 24, height: 24)
                }
            }
        }
    }
}
