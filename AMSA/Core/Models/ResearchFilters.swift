import Foundation

/// `Filters` / `DEFAULT_FILTERS` from research/types.ts, plus the page's filter/sort logic.
struct ResearchFilters: Equatable, Sendable {
    var offersAidOnly = false
    var minAidPercent: Double = 0
    var maxTotalCOA: Double = 200_000
    var maxNetCost: Double = 200_000
    var meetsFullNeedOnly = false
    var meritScholarshipsOnly = false
    var minInternationalPercent: Double = 0
    var stemOptOnly = false
    var selectedField = "Any"
    var sortBy = "ranking"
    var schoolCategory = "national_universities"
    var searchQuery = ""

    static let defaults = ResearchFilters()

    private static let stemFields: Set<String> = [
        "engineering", "computer science", "math and statistics", "physical sciences", "biology", "architecture",
        "health and nursing", "natural resources",
    ]

    /// `activeCount` in FilterDropdown (search text is not counted).
    var activeCount: Int {
        var n = 0
        if selectedField != "Any" { n += 1 }
        if sortBy != "ranking" { n += 1 }
        if schoolCategory != "national_universities" { n += 1 }
        if offersAidOnly { n += 1 }
        if meetsFullNeedOnly { n += 1 }
        if meritScholarshipsOnly { n += 1 }
        if stemOptOnly { n += 1 }
        if minAidPercent > 0 { n += 1 }
        if maxTotalCOA < Self.defaults.maxTotalCOA { n += 1 }
        if maxNetCost < Self.defaults.maxNetCost { n += 1 }
        if minInternationalPercent > 0 { n += 1 }
        return n
    }

    /// `isFiltered` on the research page.
    func isFiltered(selectedState: String?) -> Bool {
        selectedState != nil || offersAidOnly || minAidPercent > 0 || maxTotalCOA < 200_000 || maxNetCost < 200_000
            || meetsFullNeedOnly || meritScholarshipsOnly || minInternationalPercent > 0 || stemOptOnly
            || (selectedField != "Any" && !selectedField.trimmed.isEmpty) || sortBy != "ranking"
            || schoolCategory != "national_universities" || !searchQuery.trimmed.isEmpty
    }

    func matches(_ c: College, selectedState: String?) -> Bool {
        let lacOnly = schoolCategory == "liberal_arts_colleges"
        if let selectedState, c.stateAbbr != selectedState { return false }
        if offersAidOnly, !c.offersAidToInternationals { return false }
        if (c.percentReceivingAid ?? 0) < minAidPercent { return false }
        if c.totalCostOfAttendance > maxTotalCOA { return false }
        if (c.estimatedNetCost ?? c.totalCostOfAttendance) > maxNetCost { return false }
        if meetsFullNeedOnly, !c.meetsFullDemonstratedNeed { return false }
        if meritScholarshipsOnly, c.meritScholarships.isEmpty { return false }
        if (c.internationalPercent ?? 0) < minInternationalPercent { return false }
        if stemOptOnly, !c.stemOptEligible { return false }
        if selectedField != "Any" {
            let q = selectedField.lowercased().trimmed
            let matchesCategories = c.majorCategories.contains { $0.lowercased().contains(q) }
            // Fallback: if no categories in DB, use has_stem_programs for STEM-adjacent fields
            let matchesStemFallback = c.majorCategories.isEmpty && c.stemOptEligible && Self.stemFields.contains(q)
            if !q.isEmpty, !matchesCategories, !matchesStemFallback { return false }
        }
        if (c.type == "liberal_arts") != lacOnly { return false }
        let search = searchQuery.lowercased().trimmed
        if !search.isEmpty, !"\(c.name) \(c.location) \(c.state)".lowercased().contains(search) { return false }
        return true
    }

    /// Filter + sort. Stable like `Array.prototype.sort`: equal keys keep catalog order.
    func apply(to colleges: [College], selectedState: String?) -> [College] {
        let filtered = colleges.enumerated().filter { matches($0.element, selectedState: selectedState) }
        return filtered.sorted { a, b in
            if sortBy == "ranking" {
                // Unranked schools trail, ordered by financial score.
                let ar = a.element.nationalRank ?? Int.max
                let br = b.element.nationalRank ?? Int.max
                if ar != br { return ar < br }
            }
            let sa = a.element.financialAccessibilityScore
            let sb = b.element.financialAccessibilityScore
            if sa != sb { return sa > sb }
            return a.offset < b.offset
        }.map(\.element)
    }

    /// `fieldOptions`: STANDARD_FIELDS ∪ every college's majorCategories, sorted (without "Any").
    static func fieldOptions(_ colleges: [College]) -> [String] {
        var set = Set(StaticData.constants.standardFields)
        for c in colleges { set.formUnion(c.majorCategories) }
        return set.sorted { $0.localizedCompare($1) == .orderedAscending }
    }
}
