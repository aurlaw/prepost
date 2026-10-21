import Foundation
import SwiftData

extension ModelContainer {
    static let prePostSchema = Schema([Draft.self, DraftPhoto.self, Category.self])

    /// The app's on-disk store. Local only — no CloudKit.
    static func prePostOnDisk() throws -> ModelContainer {
        try ModelContainer(
            for: prePostSchema,
            configurations: ModelConfiguration(schema: prePostSchema, cloudKitDatabase: .none)
        )
    }

    /// Empty in-memory store, for tests.
    static func prePostInMemory() throws -> ModelContainer {
        try ModelContainer(
            for: prePostSchema,
            configurations: ModelConfiguration(schema: prePostSchema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }

    /// In-memory store seeded with placeholder drafts, for SwiftUI previews.
    static let preview: ModelContainer = {
        do {
            let container = try prePostInMemory()
            let context = container.mainContext
            let captions = [
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit.\nSed do eiusmod tempor.",
                "Ut enim ad minim veniam, quis nostrud exercitation.",
                "",
            ]
            for (offset, caption) in captions.enumerated() {
                let draft = Draft(now: .now.addingTimeInterval(TimeInterval(-offset * 5_400)))
                draft.caption = caption
                draft.locationText = offset == 0 ? "Lorem Canyon" : ""
                context.insert(draft)
            }
            let failed = Draft(now: .now.addingTimeInterval(-90_000))
            failed.caption = "Duis aute irure dolor in reprehenderit."
            failed.status = .failed
            context.insert(failed)
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }()
}
