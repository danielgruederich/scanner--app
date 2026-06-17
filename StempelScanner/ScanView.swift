import SwiftUI

struct ScanView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm: ScanViewModel
    @ObservedObject var ble: BLEService

    @State private var showSettings = false

    init(ble: BLEService, apiService: APIService, offlineQueue: OfflineQueueService) {
        self.ble = ble
        _vm = StateObject(wrappedValue: ScanViewModel(apiService: apiService, offlineQueue: offlineQueue))
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.authService.userName)
                        .font(.headline)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(ble.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(ble.isConnected ? ble.scannerName : "Kein Scanner")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Abmelden") {
                    appState.authService.logout()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            // MARK: - Mode Toggle
            HStack(spacing: 12) {
                ModeButton(
                    title: "Stempel geben",
                    icon: "star.fill",
                    color: .blue,
                    isSelected: vm.scanMode == .stamp
                ) { vm.scanMode = .stamp }

                ModeButton(
                    title: "Einlösen",
                    icon: "gift.fill",
                    color: .orange,
                    isSelected: vm.scanMode == .redeem
                ) { vm.scanMode = .redeem }
            }
            .padding()

            // MARK: - Status Area
            Spacer()

            if vm.isLoading {
                ProgressView()
                    .scaleEffect(2)
            } else if let success = vm.successMessage {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                    Text(success)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                    if let card = vm.lastCard {
                        StampProgressView(card: card)
                    }
                }
                .padding()
            } else if let error = vm.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: vm.scanMode == .stamp ? "barcode.viewfinder" : "gift")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                    Text(vm.scanMode == .stamp ? "Karte scannen zum Stempeln" : "Karte scannen zum Einlösen")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .onReceive(ble.$lastScannedCardID.compactMap { $0 }) { cardId in
            vm.handleScan(cardId: cardId)
        }
        .sheet(isPresented: $vm.showRewardPicker) {
            RewardPickerSheet(rewards: vm.availableRewards) { rewardId in
                vm.redeemSelected(rewardId: rewardId)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(bluetooth: ble)
                .environmentObject(appState)
        }
        .onChange(of: vm.successMessage) { _, msg in
            guard msg != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                vm.clearMessages()
            }
        }
    }
}

// MARK: - Sub-Views

struct ModeButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isSelected ? color : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct StampProgressView: View {
    let card: Card

    var body: some View {
        VStack(spacing: 6) {
            Text("\(card.currentStamps) von \(card.maxStamps) Stempeln")
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: Double(card.currentStamps), total: Double(max(card.maxStamps, 1)))
                .tint(.blue)
        }
        .padding(.horizontal)
    }
}

struct RewardPickerSheet: View {
    let rewards: [RewardTier]
    let onSelect: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(rewards) { reward in
                Button {
                    onSelect(reward.id)
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(reward.name ?? "Reward")
                            .font(.headline)
                        if let value = reward.value {
                            Text("Wert: \(value, specifier: "%.0f")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Reward auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}
