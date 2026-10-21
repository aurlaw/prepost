import Foundation
import SwiftData

@Model
final class Draft {
    /// Also the publish idempotency key (W3).
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    /// Bump with `touch()` on every edit.
    var updatedAt: Date
    var caption: String = ""
    /// Context for caption generation only.
    var note: String = ""
    /// Never sent to Instagram; copied to the clipboard after publishing.
    var locationText: String = ""
    var statusRaw: String = DraftStatus.editing.rawValue
    var publishJobId: String?
    var lastError: String?
    var category: Category?
    /// Unordered — use `orderedPhotos`.
    @Relationship(deleteRule: .cascade, inverse: \DraftPhoto.draft)
    var photos: [DraftPhoto] = []

    init(id: UUID = UUID(), now: Date = .now) {
        self.id = id
        self.createdAt = now
        self.updatedAt = now
    }

    var status: DraftStatus {
        get { DraftStatus(rawValue: statusRaw) ?? .editing }
        set { statusRaw = newValue.rawValue }
    }

    /// SwiftData relationship arrays have no stable order; `sortIndex` does.
    var orderedPhotos: [DraftPhoto] {
        photos.sorted { $0.sortIndex < $1.sortIndex }
    }

    var postKind: PostKind? {
        switch photos.count {
        case 0: nil
        case 1: .single
        default: .carousel
        }
    }

    /// First non-blank line of the caption, else "Untitled draft".
    var displayTitle: String {
        caption
            .split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
            ?? "Untitled draft"
    }

    /// No text in any field and no photos.
    var isEmpty: Bool {
        photos.isEmpty
            && [caption, note, locationText].allSatisfy {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
    }

    func touch(now: Date = .now) {
        updatedAt = now
    }
}
