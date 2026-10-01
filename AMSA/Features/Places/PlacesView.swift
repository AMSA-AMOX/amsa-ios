import SwiftUI

enum PlacesAPI {
    struct CountsResponse: Decodable, Sendable { let counts: [String: Int]? }
    struct Member: Decodable, Sendable, Identifiable {
        let id: Int
        let firstName: String?
        let lastName: String?
        let profilePic: String?
        let role: String?
        let schoolName: String?
        let graduationYear: FlexibleString?
        let city: String?
        let logoDomain: String?
    }
    struct MembersResponse: Decodable, Sendable { let members: [Member]? }
    struct Photo: Decodable, Sendable, Equatable {
        let thumb: String
        let large: String
        let photographer: String?
        let photographerUrl: String?
        let alt: String?
    }
    struct PhotoResponse: Decodable, Sendable { let photo: Photo? }

    /// GET /api/places/student-counts (plain fetch).
    static func studentCounts() -> Endpoint<CountsResponse> {
        Endpoint(path: "/api/places/student-counts", authenticated: false)
    }
    static func members(_ abbr: String) -> Endpoint<MembersResponse> {
        Endpoint(path: "/api/places/\(abbr.lowercased())/members", authenticated: false)
    }
    static func photo(_ query: String) -> Endpoint<PhotoResponse> {
        Endpoint(path: "/api/place-photo", query: [("q", query)], authenticated: false)
    }
}

extension StateInfo.CostTier {
    var label: String {
        switch self {
        case .veryHigh: "Very High"
        case .high: "High"
        case .moderate: "Moderate"
        case .affordable: "Affordable"
        }
    }
    /// `bg / text / border`
    var colors: (Color, Color, Color) {
        switch self {
        case .veryHigh: (Palette.red50, Palette.red700, Palette.red200)
        case .high: (Palette.orange50, Palette.orange700, Palette.orange200)
        case .moderate: (Palette.amber50, Palette.amber700, Palette.amber200)
        case .affordable: (Palette.green50, Palette.green700, Palette.green200)
        }
    }
}

extension StateInfo.Transit {
    /// places/page.tsx filter label.
    var filterLabel: String {
        switch self {
        case .excellent: "Excellent"
        case .good: "Good"
        case .limited: "Limited"
        case .poor: "Poor / Car needed"
        }
    }
    /// places/[abbr] stat label.
    var detailLabel: String { self == .poor ? "Car needed" : filterLabel }
    var color: Color {
        switch self {
        case .excellent: Palette.green700
        case .good: Palette.blue700
        case .limited: Palette.amber700
        case .poor: Palette.red600
        }
    }
}

// Port of src/app/(dashboard)/dashboard/places/page.tsx
struct PlacesView: View {
    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router

    @State private var search = ""
    @State private var colTiers: Set<StateInfo.CostTier> = []
    @State private var transit: Set<StateInfo.Transit> = []
    @State private var studentCounts: [String: Int] = [:]
    @State private var filterOpen = false
    @FocusState private var searchFocused: Bool

    private static let allStates = StaticData.states.sorted {
        $0.name.localizedStandardCompare($1.name) == .orderedAscending
    }

    private var filtered: [StateInfo] {
        let q = search.trimmed.lowercased()
        return Self.allStates.filter { info in
            // Match on the state only — its full name or two-letter abbreviation.
            if !q.isEmpty, !info.name.lowercased().contains(q), info.abbr.lowercased() != q { return false }
            if !colTiers.isEmpty, !colTiers.contains(info.colTier) { return false }
            if !transit.isEmpty, !transit.contains(info.publicTransport) { return false }
            return true
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    SearchField(placeholder: "Search states…", text: $search, focused: $searchFocused)
                    filterButton
                        .overlay(alignment: .topLeading) {
                            if filterOpen { filterPanel.offset(y: 48) }
                        }
                        .zIndex(1)
                }
                .padding(.bottom, 20)
                .zIndex(1)

                StateCarousel(states: filtered, counts: studentCounts) { abbr in
                    router.navigate(to: .placeDetail(abbr: abbr))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .task {
            studentCounts = (try? await session.api.send(PlacesAPI.studentCounts()))?.counts ?? [:]
        }
    }

    private var filterButton: some View {
        Button { filterOpen.toggle() } label: {
            HStack(spacing: 6) {
                Icon("adjustments", size: 24).foregroundStyle(Palette.gray500)
                if !colTiers.isEmpty || !transit.isEmpty {
                    Text("· \(colTiers.count + transit.count)").tw(.sm, .semibold).foregroundStyle(Palette.gray700)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .twBox(background: Palette.white, radius: TW.dashboardButtonRadius, border: Palette.gray300, borderWidth: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filters")
    }

    /// `absolute left-0 top-full mt-2 z-20 bg-white rounded-2xl border-2 border-gray-200 shadow-xl p-5 w-80`
    /// (the web panel only closes from its button).
    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("COST OF LIVING").tw(.xs, .semibold, tracking: .wide).foregroundStyle(Palette.gray400)
                FlowLayout(spacing: 6) {
                    ForEach(StateInfo.CostTier.allCases, id: \.self) { tier in
                        FilterChip(label: tier.label, selected: colTiers.contains(tier)) {
                            if colTiers.contains(tier) { colTiers.remove(tier) } else { colTiers.insert(tier) }
                        }
                    }
                }
            }
            .padding(.bottom, 16)
            VStack(alignment: .leading, spacing: 8) {
                Text("PUBLIC TRANSIT").tw(.xs, .semibold, tracking: .wide).foregroundStyle(Palette.gray400)
                FlowLayout(spacing: 6) {
                    ForEach(StateInfo.Transit.allCases, id: \.self) { rating in
                        FilterChip(label: rating.filterLabel, selected: transit.contains(rating)) {
                            if transit.contains(rating) { transit.remove(rating) } else { transit.insert(rating) }
                        }
                    }
                }
            }
            if !colTiers.isEmpty || !transit.isEmpty {
                Button {
                    colTiers = []
                    transit = []
                } label: {
                    Text("Clear all").tw(.sm, .semibold).foregroundStyle(Palette.gray600)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).strokeBorder(Palette.gray200, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
            }
        }
        .padding(20)
        .frame(width: 320)
        .background(RoundedRectangle(cornerRadius: TW.radius2xl).fill(Palette.white))
        .overlay(RoundedRectangle(cornerRadius: TW.radius2xl).strokeBorder(Palette.gray200, lineWidth: 2))
        .twShadow(.xl)
    }
}

/// Centered, snap-paging state carousel. The web version's fixed math (CARD_W 340 in a 1180px
/// track) leaves the active card off-screen on phones and has no touch handling; this keeps its
/// card and its per-card scale / opacity / lift formulas, sized to fit the screen.
private struct StateCarousel: View {
    let states: [StateInfo]
    let counts: [String: Int]
    let onSelect: (String) -> Void

    @State private var current: String?

    private static let cardGap: CGFloat = 20
    private static let peek: CGFloat = 40

    var body: some View {
        if states.isEmpty {
            Text("No states match your filters.")
                .tw(.sm).foregroundStyle(Palette.gray400)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 64)
        } else {
            GeometryReader { proxy in
                let viewport = proxy.size.width
                let cardWidth = min(340, viewport - 2 * Self.peek)
                content(viewport: viewport, cardWidth: cardWidth)
            }
            .frame(height: carouselHeight)
            .onChange(of: states.map(\.abbr)) { _, _ in current = states.first?.abbr }
            .onAppear { if current == nil { current = states.first?.abbr } }
        }
    }

    private var carouselHeight: CGFloat {
        let viewport = UIScreen.main.bounds.width - 32
        let cardWidth = min(340, viewport - 2 * Self.peek)
        let imageHeight = (cardWidth - 24) * 1300 / 830
        let card = 12 + imageHeight + 12 + 20 + 4 + 12
        return card * 1.12 + 40 + 24 + 44
    }

    private func content(viewport: CGFloat, cardWidth: CGFloat) -> some View {
        let slot = cardWidth + Self.cardGap
        let index = states.firstIndex { $0.abbr == current } ?? 0
        return VStack(spacing: 24) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Self.cardGap) {
                    ForEach(states) { state in
                        StateCard(state: state, count: counts[state.abbr] ?? 0)
                            .frame(width: cardWidth)
                            .visualEffect { effect, geometry in
                                let mid = geometry.frame(in: .scrollView).midX
                                let dist = abs(mid - viewport / 2) / slot
                                let opacity = dist <= 1 ? 1 - 0.25 * dist : max(0, 0.75 - 0.35 * (dist - 1))
                                let scale = dist < 1 ? 1 + 0.12 * (1 - dist) : 1
                                let lift = dist < 1 ? -14 * (1 - dist) : 0
                                return effect.scaleEffect(scale).offset(y: lift).opacity(opacity)
                            }
                            .onTapGesture { if state.abbr == current { onSelect(state.abbr) } }
                            .id(state.abbr)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 40)
            }
            .contentMargins(.horizontal, (viewport - cardWidth) / 2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $current)
            .overlay(alignment: .leading) { edgeFade(leading: true) }
            .overlay(alignment: .trailing) { edgeFade(leading: false) }

            HStack(spacing: 16) {
                navButton(icon: "chevron-left-2", label: "Previous", disabled: index == 0) {
                    withAnimation(.easeOut(duration: 0.18)) { current = states[max(0, index - 1)].abbr }
                }
                Text("\(index + 1) / \(states.count)")
                    .tw(.sm, .semibold).foregroundStyle(Palette.gray400).monospacedDigit()
                    .frame(minWidth: 52)
                navButton(icon: "chevron-right-2", label: "Next", disabled: index == states.count - 1) {
                    withAnimation(.easeOut(duration: 0.18)) { current = states[min(states.count - 1, index + 1)].abbr }
                }
            }
        }
    }

    private func edgeFade(leading: Bool) -> some View {
        LinearGradient(colors: [Color(.sRGB, red: 249 / 255, green: 250 / 255, blue: 251 / 255, opacity: 0.85), .clear],
                       startPoint: leading ? .leading : .trailing, endPoint: leading ? .trailing : .leading)
            .frame(width: 40)
            .allowsHitTesting(false)
    }

    private func navButton(icon: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Icon(icon, size: 20).foregroundStyle(Palette.gray600)
                .padding(.horizontal, 20)
                .frame(height: 44)
                .twBox(background: Palette.white, radius: TW.dashboardButtonRadius, border: Palette.gray200, borderWidth: 2)
                .twShadow(.sm)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.3 : 1)
        .accessibilityLabel(label)
    }
}

private struct StateCard: View {
    let state: StateInfo
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RemoteImage(url: AppConfig.current.siteURL("/states/\(state.photo.file)")) { phase in
                    if let image = phase.image {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Palette.gray100
                    }
                }
                .aspectRatio(830 / 1300, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: TW.radiusLg))
            }
            .overlay(alignment: .top) {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image("Logo").resizable().scaledToFill().frame(width: 20, height: 20).clipShape(Circle())
                        Text("\(count)").tw(.xs, .bold, leading: .leadingNone).foregroundStyle(Palette.gray900)
                    }
                    .padding(.leading, 4).padding(.trailing, 10).padding(.vertical, 2)
                    .background(Capsule().fill(.white.opacity(0.8)))
                    HStack(spacing: 4) {
                        Icon("map-pin-solid", size: 16).foregroundStyle(Palette.red500)
                        Text("\(state.photo.location), \(state.abbr)").tw(.xs, .semibold, leading: .leadingNone)
                            .foregroundStyle(Palette.gray900).lineLimit(1)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.8)))
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .opacity(0.7)
            }
            .overlay(alignment: .bottomTrailing) {
                Icon("arrow-up-right", size: 32).foregroundStyle(Palette.gray800)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Palette.gray200.opacity(0.9)))
                    .padding(4)
            }

            Text(state.name.uppercased())
                .tw(.px(20, lineHeight: 20), .black, tracking: .wide)
                .foregroundStyle(Palette.gray950)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 4)
                .padding(.top, 12)
                .padding(.bottom, 4)
        }
        .padding(12)
        .twBox(background: Palette.white, radius: TW.radiusXl, border: Palette.gray100, borderWidth: 2)
        .contentShape(Rectangle())
    }
}
