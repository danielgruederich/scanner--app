import Foundation

/// Handles all calls to the Boomerangme V2 API.
///
/// Workflow (mandatory to avoid HTTP 500):
///   1. GET  /api/v2/cards/{id}            → validate card exists (cache warm-up)
///   2. POST /api/v2/cards/{id}/add-stamp  → book stamp(s)
final class APIService {

    private let baseURL = "https://api.digitalwallet.cards"
    private(set) var apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func updateAPIKey(_ key: String) {
        self.apiKey = key
    }

    // MARK: - Request Building

    private func buildRequest(endpoint: String, method: String, body: [String: Any]? = nil) -> URLRequest {
        let url = URL(string: baseURL + endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    // MARK: - 2-Step Stamp Workflow

    /// Validates the card and books stamp(s) in two steps to avoid HTTP 500.
    func stampCard(cardId: String, stamps: Int = 1, comment: String = "Scan via iPad POS") async throws -> Card {
        // Step 1 – Validate (mandatory cache warm-up)
        let card = try await getCard(id: cardId)
        // Step 2 – Book stamp
        let updatedCard = try await addStamp(cardId: cardId, stamps: stamps, comment: comment)
        return updatedCard
    }

    // MARK: - Card Operations

    func getCard(id: String) async throws -> Card {
        let request = buildRequest(endpoint: "/api/v2/cards/\(id)", method: "GET")
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
        let cardResponse = try JSONDecoder().decode(CardResponse.self, from: data)
        return cardResponse.data
    }

    func addStamp(cardId: String, stamps: Int, comment: String) async throws -> Card {
        let body: [String: Any] = ["stamps": stamps, "comment": comment]
        let request = buildRequest(endpoint: "/api/v2/cards/\(cardId)/add-stamp", method: "POST", body: body)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
        let cardResponse = try JSONDecoder().decode(CardResponse.self, from: data)
        return cardResponse.data
    }

    func receiveReward(cardId: String, rewardId: Int, comment: String) async throws -> Card {
        let body: [String: Any] = ["id": rewardId, "comment": comment]
        let request = buildRequest(endpoint: "/api/v2/cards/\(cardId)/receive-reward", method: "POST", body: body)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
        let cardResponse = try JSONDecoder().decode(CardResponse.self, from: data)
        return cardResponse.data
    }

    // MARK: - User Profile

    func getProfile(jwtToken: String) async throws -> UserAttributes {
        let url = URL(string: baseURL + "/me")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
        let userResponse = try JSONDecoder().decode(UserResponse.self, from: data)
        return userResponse.data.attributes
    }

    // MARK: - Helpers

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 404:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.cardNotFound(body)
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(httpResponse.statusCode, body)
        }
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case cardNotFound(String)
    case httpError(Int, String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Ungültige Server-Antwort"
        case .unauthorized: return "Nicht autorisiert — bitte neu einloggen"
        case .cardNotFound(let m): return "Karte nicht gefunden: \(m)"
        case .httpError(let c, let m): return "HTTP \(c): \(m)"
        case .network(let m): return "Netzwerk-Fehler: \(m)"
        }
    }
}
