import Foundation

final class OfflineQueueService: ObservableObject {

    @Published var items: [OfflineStamp] = []
    private let storageKey = "offline_stamp_queue"

    var pendingCount: Int {
        items.filter { $0.status == .pending }.count
    }

    init() {
        loadFromDisk()
    }

    func enqueue(cardId: String, stamps: Int, comment: String) {
        let stamp = OfflineStamp(cardId: cardId, stamps: stamps, comment: comment)
        items.append(stamp)
        saveToDisk()
    }

    func markSending(id: UUID) {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items[idx].status = .sending
            saveToDisk()
        }
    }

    func markSuccess(id: UUID) {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items[idx].status = .success
            saveToDisk()
        }
    }

    func markFailed(id: UUID) {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items[idx].status = .failed
            saveToDisk()
        }
    }

    func clearAll() {
        items.removeAll()
        saveToDisk()
    }

    func clearCompleted() {
        items.removeAll { $0.status == .success }
        saveToDisk()
    }

    func replay(using api: APIService, delay: TimeInterval = 5.0) async -> (success: Int, failed: Int) {
        let pending = items.filter { $0.status == .pending || $0.status == .failed }
        var successCount = 0
        var failCount = 0

        for stamp in pending {
            markSending(id: stamp.id)
            do {
                _ = try await api.addStamp(cardId: stamp.cardId, stamps: stamp.stamps, comment: stamp.comment)
                markSuccess(id: stamp.id)
                successCount += 1
            } catch {
                markFailed(id: stamp.id)
                failCount += 1
            }
            if stamp.id != pending.last?.id {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        return (successCount, failCount)
    }

    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([OfflineStamp].self, from: data) else { return }
        items = saved
    }
}
