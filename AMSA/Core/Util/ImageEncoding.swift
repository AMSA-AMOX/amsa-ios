import UIKit

/// Converts picked images into the bytes the web would upload.
enum ImageEncoding {
    /// Avatar: welcome/page.tsx downsizes on a canvas to a 400px longest side, JPEG 0.8.
    static func avatarJPEG(_ image: UIImage) -> Data? {
        resized(image, maxDimension: 400).jpegData(compressionQuality: 0.8)
    }

    /// Composer images: JPEG q0.85, ≤2048px longest side (iOS photos are HEIC; browsers hand the
    /// server JPEG from `<input type=file accept="image/*">`).
    static func uploadJPEG(_ image: UIImage) -> Data? {
        resized(image, maxDimension: 2048).jpegData(compressionQuality: 0.85)
    }

    static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return normalized(image) }
        let scale = maxDimension / longest
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Bakes EXIF orientation into the pixels.
    private static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}

/// A picked image ready to preview and upload.
struct PickedImage: Identifiable, Equatable {
    let id = UUID()
    let image: UIImage
    let data: Data

    var byteCount: Int { data.count }

    static func == (lhs: PickedImage, rhs: PickedImage) -> Bool { lhs.id == rhs.id }
}
