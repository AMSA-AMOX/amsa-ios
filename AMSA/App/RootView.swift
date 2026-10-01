import SwiftUI

/// Auth gate: the web redirects every dashboard page to /login when there is no user.
struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        Group {
            if session.isAuthenticated {
                DashboardShell()
            } else {
                AuthFlowView()
            }
        }
    }
}
