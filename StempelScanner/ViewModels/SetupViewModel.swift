import Foundation

final class SetupViewModel: ObservableObject {
    @Published var domain: String = ""
    @Published var apiKey: String = ""
    @Published var useAPIKey: Bool = false
    @Published var errorMessage: String?

    func setup(authService: AuthService) -> Bool {
        let cleanDomain = domain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !cleanDomain.isEmpty else {
            errorMessage = "Bitte Domain eingeben"
            return false
        }

        if useAPIKey {
            let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanKey.isEmpty else {
                errorMessage = "Bitte API-Key eingeben"
                return false
            }
            authService.loginWithAPIKey(key: cleanKey, domain: cleanDomain)
            return true
        }

        // Save domain for login flow
        authService.saveDomain(cleanDomain)
        return true
    }
}
