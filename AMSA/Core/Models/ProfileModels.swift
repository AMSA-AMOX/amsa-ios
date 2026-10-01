import Foundation

/// `Education` rows (GET /api/user/education).
struct Education: Decodable, Sendable, Identifiable, Equatable {
    let id: Int
    let schoolName: String
    let degreeLevel: String?
    let major: String?
    let schoolYear: String?
    let graduationYear: FlexibleString?
    let currentlyEnrolled: Bool

    enum CodingKeys: String, CodingKey {
        case id, schoolName, degreeLevel, major, schoolYear, graduationYear, currentlyEnrolled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        schoolName = try c.decodeIfPresent(String.self, forKey: .schoolName) ?? ""
        degreeLevel = try c.decodeIfPresent(String.self, forKey: .degreeLevel)
        major = try c.decodeIfPresent(String.self, forKey: .major)
        schoolYear = try c.decodeIfPresent(String.self, forKey: .schoolYear)
        graduationYear = try c.decodeIfPresent(FlexibleString.self, forKey: .graduationYear)
        currentlyEnrolled = try c.decodeIfPresent(Bool.self, forKey: .currentlyEnrolled) ?? false
    }
}

struct EducationsResponse: Decodable, Sendable { let educations: [Education]? }
struct EducationResponse: Decodable, Sendable { let education: Education }
struct ExperiencesResponse: Decodable, Sendable { let experiences: [Experience]? }
struct ExperienceResponse: Decodable, Sendable { let experience: Experience }

/// GET /api/user/verification — only `reviewStatus` is needed outside the form.
struct MembershipStatusResponse: Decodable, Sendable {
    struct Membership: Decodable, Sendable { let reviewStatus: String? }
    let membership: Membership?
}

struct CollegeSearchResponse: Decodable, Sendable {
    struct College: Decodable, Sendable, Identifiable, Equatable {
        let id: Int
        let name: String
        let domain: String?
    }
    let colleges: [College]?
}

enum ProfileAPI {
    static func experiences() -> Endpoint<ExperiencesResponse> { Endpoint(path: "/api/user/experience") }
    static func createExperience(_ body: [String: JSONValue]) -> Endpoint<ExperienceResponse> {
        Endpoint(method: .post, path: "/api/user/experience", body: .object(body))
    }
    static func updateExperience(_ id: Int, _ body: [String: JSONValue]) -> Endpoint<ExperienceResponse> {
        Endpoint(method: .patch, path: "/api/user/experience/\(id)", body: .object(body))
    }
    static func deleteExperience(_ id: Int) -> Endpoint<Empty> { Endpoint(method: .delete, path: "/api/user/experience/\(id)") }

    static func educations() -> Endpoint<EducationsResponse> { Endpoint(path: "/api/user/education") }
    static func createEducation(_ body: [String: JSONValue]) -> Endpoint<EducationResponse> {
        Endpoint(method: .post, path: "/api/user/education", body: .object(body))
    }
    static func updateEducation(_ id: Int, _ body: [String: JSONValue]) -> Endpoint<EducationResponse> {
        Endpoint(method: .patch, path: "/api/user/education/\(id)", body: .object(body))
    }
    static func deleteEducation(_ id: Int) -> Endpoint<Empty> { Endpoint(method: .delete, path: "/api/user/education/\(id)") }

    static func membershipStatus() -> Endpoint<MembershipStatusResponse> { Endpoint(path: "/api/user/verification") }

    /// GET /api/colleges/search — plain fetch (no token) on the web.
    static func searchColleges(_ q: String) -> Endpoint<CollegeSearchResponse> {
        Endpoint(path: "/api/colleges/search", query: [("q", q)], authenticated: false)
    }
}

/// Option lists from welcome/page.tsx (they differ between Edit Profile and the Education modal).
enum ProfileOptions {
    static let employmentTypes = ["Full-time", "Part-time", "Internship", "Apprenticeship", "Contract", "Freelance", "Volunteer"]
    static let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
                         "November", "December"]
    /// Current year down to 1990.
    static var years: [String] {
        let current = Calendar.current.component(.year, from: .now)
        return (1990...current).reversed().map(String.init)
    }
    static let degreeLevels = ["Associate's", "Bachelor's", "Master's", "PhD / Doctorate", "Professional (MD / JD / MBA)", "Certificate"]
    static let schoolYears = ["Freshman", "Sophomore", "Junior", "Senior", "Graduate Student", "Alumni"]
    static let educationDegrees = ["Associate's", "Bachelor's", "Master's", "PhD", "MD", "JD", "MBA", "Other"]
    static let educationYears = ["Freshman", "Sophomore", "Junior", "Senior", "Graduate"]

    /// `parseMajors` — split on `/`, `,` or `|`, max 3.
    static func parseMajors(_ value: String?) -> [String] {
        (value ?? "")
            .components(separatedBy: CharacterSet(charactersIn: "/,|"))
            .map { $0.trimmed }
            .filter { !$0.isEmpty }
            .prefix(3)
            .map { $0 }
    }

    /// `serializeMajors`
    static func serializeMajors(_ majors: [String]) -> String {
        majors.map { $0.trimmed }.filter { !$0.isEmpty }.prefix(3).joined(separator: " / ")
    }
}
