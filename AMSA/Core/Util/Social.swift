import Foundation

// Port of src/lib/social.ts
enum Social {
    enum Platform { case x, linkedin, instagram, facebook }

    /// `socialHref` — prepend https:// when missing. Unlike the web, whose link for a bare handle
    /// goes nowhere, a handle ("@john", "john.doe") becomes the platform's profile link.
    static func href(_ value: String, platform: Platform) -> String {
        let v = value.trimmed
        if v.range(of: #"^https?://"#, options: [.regularExpression, .caseInsensitive]) != nil { return v }
        if isBareHandle(v) {
            let handle = v.hasPrefix("@") ? String(v.dropFirst()) : v
            let base = switch platform {
            case .x: "https://x.com/"
            case .linkedin: "https://www.linkedin.com/in/"
            case .instagram: "https://www.instagram.com/"
            case .facebook: "https://www.facebook.com/"
            }
            return base + (handle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? handle)
        }
        return "https://\(v)"
    }

    /// "@john" or "john.doe" rather than a link.
    private static func isBareHandle(_ raw: String) -> Bool {
        !raw.contains("/") && !raw.contains(".com") && !raw.contains("http")
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
        if isBareHandle(raw) {
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
