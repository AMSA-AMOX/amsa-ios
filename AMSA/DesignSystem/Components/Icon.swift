import SwiftUI

/// An inline web `<svg>` icon copied verbatim into Assets.xcassets/Icons (tools/gen-icons.mjs).
/// Renders as a template so it takes the current foreground color (`currentColor`).
struct Icon: View {
    let name: String
    var size: CGFloat = 20

    init(_ name: String, size: CGFloat = 20) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image("Icons/\(name)")
            .resizable()
            .renderingMode(.template)
            .interpolation(.high)
            .aspectRatio(contentMode: .fit) // SVG default `preserveAspectRatio="xMidYMid meet"`
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// The web's inline loading spinner, drawn from its SVG (`viewBox="0 0 24 24"`): a `currentColor`
/// ring (`r=10`, `stroke-width=4`, `opacity-25`) under a quarter wedge (`M4 12a8 8 0 018-8v8H4z`,
/// `opacity-75`), rotating with `animate-spin` (1s linear, infinite).
struct Spinner: View {
    var size: CGFloat = 16
    @State private var spinning = false

    var body: some View {
        Canvas { context, canvas in
            let s = canvas.width / 24
            context.stroke(Path(ellipseIn: CGRect(x: 2 * s, y: 2 * s, width: 20 * s, height: 20 * s)),
                           with: .foreground, style: StrokeStyle(lineWidth: 4 * s))
        }
        .opacity(0.25)
        .overlay {
            Canvas { context, canvas in
                let s = canvas.width / 24
                var wedge = Path()
                wedge.move(to: CGPoint(x: 4 * s, y: 12 * s))
                // SVG arc `a8 8 0 0 1 8 -8`: quarter circle centred at (12,12) from (4,12) to (12,4), clockwise.
                wedge.addArc(center: CGPoint(x: 12 * s, y: 12 * s), radius: 8 * s,
                             startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
                wedge.addLine(to: CGPoint(x: 12 * s, y: 12 * s))
                wedge.closeSubpath()
                context.fill(wedge, with: .foreground)
            }
            .opacity(0.75)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(spinning ? 360 : 0))
        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: spinning)
        .onAppear { spinning = true }
        .accessibilityLabel("Loading")
    }
}
