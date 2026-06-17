import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @ObservedObject var bluetooth: BLEService

    var body: some View {
        NavigationView {
            Form {
                Section("Auto-Abmeldung") {
                    Picker("Nach", selection: Binding(
                        get: { appState.authService.logoutTimerHours },
                        set: { appState.authService.logoutTimerHours = $0 }
                    )) {
                        Text("Nie").tag(0)
                        Text("4 Stunden").tag(4)
                        Text("8 Stunden").tag(8)
                        Text("12 Stunden").tag(12)
                        Text("24 Stunden").tag(24)
                    }
                    .pickerStyle(.segmented)
                }

                Section("BoomerangMe API") {
                    InfoRow(label: "Base URL", value: "api.digitalwallet.cards")
                    InfoRow(label: "Eingeloggt als", value: appState.authService.userName)
                }

                Section("NETUM C750 – BLE Hinweis") {
                    Text("Der Scanner muss im BLE-Modus (nicht HID) betrieben werden. Im HID-Modus erkennt iOS das Gerät als externe Tastatur.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section("Scanner Status") {
                    InfoRow(label: "Verbunden", value: bluetooth.isConnected ? "Ja" : "Nein")
                    InfoRow(label: "Gerät", value: bluetooth.scannerName)
                    InfoRow(label: "Service UUIDs", value: "FFF0 / 18F0 (Fallback)")
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.primary)
        }
    }
}
