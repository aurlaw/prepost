import Foundation
import SwiftData

/// The single place drafts are deleted, from the list's swipe action, the
/// editor's menu, and the empty-draft cleanup.
///
/// A1 deletes locally only (photos cascade). A2 extends this to delete the
/// draft's uploaded photos from R2 (`DELETE /media/:key`) as well.
enum DraftDeletion {
    static func delete(_ draft: Draft, in context: ModelContext) {
        context.delete(draft)
        try? context.save()
    }
}
