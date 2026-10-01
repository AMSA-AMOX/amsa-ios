import Foundation

/// `College` from research/types.ts (GET /api/colleges). Only fields the app renders are
/// decoded; every field tolerates null so one odd row can't fail the 3 MB catalog.
struct College: Decodable, Sendable, Identifiable, Hashable {
    struct MeritScholarship: Decodable, Sendable, Hashable {
        let name: String?
        let amount: Double?
    }

    let id: Int
    let name: String
    let stateRaw: String?
    let typeRaw: String?
    let locationRaw: String?
    let website: String?
    let logoUrl: String?

    let overallAcceptanceRate: Double?
    let satAvg: Double?
    let satRead25: Double?
    let satRead75: Double?
    let satMath25: Double?
    let satMath75: Double?
    let act25: Double?
    let actMid: Double?
    let act75: Double?

    let tuitionRaw: Double?
    let roomAndBoardRaw: Double?
    let booksAndSuppliesRaw: Double?
    let personalExpensesRaw: Double?
    let totalCostOfAttendanceRaw: Double?

    let ugds: Double?
    let gradStudents: Double?
    let intlStudentsEstimate: Double?
    let internationalPercent: Double?
    let completionRate4yr: Double?

    let nationalRank: Int?
    let majorCategoriesRaw: [String]?
    let stemOptEligibleRaw: Bool?
    let financialAccessibilityScoreRaw: Double?
    let estimatedNetCost: Double?

    let offersAidToInternationalsRaw: Bool?
    let averageAidPackage: Double?
    let percentReceivingAid: Double?
    let meetsFullDemonstratedNeedRaw: Bool?
    let noLoanPolicyRaw: Bool?
    let meritScholarshipsRaw: [MeritScholarship]?
    let aidIsRenewableRaw: Bool?
    let renewalConditions: String?
    let healthInsuranceRaw: Double?
    let countriesRepresented: Double?
    let activelyRecruitsUnderrepresentedRaw: Bool?
    let internationalAcceptanceRate: Double?
    let dataSource: String?

    let nicheSlug: String?
    let usNewsSlug: String?

    enum CodingKeys: String, CodingKey {
        case id, name, website, logoUrl
        case stateRaw = "state", typeRaw = "type", locationRaw = "location"
        case overallAcceptanceRate, satAvg, satRead25, satRead75, satMath25, satMath75, act25, actMid, act75
        case tuitionRaw = "tuition", roomAndBoardRaw = "roomAndBoard", booksAndSuppliesRaw = "booksAndSupplies"
        case personalExpensesRaw = "personalExpenses", totalCostOfAttendanceRaw = "totalCostOfAttendance"
        case ugds, gradStudents, intlStudentsEstimate, internationalPercent, completionRate4yr
        case nationalRank, estimatedNetCost
        case majorCategoriesRaw = "majorCategories", stemOptEligibleRaw = "stemOptEligible"
        case financialAccessibilityScoreRaw = "financialAccessibilityScore"
        case offersAidToInternationalsRaw = "offersAidToInternationals", averageAidPackage, percentReceivingAid
        case meetsFullDemonstratedNeedRaw = "meetsFullDemonstratedNeed", noLoanPolicyRaw = "noLoanPolicy"
        case meritScholarshipsRaw = "meritScholarships", aidIsRenewableRaw = "aidIsRenewable", renewalConditions
        case healthInsuranceRaw = "healthInsurance", countriesRepresented
        case activelyRecruitsUnderrepresentedRaw = "activelyRecruitsUnderrepresented"
        case internationalAcceptanceRate, dataSource, nicheSlug, usNewsSlug
    }

    // Non-null accessors with the server's defaults.
    var state: String { stateRaw ?? "" }
    var type: String { typeRaw ?? "private" }
    var location: String { locationRaw ?? "" }
    var tuition: Double { tuitionRaw ?? 0 }
    var roomAndBoard: Double { roomAndBoardRaw ?? 0 }
    var booksAndSupplies: Double { booksAndSuppliesRaw ?? 1000 }
    var personalExpenses: Double { personalExpensesRaw ?? 2000 }
    var totalCostOfAttendance: Double { totalCostOfAttendanceRaw ?? 0 }
    var majorCategories: [String] { majorCategoriesRaw ?? [] }
    var stemOptEligible: Bool { stemOptEligibleRaw ?? false }
    var financialAccessibilityScore: Double { financialAccessibilityScoreRaw ?? 0 }
    var offersAidToInternationals: Bool { offersAidToInternationalsRaw ?? false }
    var meetsFullDemonstratedNeed: Bool { meetsFullDemonstratedNeedRaw ?? false }
    var noLoanPolicy: Bool { noLoanPolicyRaw ?? false }
    var meritScholarships: [MeritScholarship] { meritScholarshipsRaw ?? [] }
    var aidIsRenewable: Bool { aidIsRenewableRaw ?? false }
    var healthInsurance: Double { healthInsuranceRaw ?? 3000 }
    var activelyRecruitsUnderrepresented: Bool { activelyRecruitsUnderrepresentedRaw ?? false }

    /// `c.state.trim().toUpperCase()`
    var stateAbbr: String { state.trimmed.uppercased() }

    static func == (lhs: College, rhs: College) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct CollegesResponse: Decodable, Sendable {
    let colleges: [College]?
}
