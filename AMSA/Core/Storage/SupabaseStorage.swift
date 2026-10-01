import Foundation

/// Uploads images straight to Supabase Storage with the public anon key, exactly as
/// the web composers do (`supabase.storage.from(bucket).upload(path, file)`).
/// Buckets and paths mirror the web so the server's account-deletion cleanup still applies.
struct SupabaseStorage: Sendable {
    let baseURL: URL
    let anonKey: String
    var session: URLSession = .shared

    enum Bucket: String, Sendable {
        case avatars
        case postImages = "post-images"
    }

    struct UploadError: Error, LocalizedError, Sendable {
        let message: String
        var errorDescription: String? { message }
    }

    /// `upload(path, file, { upsert: false, contentType })` → public URL.
    func upload(_ data: Data, bucket: Bucket, path: String, contentType: String) async throws -> String {
        var request = URLRequest(url: objectURL(bucket: bucket, path: path))
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("false", forHTTPHeaderField: "x-upsert")
        request.setValue("3600", forHTTPHeaderField: "Cache-Control")
        request.httpBody = data
        let (body, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(StorageErrorBody.self, from: body))?.message ?? "Upload failed"
            throw UploadError(message: message)
        }
        return publicURL(bucket: bucket, path: path)
    }

    /// `storage.from(bucket).remove([path])`.
    func remove(bucket: Bucket, paths: [String]) async {
        var request = URLRequest(url: baseURL.appending(path: "storage/v1/object/\(bucket.rawValue)"))
        request.httpMethod = "DELETE"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["prefixes": paths])
        _ = try? await session.data(for: request)
    }

    /// `getPublicUrl(path).data.publicUrl`.
    func publicURL(bucket: Bucket, path: String) -> String {
        baseURL.appending(path: "storage/v1/object/public/\(bucket.rawValue)/\(path)").absoluteString
    }

    /// Inverse of `publicURL` for the avatars bucket (web `getStoragePath`).
    static func avatarPath(fromPublicURL url: String) -> String? {
        let marker = "/object/public/avatars/"
        guard let range = url.range(of: marker) else { return nil }
        return String(url[range.upperBound...])
    }

    private func objectURL(bucket: Bucket, path: String) -> URL {
        baseURL.appending(path: "storage/v1/object/\(bucket.rawValue)/\(path)")
    }

    private struct StorageErrorBody: Decodable {
        let message: String?
    }
}

/// Upload paths used by each web composer.
enum UploadPath {
    /// welcome/page.tsx: `${user.id}-${Date.now()}.jpg`
    static func avatar(userId: Int, now: Date = .now) -> String { "\(userId)-\(millis(now)).jpg" }
    /// PostComposer / ThreadComposer: `${user.id}/${Date.now()}-${i}.${ext}`
    static func post(userId: Int, index: Int, ext: String = "jpg", now: Date = .now) -> String {
        "\(userId)/\(millis(now))-\(index).\(ext)"
    }
    /// places/[abbr]: `reviews/${user.id}/${Date.now()}-${i}.${ext}`
    static func placeReview(userId: Int, index: Int, ext: String = "jpg", now: Date = .now) -> String {
        "reviews/\(userId)/\(millis(now))-\(index).\(ext)"
    }
    /// research/college/[id]: `reviews/colleges/${user.id}/${Date.now()}-${i}.${ext}`
    static func collegeReview(userId: Int, index: Int, ext: String = "jpg", now: Date = .now) -> String {
        "reviews/colleges/\(userId)/\(millis(now))-\(index).\(ext)"
    }

    static func millis(_ date: Date) -> Int64 { Int64((date.timeIntervalSince1970 * 1000).rounded(.down)) }
}
