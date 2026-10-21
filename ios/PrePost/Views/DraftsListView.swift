import SwiftData
import SwiftUI

struct DraftsListView: View {
    @Binding var path: [Draft.ID]

    @Environment(\.modelContext) private var context
    @Query(sort: \Draft.updatedAt, order: .reverse) private var drafts: [Draft]
    @State private var isShowingSettings = false
    @State private var pendingSwipeDelete: Draft?
    /// Drafts created with + this session; discarded on leaving the editor if still empty.
    @State private var newDraftIDs: Set<Draft.ID> = []
    /// Drafts the editor asked to delete; deleted once the editor has been popped.
    @State private var deleteOnPop: Set<Draft.ID> = []

    var body: some View {
        List {
            ForEach(drafts) { draft in
                NavigationLink(value: draft.id) {
                    DraftRowView(draft: draft)
                }
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        pendingSwipeDelete = draft
                    }
                }
            }
        }
        .overlay {
            if drafts.isEmpty {
                ContentUnavailableView("No drafts", systemImage: "square.stack", description: Text("Tap + to start a post"))
            }
        }
        .navigationTitle("Drafts")
        .navigationDestination(for: Draft.ID.self) { id in
            DraftEditorDestination(id: id) {
                deleteOnPop.insert(id)
                path.removeAll { $0 == id }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("New draft", systemImage: "plus", action: createDraft)
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .confirmationDialog(
            "Delete this draft?",
            isPresented: Binding(get: { pendingSwipeDelete != nil }, set: { if !$0 { pendingSwipeDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingSwipeDelete
        ) { draft in
            Button("Delete draft", role: .destructive) {
                DraftDeletion.delete(draft, in: context)
            }
        } message: { _ in
            Text("This can't be undone.")
        }
        .onChange(of: path) { old, new in
            for id in Set(old).subtracting(new) { draftLeft(id) }
        }
    }

    private func createDraft() {
        let draft = Draft()
        context.insert(draft)
        newDraftIDs.insert(draft.id)
        path.append(draft.id)
    }

    /// Runs when a draft's editor is popped off the stack.
    private func draftLeft(_ id: Draft.ID) {
        let wasNew = newDraftIDs.remove(id) != nil
        let requested = deleteOnPop.remove(id) != nil
        guard let draft = drafts.first(where: { $0.id == id }) else { return }
        if requested || (wasNew && draft.isEmpty) {
            DraftDeletion.delete(draft, in: context)
        }
    }
}

/// Resolves a draft ID (value-based navigation, so later deep links and
/// Live Activity taps can target a draft) to its editor.
private struct DraftEditorDestination: View {
    let id: Draft.ID
    let onDelete: () -> Void

    @Query private var matches: [Draft]

    init(id: Draft.ID, onDelete: @escaping () -> Void) {
        self.id = id
        self.onDelete = onDelete
        _matches = Query(filter: #Predicate<Draft> { $0.id == id })
    }

    var body: some View {
        if let draft = matches.first {
            DraftEditorView(draft: draft, onDelete: onDelete)
        } else {
            ContentUnavailableView("Draft not found", systemImage: "questionmark.square.dashed")
        }
    }
}

#Preview {
    NavigationStack {
        DraftsListView(path: .constant([]))
    }
    .environment(AppEnvironment.preview())
    .modelContainer(.preview)
}
