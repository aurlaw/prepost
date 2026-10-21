import Foundation
import SwiftData

/// App-local organisation only — never sent to the Worker or Instagram.
@Model
final class Category {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var name: String
    /// e.g. `#0FA3A3`
    var colorHex: String
    var sortIndex: Int
    /// Deleting a category leaves its drafts uncategorised.
    @Relationship(deleteRule: .nullify, inverse: \Draft.category)
    var drafts: [Draft] = []

    init(id: UUID = UUID(), name: String, colorHex: String, sortIndex: Int) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.sortIndex = sortIndex
    }
}
