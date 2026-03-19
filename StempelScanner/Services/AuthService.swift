import Foundation

final class AuthService: ObservableObject {

    private let keychain = KeychainService()
    private let keychainKeyAPIKey = "api_key"
    private let keychainKeyJWT = "jwt_token"
    private let keychainKeyRefresh = "refresh_token"
    private let keychainKeyDomain = "whitelabel_domain"
    private let keychainKeyUserName = "user_name"
    private let keychainKeyLoginMethod = "login_method"
    private let keychainKeyLogoutTimer = "logout_timer"
    private let keychainKeyLoginTimestamp = "login_timestamp"

    @Published var isAuthenticated = false
    @Published var userName: String = ""
    @Published var apiKey: String = ""

    init() {
        loadStoredCredentials()
    }

    // MARK: - Stored Credentials

    private func loadStoredCredentials() {
        if let key = keychain.read(key: keychainKeyAPIKey) {
            apiKey = key
            userName = keychain.read(key: keychainKeyUserName) ?? "Inhaber"
            isAuthenticated = true
            checkAutoLogout()
        }
    }

    // MARK: - API Key Login (Option B)

    func loginWithAPIKey(key: String, domain: String) {
        keychain.save(key: keychainKeyAPIKey, value: key)
        keychain.save(key: keychainKeyDomain, value: domain)
        keychain.save(key: keychainKeyLoginMethod, value: "apikey")
        keychain.save(key: keychainKeyUserName, value: "Inhaber")
        keychain.save(key: keychainKeyLoginTimestamp, value: String(Date().timeIntervalSince1970))
        apiKey = key
        userName = "Inhaber"
        isAuthenticated = true
    }

    // MARK: - Boomerang Login (Option A)

    func loginWithToken(jwt: String, refreshToken: String, domain: String) async throws {
        let api = APIService(apiKey: "")
        let profile = try await api.getProfile(jwtToken: jwt)

        guard let key = profile.apiKey else {
            throw AuthError.noAPIKey
        }

        keychain.save(key: keychainKeyJWT, value: jwt)
        keychain.save(key: keychainKeyRefresh, value: refreshToken)
        keychain.save(key: keychainKeyAPIKey, value: key)
        keychain.save(key: keychainKeyDomain, value: domain)
        keychain.save(key: keychainKeyLoginMethod, value: "boomerang")
        keychain.save(key: keychainKeyUserName, value: profile.displayName)
        keychain.save(key: keychainKeyLoginTimestamp, value: String(Date().timeIntervalSince1970))

        await MainActor.run {
            self.apiKey = key
            self.userName = profile.displayName
            self.isAuthenticated = true
        }
    }

    // MARK: - Domain

    func saveDomain(_ domain: String) {
        keychain.save(key: keychainKeyDomain, value: domain)
    }

    var storedDomain: String? {
        keychain.read(key: keychainKeyDomain)
    }

    // MARK: - Logout

    func logout() {
        keychain.delete(key: keychainKeyAPIKey)
        keychain.delete(key: keychainKeyJWT)
        keychain.delete(key: keychainKeyRefresh)
        keychain.delete(key: keychainKeyUserName)
        keychain.delete(key: keychainKeyLoginMethod)
        keychain.delete(key: keychainKeyLoginTimestamp)
        apiKey = ""
        userName = ""
        isAuthenticated = false
    }

    // MARK: - Auto Logout

    var logoutTimerHours: Int {
        get { Int(keychain.read(key: keychainKeyLogoutTimer) ?? "0") ?? 0 }
        set { keychain.save(key: keychainKeyLogoutTimer, value: String(newValue)) }
    }

    func checkAutoLogout() {
        let hours = logoutTimerHours
        guard hours > 0 else { return }
        guard let timestampStr = keychain.read(key: keychainKeyLoginTimestamp),
              let timestamp = Double(timestampStr) else { return }

        let loginDate = Date(timeIntervalSince1970: timestamp)
        let hoursElapsed = Date().timeIntervalSince(loginDate) / 3600
        if hoursElapsed >= Double(hours) {
            logout()
        }
    }
}

enum AuthError: LocalizedError {
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "Kein API-Key im Profil gefunden"
        }
    }
}
