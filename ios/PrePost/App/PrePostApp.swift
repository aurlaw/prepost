import SwiftUI

@main
struct PrePostApp: App {
    private let config: AppConfig?

    init() {
        do {
            config = try AppConfig(bundle: .main)
        } catch {
            assertionFailure("Invalid \(AppConfig.apiBaseURLKey) in Info.plist: \(error). Check Configs/Base.xcconfig.")
            config = nil
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(apiHost: config?.apiBaseURL.host())
        }
    }
}
