import SwiftUI

/// `flex flex-wrap gap-x gap-y` — lays children left to right, wrapping lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat? = nil
    var alignment: HorizontalAlignment = .leading

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * (lineSpacing ?? spacing)
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(width: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            if alignment == .center { x += (bounds.width - row.width) / 2 }
            if alignment == .trailing { x += bounds.width - row.width }
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + (lineSpacing ?? spacing)
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}

/// Gray skeleton block used for `animate-pulse` placeholders.
struct SkeletonBlock: View {
    var color: Color = Palette.gray100
    var radius: CGFloat = TW.radiusSm
    var width: CGFloat? = nil
    var height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(color)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

/// `w-1/3`-style widths: the child gets `fraction` of the proposed width.
struct FractionalWidth: Layout {
    let fraction: CGFloat
    /// `mx-auto`
    var centered = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = (proposal.width ?? 0) * fraction
        let height = subviews.first?.sizeThatFits(ProposedViewSize(width: width, height: proposal.height)).height ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width * fraction
        let x = bounds.minX + (centered ? (bounds.width - width) / 2 : 0)
        subviews.first?.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: width, height: bounds.height))
    }
}

/// A skeleton bar `h-N bg-gray-100 rounded w-a/b`.
struct SkeletonBar: View {
    var fraction: CGFloat = 1
    let height: CGFloat
    var color: Color = Palette.gray100
    var radius: CGFloat = TW.radiusSm
    var centered = false

    var body: some View {
        FractionalWidth(fraction: fraction, centered: centered) {
            RoundedRectangle(cornerRadius: radius).fill(color).frame(height: height)
        }
    }
}
