import SwiftUI

struct TokenEntryView: View {
    /// Called after a successful save (e.g. to dismiss a sheet).
    var onSaved: (() -> Void)?

    @Environment(AppEnvironment.self) private var environment
    @State private var token = ""
    @State private var errorMessage: String?

    private var trimmed: String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section {
                SecureField("API token", text: $token)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .onSubmit(save)
                PasteButton(payloadType: String.self) { strings in
                    if let first = strings.first { token = first }
                }
            } header: {
                Text("API token")
            } footer: {
                Text("Paste the API token for \(environment.config.apiBaseURL.host() ?? "the API").")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }

            Section {
                Button("Save", action: save)
                    .disabled(trimmed.isEmpty)
            }
        }
        .navigationTitle("Pre Post")
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        do {
            try environment.saveToken(token)
            token = ""
            errorMessage = nil
            onSaved?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { TokenEntryView() }
        .environment(AppEnvironment.preview(hasToken: false))
}
