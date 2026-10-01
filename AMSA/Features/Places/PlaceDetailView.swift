import SwiftUI

// Port of src/app/(dashboard)/dashboard/places/[abbr]/page.tsx (mobile: info stacked above Reviews).
struct PlaceDetailView: View {
    let abbr: String

    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router
    @Environment(ExternalLinkPresenter.self) private var links

    @State private var members: [PlacesAPI.Member] = []
    @State private var membersLoading = true

    private var info: StateInfo? { StaticData.statesByAbbr[abbr.uppercased()] }

    var body: some View {
        ScrollView {
            if let info {
                VStack(alignment: .leading, spacing: 0) {
                    details(info).padding(24)
                    ReviewsColumn(config: .place(abbr: info.abbr, stateName: info.name))
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Button { router.back(to: .places) } label: {
                        Text("← Back to Places").tw(.sm).foregroundStyle(Palette.navy)
                    }
                    .buttonStyle(.plain)
                    Text("State not found.").tw(.base).foregroundStyle(Palette.gray500)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 32)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .task { await loadMembers() }
    }

    private func details(_ info: StateInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { router.back(to: .places) } label: {
                HStack(spacing: 6) {
                    Icon("chevron-left-thick", size: 16)
                    Text("Back to Places").tw(.sm)
                }
                .foregroundStyle(Palette.gray500)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)

            FlowLayout(spacing: 12) {
                Text(info.name).tw(.x2l, .bold).foregroundStyle(Palette.navy)
                let (bg, fg, border) = info.colTier.colors
                Text("Cost of Living: \(info.colTier.label)")
                    .tw(.xs, .semibold)
                    .foregroundStyle(fg)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(bg))
                    .overlay(Capsule().strokeBorder(border, lineWidth: 1))
            }
            .padding(.bottom, 24)

            // Stats — `grid grid-cols-2 gap-y-5 gap-x-4`
            Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 20) {
                GridRow {
                    stat("Monthly Rent", info.monthlyRent, sub: "1-bedroom apt", color: Palette.navy)
                    stat("Public Transit", info.publicTransport.detailLabel, sub: "in major cities", color: info.publicTransport.color)
                }
                GridRow {
                    stat("Temperature", info.tempRange, sub: nil, color: Palette.navy)
                }
            }
            .padding(.bottom, 20)

            InfoSection(label: "Climate") {
                Text(info.climate).tw(.sm, leading: .relaxed).foregroundStyle(Palette.gray700)
            }
            InfoSection(label: "Getting Around") {
                Text(info.transitInfo).tw(.sm, leading: .relaxed).foregroundStyle(Palette.gray700)
            }
            if !info.cities.isEmpty {
                InfoSection(label: "Major Cities") {
                    Text(info.cities.joined(separator: " · ")).tw(.sm, leading: .relaxed).foregroundStyle(Palette.gray700)
                }
            }
            if !info.places.isEmpty {
                InfoSection(label: "Notable Places") {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                              alignment: .leading, spacing: 12) {
                        ForEach(info.places, id: \.self) { place in
                            PlacePhotoCard(query: "\(place) \(info.name)", label: place)
                        }
                    }
                }
            }
            membersSection
            InfoSection(label: "Find Housing & Resources") {
                VStack(spacing: 0) {
                    let city = info.cities.first ?? info.name
                    let lower = info.abbr.lowercased()
                    let google = "student housing \(city) \(info.name)".addingPercentEncoding(withAllowedCharacters: .jsURIComponent) ?? ""
                    housingLink("Apartments.com", "Rentals across \(info.name)", "https://www.apartments.com/\(lower)/")
                    TWDivider(color: Palette.gray200)
                    housingLink("Zillow Rentals", "Houses & apartments for rent", "https://www.zillow.com/\(lower)/rentals/")
                    TWDivider(color: Palette.gray200)
                    housingLink("Student housing in \(city)", "Search student-focused listings",
                                "https://www.google.com/search?q=\(google)")
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String, sub: String?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).tw(.xs, .medium).foregroundStyle(Palette.gray400).padding(.bottom, 4)
            Text(value).tw(.base, .bold, leading: .snug).foregroundStyle(color)
            if let sub { Text(sub).tw(.xs).foregroundStyle(Palette.gray400).padding(.top, 2) }
        }
    }

    private func housingLink(_ label: String, _ desc: String, _ href: String) -> some View {
        Button { links.open(href) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(label).tw(.sm, .semibold).foregroundStyle(Palette.gray900)
                    Text(desc).tw(.xs).foregroundStyle(Palette.gray400)
                }
                Spacer(minLength: 0)
                Icon("external-link", size: 16).foregroundStyle(Palette.gray300)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var membersSection: some View {
        // Hidden entirely once loading finishes with no members.
        if membersLoading || !members.isEmpty {
            InfoSection(label: "AMSA Members Here") {
                VStack(spacing: 8) {
                    if membersLoading {
                        ForEach(0..<4, id: \.self) { _ in
                            HStack(spacing: 12) {
                                Circle().fill(Palette.gray200).frame(width: 36, height: 36)
                                VStack(alignment: .leading, spacing: 6) {
                                    SkeletonBar(fraction: 2 / 3, height: 12, color: Palette.gray200)
                                    SkeletonBar(fraction: 1 / 2, height: 10, color: Palette.gray100)
                                }
                            }
                            .padding(12)
                            .overlay(RoundedRectangle(cornerRadius: TW.radiusXl).strokeBorder(Palette.gray100, lineWidth: 2))
                            .twPulse()
                        }
                    } else {
                        ForEach(members) { m in memberRow(m) }
                    }
                }
            }
        }
    }

    private func memberRow(_ m: PlacesAPI.Member) -> some View {
        Button { router.navigate(to: .memberProfile(id: m.id)) } label: {
            HStack(spacing: 12) {
                Avatar(imageURL: m.profilePic, initials: .initials(m.firstName, m.lastName), size: 36, fontSize: .xs)
                VStack(alignment: .leading, spacing: 0) {
                    (Text("\(m.firstName ?? "") \(m.lastName ?? "")")
                        + Text(m.role == Role.ambassador ? "  Ambassador" : "")
                        .font(.custom(TW.Weight.medium.fontName, fixedSize: 12)).foregroundColor(Palette.gray400))
                        .tw(.sm, .semibold)
                        .foregroundStyle(Palette.gray900)
                        .lineLimit(1)
                    let sub = [m.city?.nilIfEmpty, m.schoolName?.nilIfEmpty, m.graduationYear?.value.nilIfEmpty].compactMap { $0 }
                    if !sub.isEmpty {
                        Text(sub.joined(separator: " · ")).tw(.xs).foregroundStyle(Palette.gray400).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .twBox(background: Palette.white, radius: TW.radiusXl, border: Palette.gray200, borderWidth: 2)
        }
        .buttonStyle(.plain)
    }

    private func loadMembers() async {
        membersLoading = true
        members = (try? await session.api.send(PlacesAPI.members(abbr)))?.members ?? []
        membersLoading = false
    }
}

/// `py-5 border-t-2 border-gray-300 first:border-t-0 first:pt-0` + uppercase label.
struct InfoSection<Content: View>: View {
    let label: String
    var first: Bool = false
    var icon: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let icon { Icon(icon, size: 18).foregroundStyle(Palette.navy).opacity(0.6) }
                Text(label.uppercased()).tw(.sm, .semibold, tracking: .wide).foregroundStyle(Palette.gray400)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, first ? 0 : 20)
        .padding(.bottom, 20)
        .overlay(alignment: .top) { if !first { Palette.gray300.frame(height: 2) } }
    }
}

private struct PlacePhotoCard: View {
    let query: String
    let label: String

    @Environment(SessionStore.self) private var session
    @State private var photo: PlacesAPI.Photo?
    @State private var loading = true
    @State private var zoomed: LightboxItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Palette.gray100
                if loading {
                    Palette.gray200.twPulse()
                } else if let photo {
                    Button {
                        zoomed = LightboxItem(url: photo.large, caption: "\(label) · Photo by ",
                                              captionLink: photo.photographerUrl.map { (label: photo.photographer ?? "", url: $0) },
                                              captionSuffix: " on Pexels")
                    } label: {
                        RemoteImage(photo.thumb) { phase in
                            if let image = phase.image { Image(uiImage: image).resizable().scaledToFill() }
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Icon("map-pin-outline", size: 24).foregroundStyle(Palette.gray300)
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: TW.radiusLg))
            Text(label).tw(.sm, .medium, leading: .snug).foregroundStyle(Palette.gray800)
        }
        .task(id: query) {
            loading = true
            photo = (try? await session.api.send(PlacesAPI.photo(query)))?.photo
            loading = false
        }
        .lightbox($zoomed)
    }
}
