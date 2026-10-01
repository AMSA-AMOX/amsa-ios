import Foundation

// Port of src/lib/social.ts
enum Social {
    enum Platform { case x, linkedin, instagram, facebook }

    /// `socialHref` — prepend https:// when missing.
    static func href(_ value: String) -> String {
        let v = value.trimmed
        if v.range(of: #"^https?://"#, options: [.regularExpression, .caseInsensitive]) != nil { return v }
        if v.hasPrefix("@") { return String(v.dropFirst()) } // bare handle isn't a valid URL on its own
        return "https://\(v)"
    }

    /// `socialHandle` — a readable handle from a stored link.
    static func handle(_ value: String?, platform: Platform) -> String {
        let fallback = switch platform {
        case .x: "X"
        case .linkedin: "LinkedIn"
        case .instagram: "Instagram"
        case .facebook: "Facebook"
        }
        guard let value else { return fallback }
        let raw = value.trimmed
        guard !raw.isEmpty else { return fallback }

        // Bare handle already (e.g. "@john" or "john.doe")
        if !raw.contains("/"), !raw.contains(".com"), !raw.contains("http") {
            let h = raw.hasPrefix("@") ? String(raw.dropFirst()) : raw
            return platform == .x || platform == .instagram ? "@\(h)" : h
        }

        let hasScheme = raw.range(of: #"^https?://"#, options: [.regularExpression, .caseInsensitive]) != nil
        let segments: [String]
        if let url = URL(string: hasScheme ? raw : "https://\(raw)"), url.host != nil {
            // `url.pathname` stays percent-encoded in JS.
            segments = url.path(percentEncoded: true).split(separator: "/").map(String.init)
        } else {
            segments = raw.split(separator: "/").map(String.init)
        }
        guard !segments.isEmpty else { return fallback }

        switch platform {
        case .linkedin:
            // LinkedIn: handle lives after /in/ or /company/
            if let idx = segments.firstIndex(where: { $0 == "in" || $0 == "company" || $0 == "pub" }), idx + 1 < segments.count {
                return segments[idx + 1]
            }
            return segments.last ?? fallback
        case .facebook:
            // Facebook: profile.php?id=... has no readable handle
            let first = segments[0]
            return first == "profile.php" ? fallback : first
        case .x, .instagram:
            let handle = segments[0].hasPrefix("@") ? String(segments[0].dropFirst()) : segments[0]
            return handle.isEmpty ? fallback : "@\(handle)"
        }
    }
}
