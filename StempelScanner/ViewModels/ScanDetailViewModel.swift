import Foundation

final class ScanDetailViewModel: ObservableObject {
    @Published var card: Card?
    @Published var isLoading = false
    @Published var message: String?

    private let api: APIService
    private let employeeName: String

    init(api: APIService, employeeName: String) {
        self.api = api
        self.employeeName = employeeName
    }

    func loadCard(id: String) {
        isLoading = true
        Task {
            do {
                let card = try await api.getCard(id: id)
                await MainActor.run {
                    self.card = card
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.message = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func addManualStamp() {
        guard let cardId = card?.id else { return }
        isLoading = true
        Task {
            do {
                let updated = try await api.addStamp(cardId: cardId, stamps: 1, comment: "Manuell von: \(employeeName)")
                await MainActor.run {
                    self.card = updated
                    self.message = "Stempel hinzugefügt"
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.message = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func redeemReward() {
        guard let cardId = card?.id,
              let rewardTier = card?.availableRewardTiers.first else { return }
        isLoading = true
        Task {
            do {
                let updated = try await api.receiveReward(cardId: cardId, rewardId: rewardTier.id, comment: "Eingelöst von: \(employeeName)")
                await MainActor.run {
                    self.card = updated
                    self.message = "Belohnung eingelöst"
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.message = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
