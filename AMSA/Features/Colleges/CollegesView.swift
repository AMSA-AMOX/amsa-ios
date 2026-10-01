import SwiftUI

// Port of src/app/(dashboard)/dashboard/research/page.tsx
struct CollegesView: View {
    @Environment(CollegesStore.self) private var store
    @Environment(Router.self) private var router

    private static let pageSize = 10

    @State private var filters = ResearchFilters.defaults
    @State private var compareIds: [Int] = Preferences.compareIds
    @State private var currentPage = 1
    @State private var selectedState: String?
    @State private var dropdown = DropdownController()
    @FocusState private var searchFocused: Bool

    var body: some View {
        let filtered = filters.apply(to: store.colleges, selectedState: selectedState)
        let totalPages = max(1, Int(ceil(Double(filtered.count) / Double(Self.pageSize))))
        let start = min((currentPage - 1) * Self.pageSize, filtered.count)
        let display = filtered[start..<min(currentPage * Self.pageSize, filtered.count)]

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topFilterBar.padding(.bottom, 20).zIndex(1)

                if !store.loading, store.error.isEmpty {
                    USMapView(colleges: store.colleges, selectedState: selectedState) { selectedState = $0 }
                        .padding(.bottom, 24)
                }

                if store.loading {
                    VStack(spacing: 16) { ForEach(0..<5, id: \.self) { _ in cardSkeleton } }
                } else if !store.error.isEmpty {
                    VStack(spacing: 4) {
                        Text("Could not load college data").tw(.sm, .semibold).foregroundStyle(Palette.red700)
                        Text(store.error).tw(.xs).foregroundStyle(Palette.red500)
                        Text("Make sure the pipeline has been run (scripts/pipeline/run-pipeline.ts) and the Supabase colleges_base table is populated.")
                            .tw(.xs).foregroundStyle(Palette.gray400).padding(.top, 4)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .twBox(background: Palette.red50, radius: TW.radius2xl, border: Palette.red100)
                } else {
                    resultsHeader(count: filtered.count, totalPages: totalPages).padding(.bottom, 16)
                    legend.padding(.bottom, 16)
                    VStack(spacing: 16) {
                        ForEach(display) { college in
                            CollegeCard(college: college, compared: compareIds.contains(college.id),
                                        onToggleCompare: { toggleCompare(college.id) },
                                        onDetail: { router.navigate(to: .collegeDetail(id: college.id)) })
                        }
                    }
                    if filtered.count > Self.pageSize {
                        HStack(spacing: 8) {
                            pageButton("Previous", disabled: currentPage == 1) { currentPage = max(1, currentPage - 1) }
                            Text("Page \(currentPage) of \(totalPages)").tw(.sm).foregroundStyle(Palette.gray500)
                            pageButton("Next", disabled: currentPage == totalPages) { currentPage = min(totalPages, currentPage + 1) }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    }
                    if filtered.isEmpty { emptyState }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 52)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .dropdownHost(dropdown)
        .onAppear { store.load() }
        .onChange(of: filters) { _, _ in currentPage = 1 }
        .onChange(of: selectedState) { _, _ in currentPage = 1 }
    }

    // MARK: Filter bar

    private var topFilterBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            SearchField(placeholder: "School, city, or state…", text: $filters.searchQuery, focused: $searchFocused)
            Button {
                dropdown.toggle("research-filters", placement: .belowLeading(offset: 40 + 8)) {
                    FilterDropdownPanel(filters: $filters, fieldOptions: ResearchFilters.fieldOptions(store.colleges))
                }
            } label: {
                HStack(spacing: 6) {
                    Icon("adjustments", size: 24).foregroundStyle(Palette.gray500)
                    if filters.activeCount > 0 {
                        Text("· \(filters.activeCount)").tw(.sm, .semibold).foregroundStyle(Palette.gray700)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .twBox(background: Palette.white, radius: TW.dashboardButtonRadius, border: Palette.gray300, borderWidth: 2)
            }
            .buttonStyle(.plain)
            .dropdownAnchor("research-filters")
            .accessibilityLabel("Filters")
        }
    }

    private func resultsHeader(count: Int, totalPages: Int) -> some View {
        let scope = selectedState.map { " in \(StaticData.stateName($0) ?? $0)" } ?? " match your filters"
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            (Text("\(count)").font(.custom(TW.Weight.semibold.fontName, fixedSize: 14)).foregroundColor(Palette.navy)
                + Text(" school\(count != 1 ? "s" : "")\(scope) · page \(currentPage)/\(totalPages)"))
                .tw(.sm)
                .foregroundStyle(Palette.gray500)
            if filters.isFiltered(selectedState: selectedState) {
                Button {
                    filters = .defaults
                    selectedState = nil
                } label: {
                    Text("Reset all").tw(.xs).underline().foregroundStyle(Palette.gray400)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var legend: some View {
        FlowLayout(spacing: 16, lineSpacing: 8) {
            Text("Data quality:").tw(.xs, .medium).foregroundStyle(Palette.gray500)
            legendItem(Palette.green500, "High confidence")
            legendItem(Palette.amber400, "Estimated")
            legendItem(Palette.gray300, "Limited data")
        }
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).tw(.xs).foregroundStyle(Palette.gray400)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Text("No schools match").tw(.sm, .semibold).foregroundStyle(Palette.gray600).padding(.bottom, 4)
            Text(selectedState.map { "No schools in \(StaticData.stateName($0) ?? $0) match your current filters." }
                 ?? "Try loosening your filters — very few schools meet all criteria simultaneously.")
                .tw(.xs).foregroundStyle(Palette.gray400).multilineTextAlignment(.center).padding(.bottom, 16)
            Button {
                filters = .defaults
                selectedState = nil
            } label: {
                Text("Reset all filters").tw(.xs, .semibold).foregroundStyle(Palette.navy)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).strokeBorder(Palette.navy.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .twBox(background: Palette.white, radius: TW.radius2xl, border: Palette.gray300, borderWidth: 2)
    }

    private var cardSkeleton: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                RoundedRectangle(cornerRadius: TW.radius2xl).fill(Palette.gray100).frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonBar(fraction: 1 / 4, height: 12)
                    SkeletonBar(fraction: 2 / 3, height: 16)
                    SkeletonBar(fraction: 1 / 3, height: 12)
                }
            }
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in RoundedRectangle(cornerRadius: TW.radiusXl).fill(Palette.gray100).frame(height: 56) }
            }
        }
        .padding(20)
        .twBox(background: Palette.white, radius: TW.radius2xl, border: Palette.gray300, borderWidth: 2)
        .twPulse()
    }

    private func pageButton(_ title: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).tw(.sm).foregroundStyle(Palette.gray600)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).strokeBorder(Palette.gray200, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }

    private func toggleCompare(_ id: Int) {
        if let index = compareIds.firstIndex(of: id) { compareIds.remove(at: index) } else { compareIds.append(id) }
        Preferences.compareIds = compareIds
    }
}

// MARK: - Filter dropdown

/// `absolute left-0 top-full mt-2 z-30 bg-white rounded-2xl border-2 border-gray-300 shadow-xl p-5
/// w-[22rem] max-w-[calc(100vw-2rem)] max-h-[75vh] overflow-y-auto space-y-5`
private struct FilterDropdownPanel: View {
    @Binding var filters: ResearchFilters
    let fieldOptions: [String]

    var body: some View {
        FittingScrollView {
            VStack(alignment: .leading, spacing: 20) {
                group("Field of study") {
                    WebSelect(options: [("Any field", "Any")] + fieldOptions.map { ($0, $0) }, selection: $filters.selectedField,
                              style: selectStyle, showsChevron: true)
                }
                group("Sort by") {
                    WebSelect(options: [("US News Ranking", "ranking"), ("Financial Accessibility Score", "affordability")],
                              selection: $filters.sortBy, style: selectStyle, showsChevron: true)
                }
                group("School category") {
                    WebSelect(options: [("National Universities", "national_universities"),
                                        ("National Liberal Arts Colleges", "liberal_arts_colleges")],
                              selection: $filters.schoolCategory, style: selectStyle, showsChevron: true)
                }
                group("Financial Aid") {
                    VStack(spacing: 8) {
                        FilterToggle(checked: $filters.offersAidOnly, label: "Only schools offering aid to internationals")
                        FilterToggle(checked: $filters.meetsFullNeedOnly, label: "Meets 100% of demonstrated need")
                        FilterToggle(checked: $filters.meritScholarshipsOnly, label: "Has merit scholarships for internationals")
                    }
                    FilterSlider(label: "Min % of internationals receiving aid", value: $filters.minAidPercent, range: 0...100,
                                 step: 5, format: { "\(JSNumber.string($0))%" })
                        .padding(.top, 12)
                }
                group("Cost") {
                    VStack(spacing: 16) {
                        FilterSlider(label: "Max Total Cost of Attendance", value: $filters.maxTotalCOA, range: 40_000...100_000,
                                     step: 5_000, format: Formatters.money)
                        FilterSlider(label: "Max Net Cost (after avg aid)", value: $filters.maxNetCost, range: 10_000...100_000,
                                     step: 5_000, format: Formatters.money)
                    }
                }
                group("International Profile") {
                    FilterSlider(label: "Min % international students", value: $filters.minInternationalPercent, range: 0...30,
                                 step: 1, format: { "\(JSNumber.string($0))%" })
                }
                group("Career") {
                    FilterToggle(checked: $filters.stemOptOnly, label: "STEM OPT eligible programs only (36-month extension)")
                }
                Button { filters = .defaults } label: {
                    Text("Reset all filters").tw(.sm, .semibold).foregroundStyle(Palette.gray600)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).strokeBorder(Palette.gray300, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .frame(width: min(352, UIScreen.main.bounds.width - 32))
        .frame(maxHeight: UIScreen.main.bounds.height * 0.75)
        .background(RoundedRectangle(cornerRadius: TW.radius2xl).fill(Palette.white))
        .clipShape(RoundedRectangle(cornerRadius: TW.radius2xl))
        .overlay(RoundedRectangle(cornerRadius: TW.radius2xl).strokeBorder(Palette.gray300, lineWidth: 2))
        .twShadow(.xl)
    }

    private var selectStyle: InputStyle {
        InputStyle(size: .sm, horizontalPadding: 12, verticalPadding: 8, radius: TW.radiusXl, border: Palette.gray300,
                   borderWidth: 2, textColor: Palette.gray700)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).tw(.xs, .bold, tracking: .wider).foregroundStyle(Palette.gray400)
            content()
        }
    }
}

/// `Toggle` on the research page: a full-width row with a custom check box.
private struct FilterToggle: View {
    @Binding var checked: Bool
    let label: String

    var body: some View {
        Button { checked.toggle() } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: TW.radiusSm).fill(checked ? Palette.navy : .clear)
                    RoundedRectangle(cornerRadius: TW.radiusSm).strokeBorder(checked ? Palette.navy : Palette.gray300, lineWidth: 2)
                    if checked {
                        Image(systemName: "checkmark").font(.system(size: 7, weight: .heavy)).foregroundStyle(Palette.white)
                    }
                }
                .frame(width: 16, height: 16)
                Text(label).tw(.xs, .medium).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .foregroundStyle(checked ? Palette.navy : Palette.gray600)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .twBox(background: checked ? Palette.navy.opacity(0.05) : .clear, radius: TW.dashboardButtonRadius,
                   border: checked ? Palette.navy : Palette.gray200)
        }
        .buttonStyle(.plain)
    }
}

/// `Slider`: shows the live value while dragging, commits on release (`onPointerUp`).
private struct FilterSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    @State private var local: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).tw(.sm, .medium).foregroundStyle(Palette.gray500)
                Spacer(minLength: 8)
                // The defaults (200000) sit above the slider max; the label shows the real value.
                Text(format(local ?? value)).tw(.sm, .semibold).foregroundStyle(Palette.navy)
            }
            Slider(value: Binding(get: { min(max(local ?? value, range.lowerBound), range.upperBound) },
                                  set: { local = $0 }),
                   in: range, step: step) { editing in
                if !editing, let local {
                    value = local
                    self.local = nil
                }
            }
            .tint(Palette.navy)
            HStack {
                Text(format(range.lowerBound)).tw(.xs).foregroundStyle(Palette.gray400)
                Spacer()
                Text(format(range.upperBound)).tw(.xs).foregroundStyle(Palette.gray400)
            }
        }
    }
}

// MARK: - College card

private struct CollegeCard: View {
    let college: College
    let compared: Bool
    let onToggleCompare: () -> Void
    let onDetail: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                SchoolLogoSquare(college: college, size: 64)
                ScoreBadge(score: college.financialAccessibilityScore)
                VStack(alignment: .leading, spacing: 0) {
                    FlowLayout(spacing: 8) {
                        CollegeTypePill(type: college.type)
                        if let rank = college.nationalRank {
                            BadgePill(label: "\(college.type == "liberal_arts" ? "LAC" : "Nat'l") Rank #\(rank)")
                        }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(college.name).tw(.px(15), .bold, leading: .snug).foregroundStyle(Palette.navy)
                        DataQualityDot(source: college.dataSource)
                    }
                    .padding(.top, 4)
                    Text(college.location).tw(.xs).foregroundStyle(Palette.gray400).padding(.top, 2)
                    if !college.majorCategories.isEmpty {
                        let more = college.majorCategories.count > 3 ? " +\(college.majorCategories.count - 3)" : ""
                        Text("Programs: \(college.majorCategories.prefix(3).joined(separator: " · "))\(more)")
                            .tw(.xs).foregroundStyle(Palette.gray500).padding(.top, 4)
                    }
                }
            }
            statGrid.padding(.top, 12)
            HStack(spacing: 12) {
                Spacer()
                Button(action: onToggleCompare) {
                    Text(compared ? "Remove Compare" : "Compare").tw(.sm, .semibold).foregroundStyle(Palette.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).fill(Palette.navy))
                }
                .buttonStyle(.plain)
                Button(action: onDetail) {
                    Text("View Detail").tw(.sm, .semibold).foregroundStyle(Palette.navy)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .overlay(RoundedRectangle(cornerRadius: TW.radiusLg).strokeBorder(Palette.navy.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
        }
        .padding(20)
        .twBox(background: Palette.white, radius: TW.radius2xl, border: Palette.gray300, borderWidth: 2)
    }

    private var statGrid: some View {
        let net = college.estimatedNetCost ?? college.totalCostOfAttendance
        let cells: [(String, String, String)] = [
            ("Est. Net Cost", Formatters.money(net) + "/yr", (college.estimatedNetCost ?? 0) != 0 ? "after avg aid" : "no aid data"),
            ("% Receiving Aid", college.percentReceivingAid.map { Formatters.raw($0) + "%" } ?? "N/A", "of internationals"),
            ("Int'l Students", college.internationalPercent.map { Formatters.raw($0) + "%" } ?? "N/A", "of enrollment"),
            ("Tuition", Formatters.money(college.tuition) + "/yr", college.type == "public" ? "out-of-state" : "full tuition"),
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(cells, id: \.0) { cell in
                VStack(spacing: 2) {
                    Text(cell.0).tw(.xs, .medium).foregroundStyle(Palette.gray500)
                    Text(cell.1).tw(.base, .bold).foregroundStyle(Palette.navy)
                    Text(cell.2).tw(.xs).foregroundStyle(Palette.gray400)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: TW.radiusXl).fill(Palette.gray50))
            }
        }
    }
}

/// `SchoolLogo`: the college's logo.dev image, or its first two letters on gray.
struct SchoolLogoSquare: View {
    let college: College
    var size: CGFloat = 64
    var radius: CGFloat = TW.radiusLg
    var bordered = false
    @State private var broken = false

    var body: some View {
        Group {
            if let logo = college.logoUrl, !broken {
                RemoteImage(logo) { phase in
                    switch phase {
                    case .success(let image): Image(uiImage: image).resizable().scaledToFit()
                    case .failure: Color.clear.onAppear { broken = true }
                    case .loading: Color.clear
                    }
                }
            } else {
                Text(String(college.name.prefix(2)).uppercased())
                    .tw(.xs, .bold)
                    .foregroundStyle(Palette.gray500)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.gray100)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

struct ScoreBadge: View {
    let score: Double
    var body: some View {
        let (bg, border, fg): (Color, Color, Color) =
            score >= 75 ? (Palette.green50, Palette.green300, Palette.green700)
            : score >= 55 ? (Palette.amber50, Palette.amber300, Palette.amber700)
            : (Palette.red50, Palette.red300, Palette.red600)
        VStack(spacing: 2) {
            Text(JSNumber.string(score)).tw(.xl, .bold, leading: .leadingNone)
            Text("SCORE").tw(.xs, .semibold, tracking: .widest).opacity(0.6)
        }
        .foregroundStyle(fg)
        .frame(width: 64, height: 64)
        .twBox(background: bg, radius: TW.radiusLg, border: border, borderWidth: 2)
        .accessibilityLabel("Financial Aid Score")
    }
}

struct CollegeTypePill: View {
    let type: String
    var body: some View {
        let (label, bg, fg, border): (String, Color, Color, Color) = switch type {
        case "public": ("Public", Palette.blue50, Palette.blue700, Palette.blue200)
        case "liberal_arts": ("Liberal Arts", Palette.purple50, Palette.purple700, Palette.purple200)
        default: ("Private", Palette.navy.opacity(0.08), Palette.navy, Palette.navy.opacity(0.2))
        }
        Text(label).tw(.xs, .semibold).foregroundStyle(fg)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(Capsule().fill(bg))
            .overlay(Capsule().strokeBorder(border, lineWidth: 1))
    }
}

struct BadgePill: View {
    let label: String
    var body: some View {
        Text(label).tw(.xs, .semibold).foregroundStyle(Palette.navy)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(Capsule().fill(Palette.navy.opacity(0.08)))
            .overlay(Capsule().strokeBorder(Palette.navy.opacity(0.2), lineWidth: 1))
    }
}

struct DataQualityDot: View {
    let source: String?
    var body: some View {
        let (color, title): (Color, String) = switch source {
        case "cds_high": (Palette.green500, "High confidence — sourced from Common Data Set")
        case "cds_medium": (Palette.amber400, "Estimated — sourced from Common Data Set (partial)")
        case "ipeds_fallback": (Palette.amber400, "General aid data — international-specific data unavailable")
        default: (Palette.gray300, "Limited data available")
        }
        Circle().fill(color).frame(width: 8, height: 8).accessibilityLabel(title)
    }
}
