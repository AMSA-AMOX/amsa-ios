import UIKit

/// The UIKit callbacks SwiftUI has no equivalent for: the APNs device token.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Set by AMSAApp at launch, before APNs registration can start.
    static var push: PushNotifications?

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Self.push?.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Self.push?.didFailToRegister(error)
    }
}
