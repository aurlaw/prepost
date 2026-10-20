import SwiftUI

/// Placeholder screen until A1 replaces it with the drafts list.
struct RootView: View {
    let apiHost: String?

    var body: some View {
        VStack(spacing: 12) {
            Text("Pre Post")
                .font(.largeTitle.bold())
            if let apiHost {
                Label(apiHost, systemImage: "network")
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
            } else {
                Label("API not configured", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }
}

#Preview("Configured") {
    RootView(apiHost: "api.example.com")
}

#Preview("Not configured") {
    RootView(apiHost: nil)
}
