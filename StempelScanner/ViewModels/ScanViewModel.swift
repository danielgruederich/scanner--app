import Foundation

@MainActor
final class ScanViewModel: ObservableObject {

    @Published var scanMode: ScanMode = .stamp
    @Published var isLoading = false
    @Published var lastCard: Card?
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var availableRewards: [RewardTier] = []
    @Published var showRewardPicker = false

    private let apiService: APIService
    private let offlineQueue: OfflineQueueService
    private var pendingCardId: String?

    init(apiService: APIService, offlineQueue: OfflineQueueService) {
        self.apiService = apiService
        self.offlineQueue = offlineQueue
    }

    // MARK: - Called by BLEService when a barcode arrives

    func handleScan(cardId: String) {
        guard !isLoading else { return }
        clearMessages()

        switch scanMode {
        case .stamp:
            Task { await addStamp(cardId: cardId) }
        case .redeem:
            Task { await prepareRedeem(cardId: cardId) }
        }
    }

    // MARK: - Stamp

    private func addStamp(cardId: String) async {
        isLoading = true
        do {
            let card = try await apiService.stampCard(cardId: cardId, stamps: 1, comment: "Scan via iOS POS")
            lastCard = card
            successMessage = "✓ Stempel gegeben (\(card.currentStamps)/\(card.maxStamps))"
        } catch APIError.cardNotFound(_) {
            errorMessage = "Karte nicht gefunden"
        } catch APIError.unauthorized {
            errorMessage = "Nicht eingeloggt"
        } catch {
            offlineQueue.enqueue(cardId: cardId, stamps: 1, comment: "Offline")
            successMessage = "Offline gespeichert — wird sync wenn online"
        }
        isLoading = false
    }

    // MARK: - Redeem

    private func prepareRedeem(cardId: String) async {
        isLoading = true
        do {
            let card = try await apiService.getCard(id: cardId)
            lastCard = card
            let rewards = card.availableRewardTiers

            if rewards.isEmpty {
                errorMessage = "Kein Reward verfügbar"
                isLoading = false
            } else if rewards.count == 1 {
                await redeemReward(cardId: cardId, rewardId: rewards[0].id)
            } else {
                availableRewards = rewards
                pendingCardId = cardId
                showRewardPicker = true
                isLoading = false
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func redeemSelected(rewardId: Int) {
        guard let cardId = pendingCardId else { return }
        showRewardPicker = false
        Task { await redeemReward(cardId: cardId, rewardId: rewardId) }
    }

    private func redeemReward(cardId: String, rewardId: Int) async {
        isLoading = true
        do {
            let card = try await apiService.receiveReward(cardId: cardId, rewardId: rewardId, comment: "Einlösen via iOS POS")
            lastCard = card
            successMessage = "✓ Reward eingelöst"
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Helpers

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
