import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = LoginViewModel()
    @Environment(\.dismiss) private var dismiss

    private let contextProvider = WebAuthContextProvider()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            VStack(spacing: 8) {
                Text("Mit Boomerangme anmelden")
                    .font(.title2.bold())
                Text("Du wirst kurz zum Boomerangme-Portal weitergeleitet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button(action: startOAuthLogin) {
                Group {
                    if viewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Anmelden")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
            .disabled(viewModel.isLoading)
        }
        .presentationDetents([.medium])
    }

    private func startOAuthLogin() {
        guard let domain = appState.authService.storedDomain, !domain.isEmpty else {
            viewModel.errorMessage = "Keine Domain gespeichert — bitte zurückgehen und Domain eingeben"
            return
        }

        let urlString = "https://\(domain)/auth/login?platform=ios&redirect_uri=stempelscanner://callback"
        guard let loginURL = URL(string: urlString) else {
            viewModel.errorMessage = "Ungültige Domain: \(domain)"
            return
        }

        viewModel.isLoading = true
        viewModel.errorMessage = nil

        let session = ASWebAuthenticationSession(
            url: loginURL,
            callbackURLScheme: "stempelscanner"
        ) { callbackURL, error in
            if let authError = error as? ASWebAuthenticationSessionError,
               authError.code == .canceledLogin {
                viewModel.isLoading = false
                return
            }

            guard let url = callbackURL else {
                viewModel.isLoading = false
                viewModel.errorMessage = "Login fehlgeschlagen — keine Callback-URL erhalten"
                return
            }

            Task {
                await viewModel.handleLoginCallback(url: url, authService: appState.authService)
                await MainActor.run {
                    if appState.authService.isAuthenticated {
                        dismiss()
                    }
                }
            }
        }

        session.presentationContextProvider = contextProvider
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }
}

private final class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
}
