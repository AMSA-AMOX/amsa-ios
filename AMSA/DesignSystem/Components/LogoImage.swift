import SwiftUI

// Port of src/components/LogoImage.tsx
/// Tries each candidate domain on logo.dev (with `fallback=404`) and advances on error;
/// when none remain, shows the navy-tint box with a cap (school) or building (company) icon.
struct LogoImage: View {
    var domain: String? = nil
    var name: String? = nil
    var email: String? = nil
    var location: String? = nil
    let kind: LogoLookup.Kind
    /// Tailwind spacing unit: size 10 → 40px box.
    var size: CGFloat = 10
    var radius: CGFloat = TW.radiusLg
    /// When set, tapping opens this route (e.g. a school logo → its college page).
    var onTap: (() -> Void)? = nil

    @State private var attempt = 0

    private var candidates: [String] {
        LogoLookup.candidates(domain: domain, name: name, email: email, location: location, kind: kind)
    }

    var body: some View {
        let box = size * 4
        let list = candidates
        let resolved = attempt < list.count ? list[attempt] : nil
        let shape = RoundedRectangle(cornerRadius: radius)
        Group {
            if let resolved, let url = LogoLookup.logoURL(domain: resolved, token: AppConfig.current.logoDevToken) {
                RemoteImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        Image(uiImage: image).resizable().scaledToFit()
                    case .loading:
                        Color.clear
                    case .failure:
                        Color.clear.onAppear { attempt += 1 }
                    }
                }
                .id(resolved)
                .frame(width: box, height: box)
                .background(shape.fill(Palette.white))
                .overlay(shape.strokeBorder(Palette.gray100, lineWidth: 1))
                .clipShape(shape)
            } else {
                ZStack {
                    shape.fill(Palette.navy.opacity(0.1))
                    Icon(kind == .school ? "logo-school" : "logo-company", size: max(10, size * 2))
                        .foregroundStyle(Palette.navy)
                }
                .frame(width: box, height: box)
            }
        }
        .onChange(of: list) { _, _ in attempt = 0 }
        .contentShape(shape)
        .onTapGesture { onTap?() }
        .allowsHitTesting(onTap != nil)
    }
}

// Port of src/components/threads/SchoolBadge.tsx
struct SchoolBadge: View {
    enum Size { case sm, md }
    let category: String?
    let categoryDomain: String?
    var size: Size = .sm

    var body: some View {
        let isGeneral = (category ?? "").isEmpty || category?.lowercased() == "general"
        let iconSize: CGFloat = size == .md ? 16 : 12
        let logoURL = !isGeneral ? categoryDomain.flatMap {
            LogoLookup.badgeURL(domain: $0, token: AppConfig.current.logoDevToken)
        } : nil
        HStack(spacing: 6) {
            if isGeneral {
                Icon("globe", size: iconSize)
            } else if let logoURL {
                RemoteImage(url: logoURL) { phase in
                    if let image = phase.image {
                        Image(uiImage: image).resizable().scaledToFit()
                            .frame(width: iconSize, height: iconSize)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    } else if !phase.isFailure {
                        Color.clear.frame(width: iconSize, height: iconSize)
                    }
                    // onError → display:none (removes the icon and its gap)
                }
            }
            Text(isGeneral ? "General" : (category ?? ""))
                .tw(size == .md ? .xs : .px(10), .semibold)
                .lineLimit(1)
        }
        .foregroundStyle(Palette.gray700)
        .padding(.horizontal, size == .md ? 10 : 8)
        .padding(.vertical, size == .md ? 4 : 2)
        .background(Capsule().fill(Palette.gray100))
    }
}
