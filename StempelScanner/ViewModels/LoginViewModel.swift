import Foundation

final class LoginViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    func handleLoginCallback(url: URL, authService: AuthService) async {
        // Extract token from callback URL
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              let refresh = components.queryItems?.first(where: { $0.name == "refresh_token" })?.value else {
            await MainActor.run {
                self.errorMessage = "Login fehlgeschlagen — kein Token erhalten"
                self.isLoading = false
            }
            return
        }

        do {
            try await authService.loginWithToken(
                jwt: token,
                refreshToken: refresh,
                domain: authService.storedDomain ?? ""
            )
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            self.isLoading = false
        }
    }
}
