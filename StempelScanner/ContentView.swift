import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var ble = BLEService()

    var body: some View {
        ScanView(
            ble: ble,
            apiService: appState.apiService,
            offlineQueue: OfflineQueueService()
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
