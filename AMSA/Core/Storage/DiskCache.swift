import Foundation

/// A file in the Caches directory with its write time — used for the 3.2 MB
/// `/api/colleges` catalog (web: sessionStorage `research_colleges_cache_v7`).
struct DiskCache: Sendable {
    let fileName: String

    private var url: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: fileName)
    }

    func read() -> (data: Data, savedAt: Date)? {
        guard let data = try? Data(contentsOf: url),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path()),
              let modified = attributes[.modificationDate] as? Date
        else { return nil }
        return (data, modified)
    }

    func write(_ data: Data) {
        try? data.write(to: url, options: .atomic)
    }

    func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
