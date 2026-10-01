import SwiftUI

// Port of src/components/posts/PostCard.tsx
struct PostCard: View {
    let post: PostItem
    let onAppreciate: (Int) -> Void
    let appreciating: Bool
    var showAuthor: Bool = true
    /// When false, the avatar and name render as static (non-clickable)
    var authorClickable: Bool = true
    var onFollow: ((Int) -> Void)? = nil
    var isFollowing: Bool = false
    var followingInProgress: Bool = false
    var onDelete: ((Int) -> Void)? = nil
    var deleting: Bool = false
    var onReport: ((Int) -> Void)? = nil

    @Environment(Router.self) private var router
    @Environment(DropdownController.self) private var dropdown

    private var initials: String {
        let value = String.initials(post.author?.firstName, post.author?.lastName)
        return value.isEmpty ? "U" : value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showAuthor { header.padding(.bottom, 12) }
            VStack(alignment: .leading, spacing: 0) {
                if !post.isApproved { moderationBadge.padding(.bottom, 8) }
                PostBodyText(text: post.body)
                if !post.images.isEmpty {
                    ImageGrid(count: post.images.count, columns: post.images.count == 1 ? 1 : 2) { index in
                        NaturalRemoteImage(url: post.images[index], maxHeight: 600, radius: TW.radius2xl)
                    }
                    .padding(.top, 16)
                }
                footer.padding(.top, 20)
            }
            .padding(.leading, showAuthor ? 56 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 20)
        .bottomBorder(Palette.gray200, width: 1)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            avatarBadge
                .onTapGesture { if let author = post.author, authorClickable { router.navigate(to: .memberProfile(id: author.id)) } }
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Group {
                        if let author = post.author {
                            Text("\(author.firstName ?? "") \(author.lastName ?? "")")
                        } else {
                            Text("Unknown user")
                        }
                    }
                    .tw(.sm, .semibold)
                    .foregroundStyle(Palette.gray900)
                    .lineLimit(1)
                    .onTapGesture { if let author = post.author, authorClickable { router.navigate(to: .memberProfile(id: author.id)) } }
                    Text(post.author?.headline?.nilIfEmpty ?? "AMSA Member")
                        .tw(.xs)
                        .foregroundStyle(Palette.gray500)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Text(RelativeTime.post.format(post.createdAt))
                        .tw(.xs)
                        .foregroundStyle(Palette.gray400)
                    if let onFollow, let author = post.author {
                        Button { onFollow(author.id) } label: {
                            Text(isFollowing ? "Following" : "Follow")
                                .tw(.xs, .semibold)
                                .foregroundStyle(isFollowing ? Palette.gray500 : Palette.navy)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius)
                                    .strokeBorder(isFollowing ? Palette.gray300 : Palette.navy, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(followingInProgress)
                        .opacity(followingInProgress ? 0.5 : 1)
                    }
                    if onDelete != nil || onReport != nil { menuButton }
                }
                .fixedSize()
            }
        }
    }

    private var avatarBadge: some View {
        Avatar(imageURL: post.author?.profilePic, initials: initials, size: 44, fontSize: .sm)
            .overlay(alignment: .bottomTrailing) {
                if let college = post.college {
                    CollegeBadge(college: college).offset(x: 2, y: 2)
                }
            }
    }

    private var menuButton: some View {
        let id = "post-menu-\(post.id)"
        return Button {
            dropdown.toggle(id, placement: .belowTrailing(offset: 28)) { menu }
        } label: {
            Icon("ellipsis", size: 16).foregroundStyle(Palette.gray400).padding(4)
        }
        .buttonStyle(.plain)
        .dropdownAnchor(id)
        .accessibilityLabel("More")
    }

    private var menu: some View {
        DropdownCard(width: 144) {
            if let onDelete {
                Button {
                    dropdown.close()
                    onDelete(post.id)
                } label: {
                    menuRow(icon: "trash", iconColor: Palette.red500, label: deleting ? "Deleting…" : "Delete",
                            color: Palette.red500)
                }
                .buttonStyle(.plain)
                .disabled(deleting)
                .opacity(deleting ? 0.5 : 1)
            }
            if let onReport {
                Button {
                    dropdown.close()
                    onReport(post.id)
                } label: {
                    menuRow(icon: "flag", iconColor: Palette.gray400, label: "Report", color: Palette.gray700)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func menuRow(icon: String, iconColor: Color, label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Icon(icon, size: 16).foregroundStyle(iconColor)
            Text(label).tw(.sm).foregroundStyle(color)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: Body

    private var moderationBadge: some View {
        VStack(alignment: .leading, spacing: 4) {
            let pending = post.reviewStatus == "pending"
            Text(pending ? "Pending approval" : "Rejected")
                .tw(.xs, .semibold)
                .foregroundStyle(pending ? Palette.yellow700 : Palette.red700)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(pending ? Palette.yellow100 : Palette.red100))
            if let note = post.reviewNote, !note.isEmpty {
                Text("Review note: \(note)").tw(.xs).foregroundStyle(Palette.gray500)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if post.isApproved {
                let disabled = appreciating || post.hasAppreciated
                Button { onAppreciate(post.id) } label: {
                    HStack(spacing: 8) {
                        Icon(post.hasAppreciated ? "heart-solid" : "heart-outline", size: 24)
                        Text("\(post.appreciationCount)").tw(.sm, .medium)
                    }
                    .foregroundStyle(post.hasAppreciated ? Palette.red500 : Palette.gray400)
                }
                .buttonStyle(.plain)
                .disabled(disabled)
                .opacity(disabled ? 0.5 : 1)
            } else {
                Text("Available after approval").tw(.xs).foregroundStyle(Palette.gray400)
            }
        }
    }
}

/// `renderBody` — `#word` tokens in semibold inside `text-lg font-medium text-gray-800 leading-relaxed`.
struct PostBodyText: View {
    let text: String

    var body: some View {
        Text(Self.attributed(text))
            .tw(.lg, .medium, leading: .relaxed)
            .foregroundStyle(Palette.gray800)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    static func attributed(_ text: String) -> AttributedString {
        var result = AttributedString()
        let ns = text as NSString
        let regex = try? NSRegularExpression(pattern: "#\(JSRegex.word)+")
        var cursor = 0
        let bold = Font.custom(TW.Weight.semibold.fontName, fixedSize: 18)
        for match in regex?.matches(in: text, range: NSRange(location: 0, length: ns.length)) ?? [] {
            if match.range.location > cursor {
                result += AttributedString(ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            }
            var tag = AttributedString(ns.substring(with: match.range))
            tag.font = bold
            result += tag
            cursor = NSMaxRange(match.range)
        }
        if cursor < ns.length { result += AttributedString(ns.substring(from: cursor)) }
        return result
    }
}

/// The college logo badge on a post author's avatar.
private struct CollegeBadge: View {
    let college: PostItem.College
    @State private var failed = false

    var body: some View {
        ZStack {
            Circle().fill(Palette.white)
            if let logo = college.logoUrl, !failed {
                RemoteImage(logo) { phase in
                    switch phase {
                    case .success(let image): Image(uiImage: image).resizable().scaledToFit()
                    case .failure: Color.clear.onAppear { failed = true }
                    case .loading: Color.clear
                    }
                }
                .frame(width: 16, height: 16)
                .clipShape(Circle())
            } else {
                Circle().fill(Palette.navy).frame(width: 16, height: 16)
                Text(String(college.name.prefix(1)).uppercased())
                    .font(.custom(TW.Weight.bold.fontName, fixedSize: 8))
                    .foregroundStyle(Palette.white)
            }
        }
        .frame(width: 20, height: 20)
        .overlay(Circle().strokeBorder(Palette.white, lineWidth: 2))
    }
}
