import Foundation

struct CardResponse: Codable {
    let data: Card
}

struct Card: Codable, Identifiable {
    let id: String
    let companyId: Int
    let templateId: Int
    let customerId: String
    let type: String
    let customer: CardCustomer
    let balance: CardBalance
    let availableRewardTiers: [RewardTier]
    let createdAt: String

    var device: String?
    var status: String?
    var expiresAt: String?
    var couponRedeemed: Bool?
}

struct CardCustomer: Codable {
    let id: String
    var firstName: String?
    var surname: String?
    var phone: String?
    var email: String?
    let segments: [CustomerSegment]
}

struct CustomerSegment: Codable {
    let id: Int
    let type: Int
    let name: String
}

struct CardBalance: Codable {
    var currentNumberOfUses: Int?
    var numberStampsTotal: Int?
    var numberRewardsUnused: Int?
    var balance: Double?
    var stampsBeforeReward: Int?
}

struct RewardTier: Codable, Identifiable {
    let id: Int
    let templateId: Int
    var name: String?
    let type: Int
    var threshold: Int?
    var value: Double?
}
