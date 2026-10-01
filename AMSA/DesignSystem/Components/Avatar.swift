import SwiftUI

/// The gold identity circle: `rounded-full bg-[#FFCA3A] text-[#001049] font-bold overflow-hidden`,
/// showing `profilePic` (object-cover) or uppercase initials.
struct Avatar: View {
    let imageURL: String?
    let initials: String
    var size: CGFloat
    var fontSize: TW.Size = .sm
    var background: Color = Palette.gold
    var foreground: Color = Palette.navy
    var fontWeight: TW.Weight = .bold

    var body: some View {
        ZStack {
            Circle().fill(background)
            if let imageURL, !imageURL.isEmpty {
                RemoteImage(imageURL) { phase in
                    if let image = phase.image {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        // A broken <img> shows nothing over the gold circle.
                        Color.clear
                    }
                }
            } else {
                Text(initials)
                    .tw(fontSize, fontWeight)
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
