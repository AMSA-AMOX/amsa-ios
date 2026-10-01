import SwiftUI

// Port of src/components/posts/PostComposer.tsx (rendered inside `.dashboard`: buttons use 4px radii).
struct PostComposer: View {
    var canPost: Bool = true
    var cannotPostMessage: String = "You do not have permission to post."
    let onCreated: (PostItem) -> Void
    let onClose: () -> Void

    @Environment(SessionStore.self) private var session
    @Environment(\.supabaseStorage) private var storage

    private static let maxBody = 4000
    private static let maxImages = 1
    private static let maxFileSize = 6 * 1024 * 1024
    private static let topics = StaticData.constants.postTopics
    private static let topicSet = Set(topics.map { $0.lowercased() })
    private static let emojis: [(emoji: String, label: String)] = [
        ("🔥", ":fire:"), ("❤️", ":heart:"), ("😂", ":joy:"), ("😊", ":smile:"), ("🎉", ":tada:"), ("💪", ":muscle:"),
    ]

    @State private var step = 1
    @State private var text = ""
    @State private var selection = NSRange(location: 0, length: 0)
    @State private var files: [PickedImage] = []
    @State private var submitting = false
    @State private var error = ""
    @State private var userCollege: UserCollegeResponse.College?
    @State private var selectedCollegeId: Int?
    @State private var popups = DropdownController()
    @State private var showHashSuggestions = false
    @State private var hashQuery = ""
    @State private var focusTrigger = 0

    private var derived: [String] { PostTopics.derived(from: text, topics: Self.topics) }

    private var canGoNext: Bool {
        let trimmed = text.trimmed
        return canPost && !trimmed.isEmpty && !derived.isEmpty && trimmed.utf16.count <= Self.maxBody
            && files.count <= Self.maxImages
    }

    private var canSubmit: Bool { canGoNext && !submitting }

    var body: some View {
        VStack(spacing: 0) {
            header
            if step == 1 { stepOne } else { stepTwo }
        }
        .dropdownHost(popups)
        .background(Palette.white)
        .clipShape(RoundedRectangle(cornerRadius: TW.radiusXl))
        .twShadow(.xl)
        .frame(maxWidth: 672)
        .maxHeight(viewportFraction: 0.9)
        .task { await loadCollege() }
    }

    private func loadCollege() async {
        if let data = try? await session.api.send(UserCollegeAPI.mine()), let college = data.college {
            userCollege = college
        }
    }

    // MARK: Header

    private var header: some View {
        let user = session.user
        return HStack(alignment: .top, spacing: 12) {
            Avatar(imageURL: user?.profilePic, initials: user?.initials ?? "", size: 48, fontSize: .sm)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(user?.firstName ?? "") \(user?.lastName ?? "")").tw(.base, .semibold).foregroundStyle(Palette.gray900)
                HStack(spacing: 4) {
                    Icon("eye-2", size: 14).foregroundStyle(Palette.gray400)
                    Text("Everyone").tw(.xs).foregroundStyle(Palette.gray400)
                }
            }
            Spacer(minLength: 0)
            Button(action: onClose) {
                Icon("close", size: 20).foregroundStyle(Palette.gray400).padding(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .contentShape(Rectangle())
        .onTapGesture { closePopups() }
    }

    // MARK: Step 1

    private var stepOne: some View {
        VStack(spacing: 0) {
            FittingScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !canPost {
                        Text(cannotPostMessage)
                            .tw(.sm)
                            .foregroundStyle(Palette.amber700)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .twBox(background: Palette.amber50, radius: TW.radiusLg, border: Palette.amber100)
                    }

                    HighlightingTextView(
                        text: $text,
                        selection: $selection,
                        placeholder: "Share your thoughts...",
                        fontName: TW.Weight.light.fontName,
                        fontSize: 20,
                        lineHeight: 30,
                        textColor: UIColor(Palette.gray700),
                        placeholderColor: UIColor(Palette.gray300),
                        caretColor: UIColor(red: 0x37 / 255, green: 0x41 / 255, blue: 0x51 / 255, alpha: 1),
                        minHeight: 144,
                        isEditable: canPost,
                        maxLength: Self.maxBody,
                        highlights: Self.topicHighlights,
                        // `<strong style="font-weight:700">` → the 600 face (the heaviest loaded)
                        highlightFontName: TW.Weight.bold.fontName,
                        focusTrigger: focusTrigger,
                        onChange: { value, range in onBodyChange(value, range) }
                    )

                    if !files.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(Array(files.enumerated()), id: \.element.id) { index, file in
                                Image(uiImage: file.image)
                                    .resizable()
                                    .scaledToFit()
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
            .overlay(alignment: .bottomLeading) {
                // Hash suggestions — outside the scroll area so they're never clipped.
                if showHashSuggestions, !hashSuggestions.isEmpty { hashList.padding(.leading, 20).padding(.bottom, 8) }
            }

            toolbar
        }
    }

    private var hashSuggestions: [String] {
        let q = hashQuery.lowercased()
        return q.isEmpty ? Self.topics : Self.topics.filter { $0.lowercased().hasPrefix(q) }
    }

    private var hashList: some View {
        FittingScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("TOPICS")
                    .tw(.xs, .semibold, tracking: .wide)
                    .foregroundStyle(Palette.gray400)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                ForEach(hashSuggestions, id: \.self) { topic in
                    let alreadyIn = derived.contains(topic)
                    let atMax = derived.count >= 3 && !alreadyIn
                    Button { if !atMax { insertHashtag(topic) } } label: {
                        HStack(spacing: 8) {
                            Text("#\(topic)").tw(.sm).foregroundStyle(Palette.gray700)
                            Spacer(minLength: 0)
                            if alreadyIn { Icon("check-25", size: 14).foregroundStyle(Palette.navy) }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .opacity(atMax ? 0.4 : 1)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: 208)
        .frame(maxHeight: 208)
        .background(RoundedRectangle(cornerRadius: TW.radiusLg).fill(Palette.white))
        .overlay(RoundedRectangle(cornerRadius: TW.radiusLg).strokeBorder(Palette.gray200, lineWidth: 1))
        .twShadow(.lg)
    }

    private var toolbar: some View {
        HStack(spacing: 0) {
            Text("\(text.trimmed.utf16.count)/\(Self.maxBody)")
                .tw(.xs)
                .foregroundStyle(Palette.gray400)
                .frame(width: 64, alignment: .leading)

            HStack(spacing: 4) {
                let canAdd = canPost && files.count < Self.maxImages
                ImagePickerButton(disabled: !canAdd, onPick: pick) {
                    Icon("photo", size: 20)
                        .foregroundStyle(canAdd ? Palette.gray500 : Palette.gray400)
                        .padding(8)
                        .opacity(canAdd ? 1 : 0.4)
                }
                .accessibilityLabel(files.count >= Self.maxImages ? "Remove the current image to add a new one" : "Add image")

                Button {
                    // `absolute bottom-10 left-0` of the button wrapper.
                    popups.toggle("emoji", placement: .aboveLeading(offset: 40)) { emojiMenu }
                    showHashSuggestions = false
                } label: {
                    Icon("face-smile", size: 20).foregroundStyle(Palette.gray500).padding(8)
                }
                .buttonStyle(.plain)
                .dropdownAnchor("emoji")

                Button(action: insertHashSign) {
                    Text("#").tw(.base, .bold, leading: .leadingNone).foregroundStyle(Palette.gray500).padding(8)
                }
                .buttonStyle(.plain)
                .disabled(!canPost)
                .opacity(canPost ? 1 : 0.4)
                .overlay(alignment: .topTrailing) {
                    Circle().fill(Palette.red400).frame(width: 6, height: 6).padding(4)
                        .scaleEffect(derived.isEmpty ? 1 : 0)
                        .opacity(derived.isEmpty ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: derived.isEmpty)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity)

            Button { step = 2; closePopups() } label: {
                Text("Next")
                    .tw(.sm, .semibold)
                    .foregroundStyle(canGoNext ? Palette.white : Palette.gray500)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius)
                        .fill(canGoNext ? Palette.navy : Palette.gray200))
                    .opacity(canGoNext ? 1 : 0.4)
                    .fixedSize()
            }
            .buttonStyle(.plain)
            .disabled(!canGoNext)
            .frame(width: 64, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .topBorder(Palette.gray100, width: 1)
    }

    private var emojiMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Self.emojis, id: \.label) { item in
                Button { insertEmoji(item.emoji) } label: {
                    HStack(spacing: 12) {
                        Text(item.emoji).font(.system(size: 20))
                        Text(item.label).twMono(.xs).foregroundStyle(Palette.gray500)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .frame(width: 176)
        .background(RoundedRectangle(cornerRadius: TW.radiusLg).fill(Palette.white))
        .overlay(RoundedRectangle(cornerRadius: TW.radiusLg).strokeBorder(Palette.gray200, lineWidth: 1))
        .twShadow(.lg)
    }

    // MARK: Step 2

    private var stepTwo: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Who is this for?").tw(.base, .semibold).foregroundStyle(Palette.gray900)
                    Text("Choose who will find this most useful.").tw(.sm).foregroundStyle(Palette.gray400)
                }
                HStack(alignment: .top, spacing: 12) {
                    audienceTile(selected: selectedCollegeId == nil, title: "General", subtitle: "Useful for everyone",
                                 action: { selectedCollegeId = nil }) {
                        Icon("globe-alt", size: 24).foregroundStyle(selectedCollegeId == nil ? Palette.navy : Palette.gray400)
                    }

                    if let college = userCollege {
                        audienceTile(selected: selectedCollegeId == college.id, title: college.name, subtitle: "School-specific",
                                     action: { selectedCollegeId = college.id }) {
                            CollegeTileIcon(college: college, selected: selectedCollegeId == college.id)
                        }
                    } else {
                        VStack(spacing: 8) {
                            Icon("nav-colleges", size: 24).foregroundStyle(Palette.gray400)
                            Text("My School").tw(.sm, .semibold).foregroundStyle(Palette.gray700)
                            Text("No school on profile").tw(.xs).foregroundStyle(Palette.gray400)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .overlay(RoundedRectangle(cornerRadius: TW.radiusLg)
                            .strokeBorder(Palette.gray200, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
                        .opacity(0.4)
                    }
                }
                if !error.isEmpty { Text(error).tw(.sm).foregroundStyle(Palette.red500) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 32)

            HStack {
                Button {
                    step = 1
                    error = ""
                } label: {
                    Text("← Back").tw(.sm, .semibold).foregroundStyle(Palette.gray600)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                Spacer()
                Button(action: submit) {
                    Text(submitting ? "Posting…" : "Post")
                        .tw(.sm, .semibold)
                        .foregroundStyle(canSubmit ? Palette.white : Palette.gray500)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius)
                            .fill(canSubmit ? Palette.navy : Palette.gray200))
                        .opacity(canSubmit ? 1 : 0.4)
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .topBorder(Palette.gray100, width: 1)
        }
    }

    private func audienceTile<IconView: View>(
        selected: Bool, title: String, subtitle: String, action: @escaping () -> Void,
        @ViewBuilder icon: () -> IconView
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                icon()
                Text(title).tw(.sm, .semibold).foregroundStyle(selected ? Palette.navy : Palette.gray700).lineLimit(1)
                Text(subtitle).tw(.xs).foregroundStyle(Palette.gray400)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius)
                .strokeBorder(selected ? Palette.navy : Palette.gray200, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    private static func topicHighlights(_ text: String) -> [NSRange] {
        let ns = text as NSString
        guard let regex = try? NSRegularExpression(pattern: "#\(JSRegex.word)+") else { return [] }
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            let word = ns.substring(with: NSRange(location: match.range.location + 1, length: match.range.length - 1))
            return topicSet.contains(word.lowercased()) ? match.range : nil
        }
    }

    /// `#(\w*)$` on the text before the caret.
    private static func hashMatch(_ text: String, caret: Int) -> NSTextCheckingResult? {
        let ns = text as NSString
        let before = ns.substring(to: min(caret, ns.length))
        guard let regex = try? NSRegularExpression(pattern: "#(\(JSRegex.word)*)$") else { return nil }
        return regex.firstMatch(in: before, range: NSRange(location: 0, length: (before as NSString).length))
    }

    private func onBodyChange(_ value: String, _ range: NSRange) {
        if let match = Self.hashMatch(value, caret: range.location) {
            let before = (value as NSString).substring(to: min(range.location, (value as NSString).length)) as NSString
            hashQuery = before.substring(with: match.range(at: 1))
            showHashSuggestions = true
            popups.close()
        } else {
            showHashSuggestions = false
        }
    }

    private func insertEmoji(_ emoji: String) {
        let ns = text as NSString
        let start = min(selection.location, ns.length)
        let end = min(NSMaxRange(selection), ns.length)
        let next = ns.replacingCharacters(in: NSRange(location: start, length: end - start), with: emoji)
        guard (next as NSString).length <= Self.maxBody else { popups.close(); return }
        text = next
        selection = NSRange(location: start + (emoji as NSString).length, length: 0)
        popups.close()
        focusTrigger += 1
    }

    private func insertHashtag(_ topic: String) {
        let ns = text as NSString
        let pos = min(selection.location, ns.length)
        let insertion = "#\(topic) "
        let newBody: String
        let newPos: Int
        if let match = Self.hashMatch(text, caret: pos) {
            let start = pos - match.range.length
            newBody = ns.replacingCharacters(in: NSRange(location: start, length: pos - start), with: insertion)
            newPos = start + (topic as NSString).length + 2
        } else {
            newBody = ns.replacingCharacters(in: NSRange(location: pos, length: 0), with: insertion)
            newPos = pos + (topic as NSString).length + 2
        }
        text = newBody
        selection = NSRange(location: newPos, length: 0)
        showHashSuggestions = false
        hashQuery = ""
        focusTrigger += 1
    }

    private func insertHashSign() {
        let ns = text as NSString
        let pos = min(selection.location, ns.length)
        text = ns.replacingCharacters(in: NSRange(location: pos, length: 0), with: "#")
        selection = NSRange(location: pos + 1, length: 0)
        showHashSuggestions = true
        hashQuery = ""
        popups.close()
        focusTrigger += 1
    }

    private func closePopups() {
        popups.close()
        showHashSuggestions = false
    }

    private func pick(_ image: PickedImage) {
        if image.byteCount > Self.maxFileSize { error = "\"Image\" exceeds 6 MB."; return }
        error = ""
        files = Array((files + [image]).prefix(Self.maxImages))
    }

    private func submit() {
        guard canSubmit, let user = session.user else { return }
        submitting = true
        error = ""
        let body = text.trimmed
        let topics = derived
        let collegeId = selectedCollegeId
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
                let data = try await session.api.send(PostsAPI.create(body: body, topics: topics, images: urls,
                                                                      collegeId: collegeId))
                onCreated(data.post)
                text = ""
                self.files = []
                selectedCollegeId = nil
                step = 1
                onClose()
            } catch let e as SupabaseStorage.UploadError {
                error = e.message
            } catch let e {
                error = e.apiMessage ?? "Could not create post."
            }
            submitting = false
        }
    }
}

private struct CollegeTileIcon: View {
    let college: UserCollegeResponse.College
    let selected: Bool
    @State private var failed = false

    var body: some View {
        if let logo = college.logoUrl {
            if !failed {
                RemoteImage(logo) { phase in
                    switch phase {
                    case .success(let image): Image(uiImage: image).resizable().scaledToFit()
                    case .failure: Color.clear.onAppear { failed = true }
                    case .loading: Color.clear
                    }
                }
                .frame(width: 24, height: 24)
            }
            // onError → display:none
        } else {
            Icon("nav-colleges", size: 24).foregroundStyle(selected ? Palette.navy : Palette.gray400)
        }
    }
}
