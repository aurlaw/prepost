import Foundation
import Observation

/// App-wide services, injected with `.environment(_:)`.
@Observable
@MainActor
final class AppEnvironment {
    let config: AppConfig
    let tokenStore: any TokenStore
    let api: APIClient
    private(set) var hasToken = false

    init(config: AppConfig, tokenStore: any TokenStore, session: URLSession = .shared) {
        self.config = config
        self.tokenStore = tokenStore
        self.api = APIClient(baseURL: config.apiBaseURL, tokenStore: tokenStore, session: session)
        refreshTokenState()
    }

    func saveToken(_ token: String) throws {
        try tokenStore.save(token)
        refreshTokenState()
    }

    func removeToken() throws {
        try tokenStore.delete()
        refreshTokenState()
    }

    func refreshTokenState() {
        hasToken = ((try? tokenStore.read()) ?? nil) != nil
    }

    static func preview(hasToken: Bool = true) -> AppEnvironment {
        AppEnvironment(
            config: AppConfig(apiBaseURL: URL(string: "https://api.example.com")!),
            tokenStore: InMemoryTokenStore(token: hasToken ? "preview-" + "token" : nil)
        )
    }
}

extension AppConfig {
    /// For previews and tests; the app builds its config from the bundle.
    nonisolated init(apiBaseURL: URL) {
        self.apiBaseURL = apiBaseURL
    }
}
