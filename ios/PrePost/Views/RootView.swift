import SwiftData
import SwiftUI

/// Token gate: token entry until a token is saved, then the drafts list.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var path: [Draft.ID] = []

    var body: some View {
        if environment.hasToken {
            NavigationStack(path: $path) {
                DraftsListView(path: $path)
            }
        } else {
            TokenEntryView()
        }
    }
}

#Preview("With token") {
    RootView()
        .environment(AppEnvironment.preview())
        .modelContainer(.preview)
}

#Preview("No token") {
    RootView()
        .environment(AppEnvironment.preview(hasToken: false))
        .modelContainer(.preview)
}
