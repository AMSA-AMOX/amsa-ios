import UIKit
import UserNotifications

private enum DevicesAPI {
    /// `POST /api/user/devices` — builds run from Xcode get sandbox tokens, TestFlight / App Store builds production ones.
    static func register(token: String) -> Endpoint<Empty> {
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        return Endpoint(method: .post, path: "/api/user/devices", body: ["token": .string(token), "environment": .string(environment)])
    }

    static func unregister(token: String, session: String) -> Endpoint<Empty> {
        Endpoint(method: .delete, path: "/api/user/devices", body: ["token": .string(token)], bearer: session)
    }
}

/// Notifications on this device. Once signed in it asks for permission, registers with APNs and hands
/// the device token to the website, which pushes new followers, questions, answers and membership
/// updates (src/lib/push.ts). Tapping a notification opens its `href`.
///
/// Remote pushes also need the Push Notifications entitlement (`AMSA_CODE_SIGN_ENTITLEMENTS`, which
/// needs a paid developer team). Without it APNs registration fails quietly and only local
/// notifications (the signup welcome) arrive.
@MainActor
@Observable
final class PushNotifications: NSObject, UNUserNotificationCenterDelegate {
    /// A tapped notification's link, waiting for the dashboard to open it.
    var pendingHref: String?
    /// A notification arrived while the app was open.
    @ObservationIgnored var onReceive: (() -> Void)?

    @ObservationIgnored private let api: APIClient
    @ObservationIgnored private var deviceToken: String?
    /// The session the device was registered under, so sign-out can take it back off that account.
    @ObservationIgnored private var registeredSession: String?
    @ObservationIgnored private var welcomeName: String?

    init(api: APIClient) {
        self.api = api
        super.init()
        // Set during launch so a tap that launched the app still reaches `didReceive`.
        UNUserNotificationCenter.current().delegate = self
    }

    /// Called whenever the signed-in app appears: asks the first time, then registers again, since
    /// APNs can change the token and the device may now be signed in to another account.
    func start() async {
        let center = UNUserNotificationCenter.current()
        if await center.notificationSettings().authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
        guard [.authorized, .provisional, .ephemeral].contains(await center.notificationSettings().authorizationStatus)
        else { return }
        if let name = welcomeName {
            welcomeName = nil
            await scheduleWelcome(firstName: name)
        }
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// The website's welcome notification, sent from the device: when the account is created the
    /// device isn't registered for pushes yet, so a server push would have nowhere to go.
    func welcomeAfterSignup(firstName: String) {
        welcomeName = firstName.trimmed
    }

    func didRegister(deviceToken data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        deviceToken = token
        guard let session = api.credentials.token else { return }
        Task {
            do {
                _ = try await api.send(DevicesAPI.register(token: token))
                registeredSession = session
            } catch {
                #if DEBUG
                print("⚠️ Registering for push notifications failed: \(error)")
                #endif
            }
        }
    }

    func didFailToRegister(_ error: Error) {
        #if DEBUG
        // Expected until the Push Notifications entitlement is on (see AMSA_CODE_SIGN_ENTITLEMENTS).
        print("⚠️ APNs registration failed: \(error.localizedDescription)")
        #endif
    }

    /// After sign-out (the session token is already cleared): stop this member's pushes on this device.
    func signedOut() {
        welcomeName = nil
        guard let deviceToken, let session = registeredSession else { return }
        registeredSession = nil
        Task { _ = try? await api.send(DevicesAPI.unregister(token: deviceToken, session: session)) }
    }

    private func scheduleWelcome(firstName: String) async {
        let content = UNMutableNotificationContent()
        // get_notifications: trim('Welcome to AMSA, ' || firstName || '!')
        content.title = firstName.isEmpty ? "Welcome to AMSA!" : "Welcome to AMSA, \(firstName)!"
        content.body = "Your account is all set. Explore the network and connect with other Mongolian students."
        content.sound = .default
        content.userInfo = ["href": "/dashboard/feed"]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "welcome", content: content, trigger: trigger))
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Shown as a banner even while the app is open.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        await MainActor.run { onReceive?() }
        return [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let href = response.notification.request.content.userInfo["href"] as? String
        await MainActor.run { pendingHref = href }
    }
}
