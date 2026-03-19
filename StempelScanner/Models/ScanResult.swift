import Foundation

// MARK: - Scan State

enum ScanState: Equatable {
    case idle
    case validating
    case processing
    case success(String)
    case failure(String)
}

// MARK: - Scan Result

struct ScanResult: Identifiable, Codable {
    let id: UUID
    let cardId: String
    let customerName: String
    let stampsAdded: Int
    let currentStamps: Int
    let totalStamps: Int
    let employeeName: String
    let timestamp: Date
    var success: Bool

    init(cardId: String, customerName: String, stampsAdded: Int, currentStamps: Int, totalStamps: Int, employeeName: String, success: Bool = true) {
        self.id = UUID()
        self.cardId = cardId
        self.customerName = customerName
        self.stampsAdded = stampsAdded
        self.currentStamps = currentStamps
        self.totalStamps = totalStamps
        self.employeeName = employeeName
        self.timestamp = Date()
        self.success = success
    }
}
