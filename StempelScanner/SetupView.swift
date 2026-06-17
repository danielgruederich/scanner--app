import SwiftUI

struct SetupView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SetupViewModel()
    @State private var showLogin = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("z.B. app.meinrestaurant.de", text: $viewModel.domain)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Boomerangme Domain")
                } footer: {
                    Text("Die Domain deines Boomerangme Whitelabel-Portals, ohne https://")
                }

                Section {
                    Toggle("API-Key direkt eingeben", isOn: $viewModel.useAPIKey)
                    if viewModel.useAPIKey {
                        TextField("API-Key", text: $viewModel.apiKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.system(.body, design: .monospaced))
                    }
                } footer: {
                    Text(viewModel.useAPIKey
                         ? "Den API-Key findest du in deinem Boomerangme-Portal unter Einstellungen."
                         : "Ohne API-Key wirst du im nächsten Schritt über das Boomerangme-Portal angemeldet.")
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Einrichtung")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Weiter") {
                        handleSetup()
                    }
                    .disabled(viewModel.domain.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
                .environmentObject(appState)
        }
    }

    private func handleSetup() {
        let success = viewModel.setup(authService: appState.authService)
        guard success else { return }
        if !viewModel.useAPIKey {
            showLogin = true
        }
        // API-Key path: authService.isAuthenticated becomes true → app root re-renders
    }
}

#Preview {
    SetupView()
        .environmentObject(AppState())
}
