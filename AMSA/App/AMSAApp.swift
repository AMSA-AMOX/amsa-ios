import SwiftUI

@main
struct AMSAApp: App {
    @State private var environment: AppEnvironment

    init() {
        URLCache.shared = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 300 * 1024 * 1024)
        #if DEBUG
        // UI tests start signed out regardless of what an earlier run left in the Keychain.
        if ProcessInfo.processInfo.arguments.contains("-uiTestSignedOut") { Keychain.delete(SessionStore.account) }
        #endif
        _environment = State(initialValue: AppEnvironment.live())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment.session)
                .environment(environment.shell)
                .environment(environment.router)
                .environment(environment.links)
                .environment(environment.colleges)
                .environment(\.appEnvironment, environment)
                .environment(\.supabaseStorage, environment.storage)
                .preferredColorScheme(.light)
                // Web layouts are fixed-size; cap Dynamic Type before rows overflow.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .tint(Palette.navy)
        }
    }
}

extension EnvironmentValues {
    @Entry var appEnvironment: AppEnvironment? = nil
    @Entry var supabaseStorage: SupabaseStorage = SupabaseStorage(
        baseURL: AppConfig.current.supabaseURL, anonKey: AppConfig.current.supabaseAnonKey)
}
