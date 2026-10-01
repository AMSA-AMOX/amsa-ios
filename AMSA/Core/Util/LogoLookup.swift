import Foundation

/// Port of src/lib/logo-lookup.ts and the URL builders in LogoImage.tsx / SchoolBadge.tsx.
enum LogoLookup {
    enum Kind { case school, company }

    /// LogoImage.buildLogoUrl — asks logo.dev for a 404 instead of a generated monogram:
    /// `https://img.logo.dev/${domain}?${new URLSearchParams({ fallback: "404", token })}`.
    static func logoURL(domain: String, token: String) -> URL? {
        var query = "fallback=404"
        if !token.isEmpty {
            let encoded = token.addingPercentEncoding(withAllowedCharacters: .formURLEncoded) ?? token
            query += "&token=" + encoded.replacingOccurrences(of: "%20", with: "+")
        }
        return URL(string: "https://img.logo.dev/\(domain)?\(query)")
    }

    /// SchoolBadge / threads tabs: `https://img.logo.dev/{domain}?token=…` (no 404 fallback).
    static func badgeURL(domain: String, token: String) -> URL? {
        let base = "https://img.logo.dev/\(domain)"
        guard !token.isEmpty else { return URL(string: base) }
        let encoded = token.addingPercentEncoding(withAllowedCharacters: .jsURIComponent) ?? token
        return URL(string: "\(base)?token=\(encoded)")
    }

    /// `logoDomainCandidates`
    static func candidates(domain: String?, name: String?, email: String?, location: String?, kind: Kind) -> [String] {
        if let domain, !domain.isEmpty { return [domain] }
        if kind == .school {
            let d = extractSchoolEmailDomain(email) ?? name.flatMap(knownSchoolDomain)
            return d.map { [$0] } ?? []
        }
        return employerDomainCandidates(name: name, location: location)
    }

    /// `normalizeEntityName`
    static func normalize(_ value: String) -> String {
        var s = value.lowercased().replacingOccurrences(of: "&", with: " and ")
        s = s.replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `extractSchoolEmailDomain` — collapses `terpmail.umd.edu` to `umd.edu`.
    static func extractSchoolEmailDomain(_ email: String?) -> String? {
        guard let email, let at = email.firstIndex(of: "@") else { return nil }
        let domain = email[email.index(after: at)...].lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = domain.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2 else { return nil }
        if parts[parts.count - 1] == "edu" { return "\(parts[parts.count - 2]).edu" }
        return domain
    }

    /// `getKnownSchoolDomain` — exact alias match, then prefix match either way.
    static func knownSchoolDomain(_ name: String) -> String? {
        guard !name.trimmed.isEmpty else { return nil }
        let normalized = normalize(name)
        if let exact = schoolAliases.first(where: { $0.0 == normalized }) { return exact.1 }
        for (key, domain) in schoolAliases where normalized.hasPrefix(key) || key.hasPrefix(normalized) {
            return domain
        }
        return nil
    }

    /// `getKnownEmployerDomain` — whole-word alias matches only.
    static func knownEmployerDomain(_ name: String?) -> String? {
        let normalized = normalize(name ?? "")
        guard !normalized.isEmpty else { return nil }
        if let company = companyAliases.first(where: { $0.0 == normalized }) { return company.1 }
        if let school = schoolAliases.first(where: { $0.0 == normalized }) { return school.1 }
        for (key, domain) in schoolAliases where normalized.hasPrefix("\(key) ") { return domain }
        return nil
    }

    /// `employerDomainCandidates`
    static func employerDomainCandidates(name: String?, location: String?) -> [String] {
        var out: [String] = []
        func push(_ d: String?) { if let d, !out.contains(d) { out.append(d) } }

        // Keep the part before a separator: "FoundationBio | CURB", "Acme (Intern)"
        let raw = name ?? ""
        let head: String
        if let range = raw.range(of: #"\s+[|/–—-]\s+|\s*\("#, options: .regularExpression) {
            head = String(raw[..<range.lowerBound])
        } else {
            head = raw
        }
        push(knownEmployerDomain(head))

        var core = normalize(head)
        var previous = ""
        while previous != core {
            previous = core
            core = core.replacingOccurrences(of: corporateSuffix, with: "", options: .regularExpression)
        }
        let slug = core.replacingOccurrences(of: #"\s"#, with: "", options: .regularExpression)
        guard !slug.isEmpty else { return out }

        if core.range(of: schoolWord, options: .regularExpression) != nil { push("\(slug).edu") }
        let isMongolia = (location ?? "").range(of: mongolia, options: [.regularExpression, .caseInsensitive]) != nil
        for tld in isMongolia ? ["mn", "com"] : ["com", "mn"] { push("\(slug).\(tld)") }
        return out
    }

    private static let corporateSuffix =
        #"\s+(llc|l l c|inc|incorporated|corp|corporation|co|company|ltd|limited|llp|plc|gmbh)$"#
    private static let schoolWord = #"\b(university|college|institute|school|academy|polytechnic|state)\b"#
    private static let mongolia = "mongolia|ulaanbaatar|улаанбаатар|монгол"

    private static let schoolAliases: [(String, String)] = StaticData.logoAliases.schools.compactMap {
        $0.count == 2 ? ($0[0], $0[1]) : nil
    }
    private static let companyAliases: [(String, String)] = StaticData.logoAliases.companies.compactMap {
        $0.count == 2 ? ($0[0], $0[1]) : nil
    }
}

extension CharacterSet {
    /// Characters `encodeURIComponent` leaves unescaped.
    static let jsURIComponent: CharacterSet = {
        var set = CharacterSet.alphanumerics.intersection(CharacterSet(charactersIn: Unicode.Scalar(0)..<Unicode.Scalar(128)))
        set.insert(charactersIn: "-_.!~*'()")
        return set
    }()

    /// Characters `URLSearchParams` serialisation leaves unescaped (it writes a space as `+`).
    static let formURLEncoded: CharacterSet = {
        var set = CharacterSet.alphanumerics.intersection(CharacterSet(charactersIn: Unicode.Scalar(0)..<Unicode.Scalar(128)))
        set.insert(charactersIn: "*-._")
        return set
    }()
}
