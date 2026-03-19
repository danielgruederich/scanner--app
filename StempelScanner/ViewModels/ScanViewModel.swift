import Foundation
import Combine

final class ScanViewModel: ObservableObject {

    @Published var currentCard: Card?
    @Published var scanHistory: [ScanResult] = []
    @Published var isProcessing = false
    @Published var statusMessage: String = "Wartet auf Scan..."
    @Published var showSuccess = false
    @Published var showError = false
    @Published var errorMessage: String = ""

    let api: APIService
    let offlineQueue: OfflineQueueService
    let employeeName: String

    init(api: APIService, offlineQueue: OfflineQueueService, employeeName: String) {
        self.api = api
        self.offlineQueue = offlineQueue
        self.employeeName = employeeName
    }

    func handleScan(cardId: String) {
        guard !isProcessing else { return }
        guard cardId.isValidCardID else {
            showErrorMessage("Ungültiger Barcode")
            return
        }

        isProcessing = true
        statusMessage = "Karte wird geladen..."

        Task {
            do {
                let card = try await api.getCard(id: cardId)
                await MainActor.run { self.currentCard = card }

                let comment = "Stempel von: \(employeeName)"
                let updatedCard = try await api.addStamp(cardId: cardId, stamps: 1, comment: comment)

                let result = ScanResult(
                    cardId: cardId,
                    customerName: card.customer.firstName ?? "Unbekannt",
                    stampsAdded: 1,
                    currentStamps: updatedCard.balance.currentNumberOfUses ?? 0,
                    totalStamps: updatedCard.balance.numberStampsTotal ?? 0,
                    employeeName: employeeName
                )

                await MainActor.run {
                    self.currentCard = updatedCard
                    self.scanHistory.insert(result, at: 0)
                    if self.scanHistory.count > 50 { self.scanHistory.removeLast() }
                    self.statusMessage = "\(result.customerName) — \(result.currentStamps)/\(result.totalStamps) Stempel"
                    self.showSuccess = true
                    self.isProcessing = false
                }

                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    self.showSuccess = false
                    self.statusMessage = "Wartet auf Scan..."
                }

            } catch {
                if (error as? URLError)?.code == .notConnectedToInternet {
                    offlineQueue.enqueue(cardId: cardId, stamps: 1, comment: "Stempel von: \(employeeName)")
                    await MainActor.run {
                        self.statusMessage = "Offline — Stempel in Warteschlange"
                        self.isProcessing = false
                    }
                } else {
                    await MainActor.run {
                        self.showErrorMessage(error.localizedDescription)
                        self.isProcessing = false
                    }
                }
            }
        }
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
        statusMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showError = false
            self.statusMessage = "Wartet auf Scan..."
        }
    }

    func replayOfflineQueue() {
        Task {
            let result = await offlineQueue.replay(using: api)
            await MainActor.run {
                self.statusMessage = "Offline-Queue: \(result.success) erfolgreich, \(result.failed) fehlgeschlagen"
            }
        }
    }
}
