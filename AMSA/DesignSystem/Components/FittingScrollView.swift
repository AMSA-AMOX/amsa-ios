import PhotosUI
import SwiftUI

/// `flex-1 min-h-0 overflow-y-auto` inside a `max-h-[90vh]` panel: as tall as its content,
/// shrinking (and scrolling) only when the panel runs out of room.
struct FittingScrollView<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var contentHeight: CGFloat = 1

    var body: some View {
        ScrollView {
            content
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = max(1, $0) }
        }
        .frame(maxHeight: contentHeight)
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// `<input type="file" accept="image/*">` → PhotosPicker, delivering upload-ready JPEG bytes.
struct ImagePickerButton<Label: View>: View {
    var disabled: Bool = false
    let onPick: (PickedImage) -> Void
    @ViewBuilder let label: Label

    @State private var item: PhotosPickerItem?
    @State private var presented = false

    var body: some View {
        // The modifier form keeps `label` out of PhotosPicker's Sendable label closure.
        Button { presented = true } label: { label }
            .buttonStyle(.plain)
            .disabled(disabled)
            .photosPicker(isPresented: $presented, selection: $item, matching: .images, photoLibrary: .shared())
            .onChange(of: item) { _, newItem in
                guard let newItem else { return }
                Task {
                    defer { item = nil }
                    guard let data = try? await newItem.loadTransferable(type: Data.self),
                          let image = UIImage(data: data),
                          let jpeg = ImageEncoding.uploadJPEG(image)
                    else { return }
                    onPick(PickedImage(image: image, data: jpeg))
                }
            }
    }
}
