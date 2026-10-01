import SwiftUI
import UIKit

/// Decoded-image memory cache. NSCache synchronizes internally.
final class ImageMemoryCache: @unchecked Sendable {
    static let shared = ImageMemoryCache()
    private let cache = NSCache<NSURL, UIImage>()

    init() { cache.totalCostLimit = 80 * 1024 * 1024 }

    func image(for url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }

    func insert(_ image: UIImage, for url: URL) {
        let pixels = image.size.width * image.size.height * image.scale * image.scale
        cache.setObject(image, forKey: url as NSURL, cost: Int(pixels * 4))
    }
}

/// Loads remote images once (de-duplicating concurrent requests); bytes are also kept
/// by URLCache on disk. Replaces `<img>`, including `onError` fallbacks via `.failure`.
actor ImagePipeline {
    static let shared = ImagePipeline()
    private var inFlight: [URL: Task<UIImage, Error>] = [:]

    nonisolated func cached(_ url: URL) -> UIImage? { ImageMemoryCache.shared.image(for: url) }

    func image(for url: URL) async throws -> UIImage {
        if let hit = ImageMemoryCache.shared.image(for: url) { return hit }
        if let task = inFlight[url] { return try await task.value }
        let task = Task<UIImage, Error> {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 200
            guard (200..<300).contains(status), let image = UIImage(data: data) else {
                throw URLError(.cannotDecodeContentData)
            }
            let prepared = await image.byPreparingForDisplay() ?? image
            ImageMemoryCache.shared.insert(prepared, for: url)
            return prepared
        }
        inFlight[url] = task
        defer { inFlight[url] = nil }
        return try await task.value
    }
}

enum RemoteImagePhase {
    case loading
    case success(UIImage)
    case failure
}

struct RemoteImage<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (RemoteImagePhase) -> Content

    @State private var phase: RemoteImagePhase

    init(url: URL?, @ViewBuilder content: @escaping (RemoteImagePhase) -> Content) {
        self.url = url
        self.content = content
        if let url, let hit = ImagePipeline.shared.cached(url) {
            _phase = State(initialValue: .success(hit))
        } else {
            _phase = State(initialValue: url == nil ? .failure : .loading)
        }
    }

    init(_ string: String?, @ViewBuilder content: @escaping (RemoteImagePhase) -> Content) {
        self.init(url: string.flatMap { $0.isEmpty ? nil : URL(string: $0) }, content: content)
    }

    var body: some View {
        content(phase)
            .task(id: url) {
                guard let url else { phase = .failure; return }
                if let hit = ImagePipeline.shared.cached(url) { phase = .success(hit); return }
                phase = .loading
                do {
                    phase = .success(try await ImagePipeline.shared.image(for: url))
                } catch is CancellationError {
                } catch {
                    phase = .failure
                }
            }
    }
}

extension RemoteImagePhase {
    var image: UIImage? {
        if case .success(let image) = self { return image }
        return nil
    }
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}
