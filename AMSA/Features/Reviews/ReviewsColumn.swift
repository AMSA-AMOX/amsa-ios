import SwiftUI

// Port of `ReviewsColumn` / `CollegeReviewsColumn` (places/[abbr], research/college/[id]) — identical apart from config.
struct ReviewsColumn: View {
    let config: ReviewsConfig

    @Environment(SessionStore.self) private var session

    @State private var reviews: [Review] = []
    @State private var loading = true
    @State private var error = ""
    @State private var markingHelpful: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Reviews top bar — `bg-gray-50 border-b-2 border-gray-300 px-6 py-4`
            Text("Reviews")
                .tw(.lg, .bold)
                .foregroundStyle(Palette.gray900)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Palette.gray50)
                .bottomBorder(Palette.gray300, width: 2)

            VStack(alignment: .leading, spacing: 20) {
                if session.role != Role.member {
                    ReviewComposer(config: config) { review in
                        var r = review
                        r.helpfulCount = 0
                        r.hasHelpful = false
                        reviews.insert(r, at: 0)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(reviews.count) \(reviews.count == 1 ? "Review" : "Reviews")".uppercased())
                        .tw(.xs, .semibold, tracking: .wide)
                        .foregroundStyle(Palette.gray400)
                    if !error.isEmpty, !loading {
                        HStack(spacing: 12) {
                            Text("Couldn't load reviews right now.")
                            Spacer(minLength: 0)
                            Button { Task { await load() } } label: {
                                Text("Try again").font(.custom(TW.Weight.semibold.fontName, fixedSize: 12)).underline()
                            }
                            .buttonStyle(.plain)
                        }
                        .tw(.xs)
                        .foregroundStyle(Palette.amber700)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: TW.radiusLg).fill(Palette.amber50))
                    }
                    if loading {
                        ForEach(0..<2, id: \.self) { _ in reviewSkeleton }
                    } else if reviews.isEmpty, error.isEmpty {
                        VStack(spacing: 0) {
                            Image("ReviewLeaves").resizable().scaledToFit().frame(width: 176).padding(.bottom, 32)
                            Text("No reviews yet").tw(.lg, .medium).foregroundStyle(Palette.gray400)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    } else {
                        ForEach(reviews) { review in
                            ReviewItem(review: review, config: config, markingHelpful: markingHelpful.contains(review.id),
                                       onDelete: { id in reviews.removeAll { $0.id == id } },
                                       onHelpful: helpful)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .topBorder(Palette.gray300, width: 2)
        .task { await load() }
    }

    private var reviewSkeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(Palette.gray100).frame(width: 24, height: 24)
                SkeletonBlock(width: 96, height: 12)
            }
            .padding(.bottom, 8)
            SkeletonBar(height: 12).padding(.bottom, 6)
            SkeletonBar(fraction: 3 / 4, height: 12)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .twBox(background: Palette.white, radius: TW.radius2xl, border: Palette.gray100)
        .twPulse()
    }

    private func load() async {
        loading = true
        error = ""
        do {
            reviews = try await session.api.send(config.list(session.isAuthenticated)).reviews ?? []
        } catch {
            self.error = "Failed to load reviews."
        }
        loading = false
    }

    private func helpful(_ id: String) {
        guard session.isAuthenticated, !markingHelpful.contains(id),
              let index = reviews.firstIndex(where: { $0.id == id }) else { return }
        let current = reviews[index]
        let liking = !current.hasHelpful
        markingHelpful.insert(id)
        reviews[index].hasHelpful = liking
        reviews[index].helpfulCount = max(0, current.helpfulCount + (liking ? 1 : -1))
        Task {
            do {
                let data = try await session.api.send(config.helpful(id))
                if let i = reviews.firstIndex(where: { $0.id == id }) {
                    reviews[i].hasHelpful = data.hasHelpful ?? false
                    reviews[i].helpfulCount = data.helpfulCount ?? reviews[i].helpfulCount
                }
            } catch {
                if let i = reviews.firstIndex(where: { $0.id == id }) {
                    reviews[i].hasHelpful = current.hasHelpful
                    reviews[i].helpfulCount = current.helpfulCount
                }
            }
            markingHelpful.remove(id)
        }
    }
}

private struct ReviewComposer: View {
    let config: ReviewsConfig
    let onCreated: (Review) -> Void

    @Environment(SessionStore.self) private var session
    @Environment(\.supabaseStorage) private var storage

    private static let maxImages = 4
    private static let maxFileSize = 5 * 1024 * 1024

    @State private var content = ""
    @State private var files: [PickedImage] = []
    @State private var usedPrompts: Set<String> = []
    @State private var submitting = false
    @State private var error = ""
    @State private var revealedPreview: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WebTextArea(placeholder: config.placeholder, text: $content,
                        style: InputStyle(size: .sm, radius: TW.radiusXl, border: Palette.gray300, borderWidth: 2,
                                          textColor: Palette.gray800, placeholderColor: Palette.gray400,
                                          focusBorder: Palette.navy, focusRing: nil),
                        rows: 3, maxLength: 2000)
            ReviewPromptChips(prompts: config.prompts, used: usedPrompts, onPick: insertPrompt)
            if !files.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(files) { file in
                        Image(uiImage: file.image).resizable().scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: TW.radiusLg))
                            .overlay(RoundedRectangle(cornerRadius: TW.radiusLg).strokeBorder(Palette.gray200, lineWidth: 1))
                            .overlay {
                                // Hover-only on the web: iOS Safari shows it on the first tap, removes on the second.
                                if revealedPreview == file.id {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: TW.radiusLg).fill(Color.black.opacity(0.4))
                                        Icon("close-25", size: 12).foregroundStyle(Palette.white)
                                    }
                                }
                            }
                            .onTapGesture {
                                if revealedPreview == file.id { files.removeAll { $0.id == file.id } } else { revealedPreview = file.id }
                            }
                    }
                }
                .padding(.top, 8)
            }
            HStack(spacing: 12) {
                ImagePickerButton(disabled: files.count >= Self.maxImages, onPick: pick) {
                    Icon("photo", size: 24).foregroundStyle(Palette.gray500).opacity(files.count >= Self.maxImages ? 0.4 : 1)
                }
                .accessibilityLabel("Add photo")
                Spacer(minLength: 0)
                Button(action: submit) {
                    Text(submitting ? "Posting…" : "Post").tw(.sm, .semibold).foregroundStyle(Palette.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).fill(Palette.navy))
                }
                .buttonStyle(.plain)
                .disabled(submitting)
                .opacity(submitting ? 0.5 : 1)
            }
            .padding(.top, 8)
            if !error.isEmpty { Text(error).tw(.xs).foregroundStyle(Palette.red500).padding(.top, 8) }
        }
    }

    private func insertPrompt(_ q: String) {
        let base = content.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression)
        content = ((base.isEmpty ? "" : "\(base)\n\n") + "\(q)\n").limitedUTF16(to: 2000)
        usedPrompts.insert(q)
    }

    private func pick(_ image: PickedImage) {
        if image.byteCount > Self.maxFileSize { error = "Max 5 MB per image."; return }
        error = ""
        files = Array((files + [image]).prefix(Self.maxImages))
    }

    private func submit() {
        guard content.trimmed.count >= 10 else { error = "Write at least 10 characters."; return }
        guard let user = session.user else { return }
        submitting = true
        error = ""
        let files = self.files
        let text = content.trimmed
        Task {
            do {
                var urls: [String] = []
                for (index, file) in files.enumerated() {
                    urls.append(try await storage.upload(file.data, bucket: .postImages,
                                                         path: config.uploadPath(user.id, index), contentType: "image/jpeg"))
                }
                let res = try await session.api.send(config.create(text, urls))
                if let review = res.review {
                    onCreated(review)
                    content = ""
                    self.files = []
                    usedPrompts = []
                } else {
                    error = res.message ?? "Failed to submit."
                }
            } catch {
                self.error = "Failed to submit. Please try again."
            }
            submitting = false
        }
    }
}

private struct ReviewItem: View {
    let review: Review
    let config: ReviewsConfig
    let markingHelpful: Bool
    let onDelete: (String) -> Void
    let onHelpful: (String) -> Void

    @Environment(SessionStore.self) private var session
    @State private var deleting = false
    @State private var confirmDelete = false
    @State private var lightbox: LightboxItem?

    var body: some View {
        let author = review.author
        let initials = author.map { String.initials($0.firstName, $0.lastName) } ?? "?"
        let name = author.map { "\($0.firstName ?? "") \($0.lastName ?? "")".trimmed } ?? "Member"
        let canDelete = session.user?.id == review.userId || session.role == Role.admin

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Avatar(imageURL: author?.profilePic, initials: initials, size: 24, fontSize: .px(10))
                Text(name).tw(.xs, .semibold).foregroundStyle(Palette.gray700)
                Text("·").foregroundStyle(Palette.gray300)
                Text(RelativeTime.agoMonth.format(review.createdAt)).tw(.xs).foregroundStyle(Palette.gray400)
                Spacer(minLength: 0)
                if canDelete {
                    Button { confirmDelete = true } label: {
                        Icon("trash", size: 14).foregroundStyle(Palette.gray300)
                    }
                    .buttonStyle(.plain)
                    .disabled(deleting)
                    .opacity(deleting ? 0.4 : 1)
                    .accessibilityLabel("Delete review")
                }
            }
            .padding(.bottom, 8)

            Text(review.content).tw(.base, leading: .relaxed).foregroundStyle(Palette.gray700)

            if !review.images.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(Array(review.images.enumerated()), id: \.offset) { _, url in
                        Button { lightbox = LightboxItem(url: url) } label: {
                            RemoteImage(url) { phase in
                                if let image = phase.image { Image(uiImage: image).resizable().scaledToFill() }
                                else { Palette.gray100 }
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: TW.radiusXl))
                            .overlay(RoundedRectangle(cornerRadius: TW.radiusXl).strokeBorder(Palette.gray200, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12)
            }

            Button { onHelpful(review.id) } label: {
                HStack(spacing: 6) {
                    Icon(review.hasHelpful ? "rose-solid" : "rose-outline", size: 24)
                    Text("Helpful").tw(.sm, .medium)
                    if review.helpfulCount > 0 { Text("\(review.helpfulCount)").tw(.sm, .medium).monospacedDigit() }
                }
                .foregroundStyle(review.hasHelpful ? Palette.emerald800 : Palette.gray400)
            }
            .buttonStyle(.plain)
            .disabled(!session.isAuthenticated || markingHelpful)
            .opacity(!session.isAuthenticated || markingHelpful ? 0.5 : 1)
            .accessibilityLabel(review.hasHelpful ? "Remove helpful" : "Mark as helpful")
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .twBox(background: Palette.white, radius: TW.radius2xl, border: Palette.gray100)
        .twShadow(.sm)
        .alert("Delete this review?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("OK", role: .destructive) { delete() }
        }
        .lightbox($lightbox, backdropOpacity: 0.8)
    }

    private func delete() {
        deleting = true
        Task {
            do {
                _ = try await session.api.send(config.delete(review.id))
                onDelete(review.id)
            } catch {
                deleting = false
            }
        }
    }
}

// Port of src/components/reviews/ReviewPromptChips.tsx
struct ReviewPromptChips: View {
    let prompts: [String]
    let used: Set<String>
    let onPick: (String) -> Void
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { open.toggle() } label: {
                HStack(spacing: 4) {
                    Icon("chevron-down", size: 14).rotationEffect(.degrees(open ? 180 : 0))
                    Text("Need ideas? Tap a question to add it").tw(.xs, .medium)
                }
                .foregroundStyle(Palette.navy)
            }
            .buttonStyle(.plain)
            if open {
                FlowLayout(spacing: 6) {
                    ForEach(prompts, id: \.self) { q in
                        let isUsed = used.contains(q)
                        Button { onPick(q) } label: {
                            HStack(spacing: 4) {
                                if isUsed { Icon("check-25", size: 12) }
                                Text(q).tw(.xs, .medium)
                            }
                            .foregroundStyle(isUsed ? Palette.gray300 : Palette.gray600)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .twBox(background: isUsed ? Palette.gray50 : .clear, radius: TW.dashboardButtonRadius,
                                   border: isUsed ? Palette.gray200 : Palette.gray300)
                        }
                        .buttonStyle(.plain)
                        .disabled(isUsed)
                    }
                }
            }
        }
        .padding(.top, 8)
    }
}
