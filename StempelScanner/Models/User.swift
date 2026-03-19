import Foundation

struct UserResponse: Codable {
    let data: UserData
}

struct UserData: Codable {
    let id: Int
    let attributes: UserAttributes
}

struct UserAttributes: Codable {
    let id: String
    let name: String?
    let surname: String?
    let companyName: String?
    let email: String?
    let phone: String?
    let company: Int?
    let apiKey: String?
    let isManager: Bool?
    let isAgency: Bool?
    let isSubaccount: Bool?
    let autoAccrualOperationsDelay: Int?

    var displayName: String {
        [name, surname].compactMap { $0 }.joined(separator: " ")
    }
}
