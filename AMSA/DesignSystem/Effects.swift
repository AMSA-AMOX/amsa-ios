import SwiftUI

/// Tailwind v4 `--shadow-*` values. CSS blur B ≈ SwiftUI radius B/2; negative spread
/// has no SwiftUI equivalent and is approximated by the offset alone.
enum TWShadow {
    case sm, md, lg, xl, x2l

    fileprivate var layers: [(y: CGFloat, blur: CGFloat, opacity: Double)] {
        switch self {
        case .sm: [(1, 3, 0.1), (1, 2, 0.1)]
        case .md: [(4, 6, 0.1), (2, 4, 0.1)]
        case .lg: [(10, 15, 0.1), (4, 6, 0.1)]
        case .xl: [(20, 25, 0.1), (8, 10, 0.1)]
        case .x2l: [(25, 50, 0.25)]
        }
    }
}

extension View {
    func twShadow(_ shadow: TWShadow) -> some View {
        let layers = shadow.layers
        return self
            .shadow(color: .black.opacity(layers[0].opacity), radius: layers[0].blur / 2, x: 0, y: layers[0].y)
            .shadow(color: .black.opacity(layers.count > 1 ? layers[1].opacity : 0),
                    radius: (layers.count > 1 ? layers[1].blur : 0) / 2, x: 0, y: layers.count > 1 ? layers[1].y : 0)
    }

    /// `rounded-* border-N border-color bg-color` in one call. Borders draw inside the box (CSS border-box).
    func twBox(background: Color? = nil, radius: CGFloat = 0, border: Color? = nil, borderWidth: CGFloat = 1) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .circular)
        return self
            .background { if let background { shape.fill(background) } }
            .overlay { if let border { shape.strokeBorder(border, lineWidth: borderWidth) } }
            .clipShape(shape)
    }

    /// `animate-pulse`: opacity 1 → 0.5 → 1 over 2s, cubic-bezier(0.4, 0, 0.6, 1).
    func twPulse() -> some View { modifier(PulseModifier()) }

    /// A 2px (or custom) horizontal rule at the bottom, e.g. `border-b-2 border-gray-300`.
    func bottomBorder(_ color: Color = Palette.gray300, width: CGFloat = 2) -> some View {
        overlay(alignment: .bottom) { color.frame(height: width) }
    }

    func topBorder(_ color: Color = Palette.gray300, width: CGFloat = 2) -> some View {
        overlay(alignment: .top) { color.frame(height: width) }
    }
}

private struct PulseModifier: ViewModifier {
    @State private var dimmed = false
    func body(content: Content) -> some View {
        content
            .opacity(dimmed ? 0.5 : 1)
            .onAppear {
                withAnimation(.timingCurve(0.4, 0, 0.6, 1, duration: 1).repeatForever(autoreverses: true)) {
                    dimmed = true
                }
            }
    }
}

/// `divide-y-N divide-color` separator between rows.
struct TWDivider: View {
    var color: Color = Palette.gray300
    var width: CGFloat = 2
    var body: some View { color.frame(height: width) }
}
