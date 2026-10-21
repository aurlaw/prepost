import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var isReplacingToken = false
    @State private var isConfirmingRemove = false
    @State private var connection: ConnectionState = .idle
    @State private var errorMessage: String?

    private enum ConnectionState: Equatable {
        case idle, checking, reachable, failed(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("API") {
                    LabeledContent("Host", value: environment.config.apiBaseURL.host() ?? "—")
                    LabeledContent("Token", value: environment.hasToken ? "Saved" : "Not set")
                    Button("Replace token") { isReplacingToken = true }
                    Button("Remove token", role: .destructive) { isConfirmingRemove = true }
                }

                Section {
                    Button("Check connection", action: checkConnection)
                        .disabled(connection == .checking)
                    switch connection {
                    case .idle:
                        EmptyView()
                    case .checking:
                        ProgressView()
                    case .reachable:
                        Label("Reachable", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    case .failed(let message):
                        Label(message, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
                    }
                } footer: {
                    Text("Checks that the server is up. It doesn't check the token.")
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }

                Section("About") {
                    LabeledContent("Version", value: Self.versionString)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $isReplacingToken) {
                NavigationStack {
                    TokenEntryView { isReplacingToken = false }
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { isReplacingToken = false }
                            }
                        }
                }
            }
            .confirmationDialog("Remove the saved token?", isPresented: $isConfirmingRemove, titleVisibility: .visible) {
                Button("Remove token", role: .destructive, action: removeToken)
            } message: {
                Text("You'll need to paste it again to use the app.")
            }
        }
    }

    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private func checkConnection() {
        connection = .checking
        Task {
            do {
                _ = try await environment.api.health()
                connection = .reachable
            } catch {
                connection = .failed(error.localizedDescription)
            }
        }
    }

    private func removeToken() {
        do {
            try environment.removeToken()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppEnvironment.preview())
}
