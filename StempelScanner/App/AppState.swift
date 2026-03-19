import SwiftUI

final class AppState: ObservableObject {
    @Published var authService = AuthService()

    var apiService: APIService {
        APIService(apiKey: authService.apiKey)
    }
}
