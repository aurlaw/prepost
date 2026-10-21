import Foundation
import SwiftData
import Testing
@testable import PrePost

@MainActor
struct ModelTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer.prePostInMemory()
    }

    private func addPhotos(_ indices: [Int], to draft: Draft) {
        for index in indices {
            let photo = DraftPhoto(sortIndex: index)
            context.insert(photo)
            photo.draft = draft
        }
    }

    @Test func draftDefaults() {
        let now = Date(timeIntervalSince1970: 1_000)
        let draft = Draft(now: now)
        context.insert(draft)
        #expect(draft.caption.isEmpty)
        #expect(draft.note.isEmpty)
        #expect(draft.locationText.isEmpty)
        #expect(draft.status == .editing)
        #expect(draft.statusRaw == "editing")
        #expect(draft.publishJobId == nil)
        #expect(draft.lastError == nil)
        #expect(draft.category == nil)
        #expect(draft.photos.isEmpty)
        #expect(draft.createdAt == now)
        #expect(draft.updatedAt == now)
        #expect(draft.isEmpty)
    }

    @Test func photoDefaults() {
        let photo = DraftPhoto(sortIndex: 3)
        #expect(photo.uploadState == .pending)
        #expect(photo.r2Key == nil)
        #expect(photo.remoteURL == nil)
        #expect(photo.localThumbnail == nil)
        #expect(photo.width == 0 && photo.height == 0)
    }

    @Test func orderedPhotosSortsBySortIndexRegardlessOfInsertionOrder() throws {
        let draft = Draft()
        context.insert(draft)
        addPhotos([2, 0, 3, 1], to: draft)
        try context.save()
        #expect(draft.orderedPhotos.map(\.sortIndex) == [0, 1, 2, 3])
    }

    @Test(arguments: [(0, nil), (1, PostKind.single), (2, .carousel), (10, .carousel)] as [(Int, PostKind?)])
    func postKind(count: Int, expected: PostKind?) {
        let draft = Draft()
        context.insert(draft)
        addPhotos(Array(0..<count), to: draft)
        #expect(draft.postKind == expected)
    }

    @Test func deletingDraftCascadesToPhotos() throws {
        let draft = Draft()
        context.insert(draft)
        addPhotos([0, 1, 2], to: draft)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<DraftPhoto>()) == 3)

        context.delete(draft)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Draft>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<DraftPhoto>()) == 0)
    }

    @Test func draftDeletionHelperDeletesDraftAndPhotos() throws {
        let draft = Draft()
        context.insert(draft)
        addPhotos([0, 1], to: draft)
        try context.save()

        DraftDeletion.delete(draft, in: context)
        #expect(try context.fetchCount(FetchDescriptor<Draft>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<DraftPhoto>()) == 0)
    }

    @Test func deletingCategoryNullifiesDraftAndKeepsIt() throws {
        let category = PrePost.Category(name: "Lorem", colorHex: "#0FA3A3", sortIndex: 0)
        let draft = Draft()
        context.insert(category)
        context.insert(draft)
        draft.category = category
        try context.save()
        #expect(category.drafts.count == 1)

        context.delete(category)
        try context.save()
        #expect(draft.category == nil)
        #expect(try context.fetchCount(FetchDescriptor<Draft>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<PrePost.Category>()) == 0)
    }

    @Test func unknownStatusRawFallsBackToEditing() {
        let draft = Draft()
        draft.statusRaw = "somethingNew"
        #expect(draft.status == .editing)

        let photo = DraftPhoto(sortIndex: 0)
        photo.uploadStateRaw = "somethingNew"
        #expect(photo.uploadState == .pending)
    }

    @Test func statusSetterWritesRawString() {
        let draft = Draft()
        draft.status = .failed
        #expect(draft.statusRaw == "failed")
    }

    @Test(arguments: [
        ("", "Untitled draft"),
        ("   \n\n", "Untitled draft"),
        ("Lorem ipsum\nDolor sit", "Lorem ipsum"),
        ("\n  Lorem ipsum  \nDolor", "Lorem ipsum"),
    ])
    func displayTitle(caption: String, expected: String) {
        let draft = Draft()
        draft.caption = caption
        #expect(draft.displayTitle == expected)
    }

    @Test func isEmptyIgnoresWhitespaceButNotPhotos() {
        let draft = Draft()
        context.insert(draft)
        draft.caption = "  \n"
        #expect(draft.isEmpty)
        draft.locationText = "Lorem"
        #expect(!draft.isEmpty)
        draft.locationText = ""
        addPhotos([0], to: draft)
        #expect(!draft.isEmpty)
    }

    @Test func touchBumpsUpdatedAtOnly() {
        let created = Date(timeIntervalSince1970: 1_000)
        let draft = Draft(now: created)
        draft.touch(now: created.addingTimeInterval(60))
        #expect(draft.createdAt == created)
        #expect(draft.updatedAt == created.addingTimeInterval(60))
    }
}
