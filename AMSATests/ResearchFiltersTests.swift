import Foundation
import Testing
@testable import AMSA

/// Mirrors the `filtered` memo in research/page.tsx.
@Suite("Research filters and sort")
struct ResearchFiltersTests {
    let catalog: [College]

    init() throws {
        catalog = [
            try Fixture.college(1, "Alpha University", [
                "state": "CA", "type": "private", "nationalRank": 5, "financialAccessibilityScore": 80,
                "totalCostOfAttendance": 80_000, "estimatedNetCost": 30_000, "offersAidToInternationals": true,
                "percentReceivingAid": 50, "internationalPercent": 10, "majorCategories": ["Engineering", "Business"],
                "stemOptEligible": true, "meetsFullDemonstratedNeed": true,
                "meritScholarships": [["name": "Dean's", "amount": 10_000]], "location": "Palo Alto, CA",
            ]),
            try Fixture.college(2, "Beta College", [
                "state": "NY", "type": "liberal_arts", "nationalRank": 3, "financialAccessibilityScore": 70,
                "totalCostOfAttendance": 70_000,
            ]),
            try Fixture.college(3, "Gamma Institute", [
                "state": " ca ", "type": "public", "financialAccessibilityScore": 90, "totalCostOfAttendance": 50_000,
                "majorCategories": [], "stemOptEligible": true,
            ]),
            try Fixture.college(4, "Delta State", [
                "state": "TX", "type": "public", "financialAccessibilityScore": 60, "totalCostOfAttendance": 20_000,
            ]),
            try Fixture.college(5, "Epsilon Univ", [
                "state": "CA", "type": "private", "nationalRank": 5, "financialAccessibilityScore": 85,
                "totalCostOfAttendance": 90_000, "estimatedNetCost": 45_000,
                "majorCategories": ["Computer Science and Engineering"],
            ]),
        ]
    }

    private func ids(_ filters: ResearchFilters, state: String? = nil) -> [Int] {
        filters.apply(to: catalog, selectedState: state).map(\.id)
    }

    @Test func defaultsRankThenScoreWithUnrankedLast() {
        // National list only (Beta is a liberal-arts college); rank ties break on score, unranked trail by score.
        #expect(ids(.defaults) == [5, 1, 3, 4])
    }

    @Test func stateMatchesTrimmedUppercase() {
        #expect(ids(.defaults, state: "CA") == [5, 1, 3])
    }

    @Test func liberalArtsListIsSeparate() {
        var f = ResearchFilters.defaults
        f.schoolCategory = "liberal_arts_colleges"
        #expect(ids(f) == [2])
    }

    @Test func fieldUsesCategoriesWithStemFallback() {
        var f = ResearchFilters.defaults
        f.selectedField = "Computer Science"
        // Epsilon: category substring match. Gamma: no categories + STEM OPT + STEM field.
        #expect(ids(f) == [5, 3])
        f.selectedField = "Business"
        #expect(ids(f) == [1])
    }

    @Test func nonRankingSortIsScoreOnly() {
        var f = ResearchFilters.defaults
        f.sortBy = "aid"
        #expect(ids(f) == [3, 5, 1, 4])
    }

    @Test func costFilters() {
        var f = ResearchFilters.defaults
        f.maxNetCost = 40_000 // net falls back to total cost of attendance
        #expect(ids(f) == [1, 4])
        f = .defaults
        f.maxTotalCOA = 60_000
        #expect(ids(f) == [3, 4])
    }

    @Test func aidToggles() {
        var f = ResearchFilters.defaults
        f.offersAidOnly = true
        #expect(ids(f) == [1])
        f = .defaults
        f.meritScholarshipsOnly = true
        #expect(ids(f) == [1])
        f = .defaults
        f.minAidPercent = 1
        #expect(ids(f) == [1])
        f = .defaults
        f.stemOptOnly = true
        #expect(ids(f) == [1, 3])
    }

    @Test func searchMatchesNameLocationAndState() {
        var f = ResearchFilters.defaults
        f.searchQuery = "gamma"
        #expect(ids(f) == [3])
        f.searchQuery = "  DELTA "
        #expect(ids(f) == [4])
        f.searchQuery = "tx"
        #expect(ids(f) == [4])
        f.searchQuery = "palo alto"
        #expect(ids(f) == [1])
    }

    @Test func sortIsStable() throws {
        let twins = [
            try Fixture.college(10, "First", ["nationalRank": 1, "financialAccessibilityScore": 50]),
            try Fixture.college(11, "Second", ["nationalRank": 1, "financialAccessibilityScore": 50]),
            try Fixture.college(12, "Third", ["nationalRank": 1, "financialAccessibilityScore": 50]),
        ]
        #expect(ResearchFilters.defaults.apply(to: twins, selectedState: nil).map(\.id) == [10, 11, 12])
    }

    @Test func activeCountIgnoresSearch() {
        var f = ResearchFilters.defaults
        #expect(f.activeCount == 0)
        f.searchQuery = "x"
        #expect(f.activeCount == 0)
        f.sortBy = "aid"
        f.offersAidOnly = true
        f.maxNetCost = 40_000
        #expect(f.activeCount == 3)
    }

    @Test func isFiltered() {
        var f = ResearchFilters.defaults
        #expect(!f.isFiltered(selectedState: nil))
        #expect(f.isFiltered(selectedState: "CA"))
        f.searchQuery = "   "
        #expect(!f.isFiltered(selectedState: nil))
        f.searchQuery = "a"
        #expect(f.isFiltered(selectedState: nil))
    }
}
