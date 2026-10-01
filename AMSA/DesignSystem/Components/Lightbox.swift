import SwiftUI

/// Full-screen image viewer replacing the web lightboxes (`fixed inset-0 z-50 bg-black/80…`).
struct LightboxItem: Identifiable, Equatable {
    let id = UUID()
    let url: String
    var caption: String? = nil
    var captionLink: (label: String, url: String)? = nil
    var captionSuffix: String? = nil

    static func == (lhs: LightboxItem, rhs: LightboxItem) -> Bool { lhs.id == rhs.id }
}

struct LightboxView: View {
    let item: LightboxItem
    var backdropOpacity: Double = 0.85
    let onClose: () -> Void

    @Environment(ExternalLinkPresenter.self) private var links
    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.opacity(backdropOpacity).ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(spacing: 12) {
                RemoteImage(item.url) { phase in
                    if let image = phase.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: TW.radiusXl))
                            .scaleEffect(scale)
                            .gesture(MagnifyGesture()
                                .onChanged { scale = max(1, min(4, $0.magnification)) }
                                .onEnded { _ in withAnimation(.easeOut(duration: 0.2)) { scale = 1 } })
                    } else if phase.isFailure {
                        EmptyView()
                    } else {
                        ProgressView().tint(.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let caption = item.caption {
                    HStack(spacing: 0) {
                        Text(caption)
                        if let link = item.captionLink {
                            Button(link.label) { links.open(link.url) }
                                .underline()
                        }
                        if let suffix = item.captionSuffix { Text(suffix) }
                    }
                    .tw(.xs)
                    .foregroundStyle(Palette.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(16)

            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Icon("close", size: 20)
                            .foregroundStyle(Palette.gray800)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Palette.white))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
                Spacer()
            }
            .padding(16)
        }
    }
}

extension View {
    func lightbox(_ item: Binding<LightboxItem?>, backdropOpacity: Double = 0.85) -> some View {
        webModal(item: item, backdropOpacity: 0, padding: 0) { value in
            LightboxView(item: value, backdropOpacity: backdropOpacity) { item.wrappedValue = nil }
        }
    }
}
