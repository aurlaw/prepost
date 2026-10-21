import SwiftData
import SwiftUI

@main
struct PrePostApp: App {
    private enum Launch {
        case ready(AppEnvironment, ModelContainer)
        case failed(title: String, message: String)
    }

    private let launch: Launch

    init() {
        let config: AppConfig
        do {
            config = try AppConfig(bundle: .main)
        } catch {
            assertionFailure("Invalid \(AppConfig.apiBaseURLKey) in Info.plist: \(error). Check Configs/Base.xcconfig.")
            launch = .failed(
                title: "App not configured",
                message: "The API address is missing or invalid in this build (\(AppConfig.apiBaseURLKey))."
            )
            return
        }

        do {
            let container = try ModelContainer.prePostOnDisk()
            launch = .ready(AppEnvironment(config: config, tokenStore: KeychainTokenStore()), container)
        } catch {
            launch = .failed(title: "Can't open drafts", message: "The local drafts store failed to load.\n\(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            switch launch {
            case .ready(let environment, let container):
                RootView()
                    .environment(environment)
                    .modelContainer(container)
            case .failed(let title, let message):
                LaunchErrorView(title: title, message: message)
            }
        }
    }
}
