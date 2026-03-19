import Foundation

struct OfflineStamp: Identifiable, Codable {
    let id: UUID
    let cardId: String
    let stamps: Int
    let comment: String
    let createdAt: Date
    var status: OfflineStampStatus

    enum OfflineStampStatus: String, Codable {
        case pending
        case sending
        case success
        case failed
    }

    init(cardId: String, stamps: Int, comment: String) {
        self.id = UUID()
        self.cardId = cardId
        self.stamps = stamps
        self.comment = comment
        self.createdAt = Date()
        self.status = .pending
    }
}
