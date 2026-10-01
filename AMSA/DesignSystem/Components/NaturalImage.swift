import SwiftUI

/// Sizes a child to an image's natural pixel size (CSS px), scaled down — never up — to fit
/// the proposed width and `maxHeight`: `<img class="max-h-150 max-w-full w-auto h-auto">`.
struct NaturalFit: Layout {
    let pixelSize: CGSize
    var maxHeight: CGFloat = .infinity

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        fitted(width: proposal.width)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let size = fitted(width: bounds.width)
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(size))
    }

    private func fitted(width: CGFloat?) -> CGSize {
        guard pixelSize.width > 0, pixelSize.height > 0 else { return .zero }
        let maxWidth = width ?? pixelSize.width
        let scale = min(1, maxWidth / pixelSize.width, maxHeight / pixelSize.height)
        return CGSize(width: (pixelSize.width * scale).rounded(.down), height: (pixelSize.height * scale).rounded(.down))
    }
}

/// A remote `<img>` rendered at its natural size (0×0 until loaded, like the browser).
struct NaturalRemoteImage: View {
    let url: String
    var maxHeight: CGFloat = .infinity
    var radius: CGFloat = 0

    var body: some View {
        RemoteImage(url) { phase in
            if let image = phase.image {
                NaturalFit(pixelSize: CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale),
                           maxHeight: maxHeight) {
                    Image(uiImage: image).resizable().clipShape(RoundedRectangle(cornerRadius: radius))
                }
            }
        }
    }
}

/// `grid grid-cols-N gap-2` of top-left aligned cells.
struct ImageGrid<Cell: View>: View {
    let count: Int
    let columns: Int
    var spacing: CGFloat = 8
    @ViewBuilder let cell: (Int) -> Cell

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(stride(from: 0, to: count, by: columns)), id: \.self) { rowStart in
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { offset in
                        let index = rowStart + offset
                        Group {
                            if index < count { cell(index) } else { Color.clear.frame(height: 0) }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
        }
    }
}
