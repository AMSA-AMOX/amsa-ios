import Foundation

enum UserAPI {
    /// DELETE /api/user/account — the server re-checks the confirmation word.
    static func deleteAccount(confirmation: String) -> Endpoint<MessageResponse> {
        Endpoint(method: .delete, path: "/api/user/account", body: ["confirmation": .string(confirmation)])
    }

    /// PATCH /api/user/profile — `""` values are stored as null by the server.
    static func updateProfile(_ fields: [String: JSONValue]) -> Endpoint<MeResponse> {
        Endpoint(method: .patch, path: "/api/user/profile", body: .object(fields))
    }
}
