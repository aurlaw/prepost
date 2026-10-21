import SwiftData
import SwiftUI

struct DraftEditorView: View {
    @Bindable var draft: Draft
    /// Asks the list to pop this editor and delete the draft.
    let onDelete: () -> Void

    @State private var isConfirmingDelete = false

    var body: some View {
        // A deleted model must not be read while the pop animation finishes.
        if draft.isDeleted {
            Color.clear
        } else {
            form
        }
    }

    private var form: some View {
        Form {
            Section("Photos") {
                Label("Photos are added in a later update", systemImage: "photo.on.rectangle.angled")
                    .foregroundStyle(.secondary)
            }

            Section {
                TextField("Write a caption…", text: edit(\.caption), axis: .vertical)
                    .lineLimit(4...)
            } header: {
                Text("Caption")
            } footer: {
                CaptionCountView(count: draft.caption.count)
            }

            Section {
                TextField("What happened here?", text: edit(\.note), axis: .vertical)
                    .lineLimit(2...)
            } header: {
                Text("Note")
            } footer: {
                Text("Only used to help generate captions.")
            }

            Section {
                TextField("Location", text: edit(\.locationText))
            } header: {
                Text("Location")
            } footer: {
                Text("Copied for you after posting; add it in Instagram.")
            }
        }
        .navigationTitle(draft.caption.isEmpty ? "New draft" : "Draft")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("More", systemImage: "ellipsis.circle") {
                    Button("Delete draft", systemImage: "trash", role: .destructive) {
                        isConfirmingDelete = true
                    }
                }
            }
        }
        .confirmationDialog("Delete this draft?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete draft", role: .destructive, action: onDelete)
        } message: {
            Text("This can't be undone.")
        }
    }

    /// A binding that writes straight to the model and bumps `updatedAt`.
    private func edit(_ keyPath: ReferenceWritableKeyPath<Draft, String>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { newValue in
                guard draft[keyPath: keyPath] != newValue else { return }
                draft[keyPath: keyPath] = newValue
                draft.touch()
            }
        )
    }
}

private struct CaptionCountView: View {
    let count: Int

    var body: some View {
        let limit = InstagramLimits.captionMaxCharacters
        Text("\(count.formatted()) / \(limit.formatted())")
            .monospacedDigit()
            .foregroundStyle(count > limit ? .red : .secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

#Preview {
    let draft = (try? ModelContainer.preview.mainContext.fetch(FetchDescriptor<Draft>()).first) ?? Draft()
    NavigationStack {
        DraftEditorView(draft: draft, onDelete: {})
    }
    .modelContainer(.preview)
}
