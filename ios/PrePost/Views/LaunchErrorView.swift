import SwiftUI

/// Full-screen error shown instead of the app when config or the store fails at launch.
struct LaunchErrorView: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        }
    }
}

#Preview {
    LaunchErrorView(title: "Can't open drafts", message: "Lorem ipsum dolor sit amet.")
}
