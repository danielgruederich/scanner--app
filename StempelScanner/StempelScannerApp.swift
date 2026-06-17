import SwiftUI

@main
struct StempelScannerApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.authService.isAuthenticated {
                ContentView()
                    .environmentObject(appState)
            } else {
                SetupView()
                    .environmentObject(appState)
            }
        }
    }
}
