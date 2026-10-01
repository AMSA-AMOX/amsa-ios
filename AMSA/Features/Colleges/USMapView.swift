import SwiftUI

/// Pre-projected state shapes (tools/gen-us-map.ts) as SwiftUI paths in the 975×610 viewBox.
enum USMapGeometry {
    struct State: Sendable {
        let abbr: String
        let path: Path
        let centroid: CGPoint?
    }

    static let size = CGSize(width: StaticData.usMap.width, height: StaticData.usMap.height)

    static let states: [State] = StaticData.usMap.states.map { shape in
        State(abbr: shape.abbr, path: parse(shape.d),
              centroid: shape.cx.flatMap { cx in shape.cy.map { CGPoint(x: cx, y: $0) } })
    }

    /// Parses d3-geo output (`M x,y L x,y … Z` only — asserted by the generator).
    static func parse(_ d: String) -> Path {
        var path = Path()
        var number = ""
        var numbers: [Double] = []
        var command: Character = "M"

        func flush() {
            if !number.isEmpty, let value = Double(number) { numbers.append(value) }
            number = ""
            while numbers.count >= 2 {
                let point = CGPoint(x: numbers[0], y: numbers[1])
                numbers.removeFirst(2)
                if command == "M" { path.move(to: point); command = "L" } else { path.addLine(to: point) }
            }
        }

        for ch in d {
            switch ch {
            case "M", "L":
                flush()
                command = ch
            case "Z":
                flush()
                path.closeSubpath()
            case ",":
                flush()
            case "-":
                // A minus sign starts a new number unless it follows an exponent marker.
                if !number.isEmpty, number.last != "e", number.last != "E" { flush() }
                number.append(ch)
            default:
                number.append(ch)
            }
        }
        flush()
        return path
    }
}

// Port of `USIntlDotMap` in src/app/(dashboard)/dashboard/research/page.tsx
struct USMapView: View {
    let colleges: [College]
    let selectedState: String?
    let onSelectState: (String?) -> Void

    @State private var hoveredState: String?
    /// Tooltip anchor in percent of the map box (the web's `mousePos`).
    @State private var tipPosition: CGPoint?

    private var collegesByState: [String: [College]] {
        var map: [String: [College]] = [:]
        for c in colleges where !c.state.isEmpty { map[c.stateAbbr, default: []].append(c) }
        return map
    }

    var body: some View {
        let byState = collegesByState
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Explore by State").tw(.base, .bold).foregroundStyle(Palette.navy)
                    Text(selectedState.map {
                        "Filtering to \(StaticData.stateName($0) ?? $0) — click again or press Clear to reset"
                    } ?? "Hover a state to preview schools · click to filter · \(byState.count) states tracked")
                        .tw(.sm)
                        .foregroundStyle(Palette.gray500)
                }
                Spacer(minLength: 0)
                if let selectedState {
                    Button { onSelectState(nil) } label: {
                        Text("Clear · \(StaticData.stateName(selectedState) ?? selectedState)")
                            .tw(.sm, .semibold)
                            .foregroundStyle(Palette.navy)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).fill(Palette.navy.opacity(0.05)))
                            .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).strokeBorder(Palette.navy.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                }
            }

            GeometryReader { proxy in
                let scale = proxy.size.width / USMapGeometry.size.width
                let box = proxy.size // alignment-guide closures are @Sendable; GeometryProxy is not
                ZStack(alignment: .topLeading) {
                    Canvas { context, _ in draw(context, scale: scale, byState: byState) }
                        .contentShape(Rectangle())
                        .gesture(SpatialTapGesture().onEnded { tap(at: $0.location, size: proxy.size, scale: scale, byState: byState) })
                    if let hoveredState, let tipPosition, let list = byState[hoveredState], !list.isEmpty {
                        tooltip(state: hoveredState, colleges: list)
                            .fixedSize()
                            .alignmentGuide(.leading) { d in d.width / 2 - box.width * tipPosition.x / 100 }
                            .alignmentGuide(.top) { d in
                                tipPosition.y > 65
                                    ? d.height + 12 - box.height * tipPosition.y / 100
                                    : -14 - box.height * tipPosition.y / 100
                            }
                            .allowsHitTesting(false)
                    }
                }
            }
            .aspectRatio(USMapGeometry.size.width / USMapGeometry.size.height, contentMode: .fit)
            .background(Palette.mapBackground)
            .clipShape(RoundedRectangle(cornerRadius: TW.radiusXl))
            .overlay(RoundedRectangle(cornerRadius: TW.radiusXl).strokeBorder(Palette.gray100, lineWidth: 1))
        }
        .padding(16)
        .twBox(background: Palette.white, radius: TW.radius2xl, border: Palette.gray300, borderWidth: 2)
    }

    // MARK: Drawing

    private static let navy = (r: 0.0, g: 16.0 / 255, b: 73.0 / 255)
    private static func navy(_ a: Double) -> Color { Color(.sRGB, red: navy.r, green: navy.g, blue: navy.b, opacity: a) }
    private static func indigo(_ a: Double) -> Color { Color(.sRGB, red: 31 / 255, green: 42 / 255, blue: 125 / 255, opacity: a) }

    private func fill(abbr: String, has: Bool) -> Color {
        if abbr == selectedState { return Self.navy(0.28) }
        if abbr == hoveredState { return Self.navy(0.16) }
        return has ? Self.navy(0.09) : Self.indigo(0.04)
    }

    private func draw(_ context: GraphicsContext, scale: CGFloat, byState: [String: [College]]) {
        var ctx = context
        ctx.scaleBy(x: scale, y: scale)
        for state in USMapGeometry.states where state.abbr != "DC" {
            let has = byState[state.abbr] != nil
            let selected = state.abbr == selectedState
            ctx.fill(state.path, with: .color(fill(abbr: state.abbr, has: has)))
            ctx.stroke(state.path, with: .color(selected ? Self.navy(0.5) : Self.indigo(0.22)), lineWidth: selected ? 1.2 : 0.7)
        }
        for state in USMapGeometry.states where state.abbr != "DC" {
            guard let c = state.centroid else { continue }
            let has = byState[state.abbr] != nil
            let alpha = state.abbr == selectedState ? 0.75 : (has ? 0.45 : 0.18)
            label(ctx, state.abbr, at: CGPoint(x: c.x, y: c.y + 4), weight: has ? .semibold : .regular, color: Self.navy(alpha))
        }
        // DC — too small to click in place, so pull it out as a labeled callout
        if let dc = USMapGeometry.states.first(where: { $0.abbr == "DC" }), let c = dc.centroid {
            let has = byState["DC"] != nil
            let selected = selectedState == "DC"
            let box = dcBox(centroidY: c.y)
            var line = Path()
            line.move(to: c)
            line.addLine(to: CGPoint(x: box.minX, y: box.midY))
            ctx.stroke(line, with: .color(Self.navy(0.35)), lineWidth: 0.7)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 2.2, y: c.y - 2.2, width: 4.4, height: 4.4)),
                     with: .color(has ? Self.navy(0.55) : Self.navy(0.25)))
            let rect = Path(roundedRect: box, cornerRadius: 5)
            ctx.fill(rect, with: .color(fill(abbr: "DC", has: has)))
            ctx.stroke(rect, with: .color(selected ? Self.navy(0.5) : Self.indigo(0.3)), lineWidth: selected ? 1.2 : 0.7)
            label(ctx, "DC", at: CGPoint(x: box.midX, y: box.midY + 3.5), weight: has ? .semibold : .regular,
                  color: selected ? Self.navy(0.75) : (has ? Self.navy(0.55) : Self.navy(0.25)))
        }
    }

    /// SVG `<text text-anchor="middle" y=baseline font-size=10 font-family=sans-serif>` — iOS Safari's
    /// `sans-serif` is Helvetica; weight 600 resolves to its Bold face.
    private func label(_ ctx: GraphicsContext, _ text: String, at baseline: CGPoint, weight: Font.Weight, color: Color) {
        let font = Font.custom(weight == .semibold ? "Helvetica-Bold" : "Helvetica", fixedSize: 10)
        let resolved = ctx.resolve(Text(text).font(font).foregroundColor(color))
        ctx.draw(resolved, at: baseline, anchor: UnitPoint(x: 0.5, y: 0.77))
    }

    private func dcBox(centroidY: CGFloat) -> CGRect {
        let w: CGFloat = 34, h: CGFloat = 20
        let cx = USMapGeometry.size.width - 22
        return CGRect(x: cx - w / 2, y: centroidY - h / 2, width: w, height: h)
    }

    // MARK: Interaction (a tap on iOS Safari = hover + click)

    private func tap(at location: CGPoint, size: CGSize, scale: CGFloat, byState: [String: [College]]) {
        let point = CGPoint(x: location.x / scale, y: location.y / scale)
        var hit: String?
        if let dc = USMapGeometry.states.first(where: { $0.abbr == "DC" }), let c = dc.centroid, dcBox(centroidY: c.y).contains(point) {
            hit = "DC"
        } else {
            hit = USMapGeometry.states.first { $0.abbr != "DC" && $0.path.contains(point) }?.abbr
        }
        guard let abbr = hit, byState[abbr] != nil else {
            hoveredState = nil
            tipPosition = nil
            return
        }
        hoveredState = abbr
        tipPosition = CGPoint(x: location.x / size.width * 100, y: location.y / size.height * 100)
        onSelectState(abbr == selectedState ? nil : abbr)
    }

    private func tooltip(state: String, colleges: [College]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            (Text(StaticData.stateName(state) ?? state).foregroundColor(Palette.navy)
                + Text(" · \(colleges.count) school\(colleges.count == 1 ? "" : "s")")
                .font(.custom(TW.Weight.normal.fontName, fixedSize: 11)).foregroundColor(Palette.gray400))
                .tw(.px(11), .semibold)
                .padding(.bottom, 6)
            HStack(spacing: 4) {
                ForEach(colleges.prefix(5)) { college in
                    Group {
                        if let logo = college.logoUrl {
                            RemoteImage(logo) { phase in
                                if let image = phase.image { Image(uiImage: image).resizable().scaledToFill() } else { Palette.white }
                            }
                            .background(Palette.white)
                            .overlay(Circle().strokeBorder(Palette.gray100, lineWidth: 1))
                        } else {
                            Text(String(college.name.prefix(1)))
                                .font(.custom(TW.Weight.bold.fontName, fixedSize: 8))
                                .foregroundStyle(Palette.navy)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Palette.navy.opacity(0.1))
                                .overlay(Circle().strokeBorder(Palette.navy.opacity(0.15), lineWidth: 1))
                        }
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                }
                if colleges.count > 5 {
                    Text("+\(colleges.count - 5)").tw(.px(10), .bold).foregroundStyle(Palette.navy).padding(.leading, 2)
                }
            }
            Text("Click to filter").tw(.px(10)).foregroundStyle(Palette.gray400).padding(.top, 6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minWidth: 160, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: TW.radius2xl).fill(Palette.white))
        .overlay(RoundedRectangle(cornerRadius: TW.radius2xl).strokeBorder(Palette.gray200, lineWidth: 1))
        .twShadow(.xl)
    }
}
