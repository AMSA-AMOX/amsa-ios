import SwiftUI
import UIKit

/// Tailwind v4 type scale on Urbanist. The web loads only weights 400/500/600, so
/// `font-bold`/`font-extrabold`/`font-black` render with the 600 face and
/// `font-light` with 400 — mirrored here.
enum TW {
    enum Weight {
        case light, normal, medium, semibold, bold, extrabold, black

        var fontName: String {
            switch self {
            case .light, .normal: "UrbanistRoman-Regular"
            case .medium: "UrbanistRoman-Medium"
            case .semibold, .bold, .extrabold, .black: "UrbanistRoman-SemiBold"
            }
        }
    }

    /// Font size + line height (px) — `--text-*` and `--text-*--line-height`.
    struct Size: Sendable {
        let px: CGFloat
        let lineHeight: CGFloat

        static let xs = Size(px: 12, lineHeight: 16)
        static let sm = Size(px: 14, lineHeight: 20)
        static let base = Size(px: 16, lineHeight: 24)
        static let lg = Size(px: 18, lineHeight: 28)
        static let xl = Size(px: 20, lineHeight: 28)
        static let x2l = Size(px: 24, lineHeight: 32)
        static let x3l = Size(px: 30, lineHeight: 36)
        /// `text-md` is not a Tailwind v4 utility: it sets nothing, so text inherits
        /// the parent's 16px / 1.5 (body defaults).
        static let md = Size(px: 16, lineHeight: 24)

        /// Arbitrary `text-[Npx]`: size only; line height inherits (body `line-height: 1.5`).
        static func px(_ px: CGFloat, lineHeight: CGFloat? = nil) -> Size {
            Size(px: px, lineHeight: lineHeight ?? px * 1.5)
        }
    }

    enum Leading {
        /// `leading-none`. Not named `none`: on an optional parameter `.none` would mean nil.
        case leadingNone
        case tight, snug, normal, relaxed, loose
        var multiplier: CGFloat {
            switch self {
            case .leadingNone: 1
            case .tight: 1.25
            case .snug: 1.375
            case .normal: 1.5
            case .relaxed: 1.625
            case .loose: 2
            }
        }
    }

    enum Tracking {
        case tight, normal, wide, wider, widest
        var em: CGFloat {
            switch self {
            case .tight: -0.025
            case .normal: 0
            case .wide: 0.025
            case .wider: 0.05
            case .widest: 0.1
            }
        }
    }

    /// Urbanist's hhea metrics (ascent 1900, descent 500, upm 2000): natural line = 1.2em.
    static let naturalLineHeight: CGFloat = 1.2
    /// Urbanist's space / no-break-space advance (hmtx 480 of 2000 upm, all three faces).
    static let spaceAdvanceEm: CGFloat = 0.24

    // Radii (`--radius-*`)
    static let radiusSm: CGFloat = 4
    static let radiusMd: CGFloat = 6
    static let radiusLg: CGFloat = 8
    static let radiusXl: CGFloat = 12
    static let radius2xl: CGFloat = 16
    static let radius3xl: CGFloat = 24
    /// `.dashboard button { border-radius: 0.25rem }` — overrides every button's class radius.
    static let dashboardButtonRadius: CGFloat = 4
}

private struct TWTextModifier: ViewModifier {
    let size: TW.Size
    let weight: TW.Weight
    let leading: TW.Leading?
    let tracking: TW.Tracking?
    let monospaced: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let scale = Self.scale(for: size.px, dynamicTypeSize)
        let px = size.px * scale
        let lineHeight = (leading.map { $0.multiplier * size.px } ?? size.lineHeight) * scale
        // CSS centers the glyph box in the line box: half-leading above and below each line.
        let extra = lineHeight - px * TW.naturalLineHeight
        let font: Font = monospaced
            ? .system(size: px, weight: .regular, design: .monospaced)
            : .custom(weight.fontName, fixedSize: px)
        content
            .font(font)
            .tracking((tracking?.em ?? 0) * px)
            .lineSpacing(max(0, extra))
            .padding(.vertical, extra / 2)
    }

    /// Scales with Dynamic Type like `Font.custom(_:size:relativeTo:)`; identical at the default size.
    static func scale(for px: CGFloat, _ dts: DynamicTypeSize) -> CGFloat {
        let style: UIFont.TextStyle = switch px {
        case ..<13: .caption1
        case ..<15: .footnote
        case ..<17: .body
        case ..<21: .title3
        case ..<25: .title2
        default: .title1
        }
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dts))
        return UIFontMetrics(forTextStyle: style).scaledValue(for: 100, compatibleWith: traits) / 100
    }
}

extension View {
    /// Tailwind text utilities, e.g. `.tw(.sm, .semibold)` for `text-sm font-semibold`.
    func tw(_ size: TW.Size, _ weight: TW.Weight = .normal, leading: TW.Leading? = nil,
            tracking: TW.Tracking? = nil) -> some View {
        modifier(TWTextModifier(size: size, weight: weight, leading: leading, tracking: tracking, monospaced: false))
    }

    /// `font-mono` (SF Mono stands in for the browser's monospace font).
    func twMono(_ size: TW.Size) -> some View {
        modifier(TWTextModifier(size: size, weight: .normal, leading: nil, tracking: nil, monospaced: true))
    }
}

extension Text {
    /// An unbreakable inline gap of `width` pt — CSS `ml-*` on an inline `<span>` that starts
    /// with no whitespace. `px` is the span's font size.
    static func inlineGap(_ width: CGFloat, fontSize px: CGFloat) -> Text {
        Text("\u{00A0}")
            .font(.custom(TW.Weight.normal.fontName, fixedSize: px))
            .tracking(width - TW.spaceAdvanceEm * px)
    }
}

extension UIContentSizeCategory {
    init(_ dts: DynamicTypeSize) {
        self = switch dts {
        case .xSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .xLarge: .extraLarge
        case .xxLarge: .extraExtraLarge
        case .xxxLarge: .extraExtraExtraLarge
        case .accessibility1: .accessibilityMedium
        case .accessibility2: .accessibilityLarge
        case .accessibility3: .accessibilityExtraLarge
        case .accessibility4: .accessibilityExtraExtraLarge
        case .accessibility5: .accessibilityExtraExtraExtraLarge
        @unknown default: .large
        }
    }
}
