import SwiftUI

/// Main POS overlay view.
///
/// Design goals:
/// - Compact floating panel that does NOT block the on-screen keyboard.
/// - The panel uses .safeAreaInset so it stays above the keyboard.
/// - No UITextField / UITextView usage → keyboard stays under the POS app's control.
struct ContentView: View {

    @StateObject private var bluetooth = BLEService()
    @StateObject private var appState = AppState()

    @State private var scanState: ScanState = .idle
    @State private var lastCode: String?
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack {
                Spacer()
                scanPanel
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            bluetooth.onCodeScanned = { code in
                handleScannedCode(code)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(bluetooth: bluetooth)
        }
    }

    // MARK: - Scan panel

    private var scanPanel: some View {
        VStack(spacing: 12) {

            // Header row
            HStack {
                Image(systemName: "barcode.viewfinder")
                    .font(.title2)
                Text("StempelScanner")
                    .font(.headline)
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // BLE connection status
            ConnectionStatusRow(bluetooth: bluetooth)

            Divider()

            // Scan result
            ScanResultRow(state: scanState, lastCode: lastCode)

        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
        .shadow(radius: 8, y: 4)
    }

    // MARK: - Business logic

    private func handleScannedCode(_ code: String) {
        guard scanState == .idle else { return } // debounce
        guard code.isValidCardID else {
            setStatus(.failure("Ungültiger Barcode"))
            resetAfterDelay()
            return
        }

        lastCode = code
        scanState = .validating

        Task {
            do {
                await setStatus(.validating)
                let updatedCard = try await appState.apiService.stampCard(cardId: code)
                let name = updatedCard.customer.firstName ?? "Kunde"
                let stamps = updatedCard.balance.currentNumberOfUses ?? 0
                let total = updatedCard.balance.numberStampsTotal ?? 0
                await setStatus(.success("\(name) — \(stamps)/\(total) Stempel ✓"))
            } catch {
                await setStatus(.failure(error.localizedDescription))
            }

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await setStatus(.idle)
        }
    }

    @MainActor
    private func setStatus(_ state: ScanState) {
        scanState = state
    }

    private func resetAfterDelay() {
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await setStatus(.idle)
        }
    }
}

// MARK: - ConnectionStatusRow

struct ConnectionStatusRow: View {
    @ObservedObject var bluetooth: BLEService

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(bluetooth.isConnected ? Color.green : Color.orange)
                .frame(width: 10, height: 10)

            Text(bluetooth.isConnected
                 ? "Verbunden: \(bluetooth.scannerName)"
                 : bluetooth.statusMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer()

            if !bluetooth.isConnected && bluetooth.isBluetoothReady {
                Button("Suchen") {
                    bluetooth.startScanning()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - ScanResultRow

struct ScanResultRow: View {
    let state: ScanState
    let lastCode: String?

    var body: some View {
        HStack(spacing: 12) {
            stateIcon
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                if let code = lastCode {
                    Text(code)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("Warte auf Scan…")
                        .foregroundColor(.secondary)
                }

                stateLabel
                    .font(.caption)
                    .foregroundStyle(stateLabelColor)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch state {
        case .idle:
            Image(systemName: "barcode")
                .foregroundColor(.secondary)
                .font(.title2)
        case .validating:
            ProgressView()
                .tint(.blue)
        case .processing:
            ProgressView()
                .tint(.orange)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.title2)
        }
    }

    private var stateLabel: Text {
        switch state {
        case .idle:           return Text("Bereit")
        case .validating:     return Text("Karte wird geprüft…")
        case .processing:     return Text("Stempel wird vergeben…")
        case .success(let m): return Text(m)
        case .failure(let m): return Text(m)
        }
    }

    private var stateLabelColor: Color {
        switch state {
        case .idle:                    return Color(UIColor.secondaryLabel)
        case .validating, .processing: return .blue
        case .success:                 return .green
        case .failure:                 return .red
        }
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var bluetooth: BLEService

    var body: some View {
        NavigationView {
            Form {
                Section("Boomerangme V2 API") {
                    InfoRow(label: "Base URL", value: "api.digitalwallet.cards")
                }
                Section("NETUM C750 – BLE Hinweis") {
                    Text("Der Scanner muss zwingend im BLE-Modus (nicht HID) betrieben werden. Im HID-Modus erkennt iOS das Gerät als externe Tastatur und blendet die Bildschirmtastatur aus.")
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

#Preview {
    ContentView()
}
