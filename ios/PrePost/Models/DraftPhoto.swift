import Foundation
import SwiftData

@Model
final class DraftPhoto {
    @Attribute(.unique) var id: UUID
    var sortIndex: Int
    /// Set after upload (A2).
    var r2Key: String?
    /// Set after upload (A2).
    var remoteURL: URL?
    /// Of the uploaded (resized) image.
    var width: Int = 0
    var height: Int = 0
    var uploadStateRaw: String = PhotoUploadState.pending.rawValue
    /// Small JPEG shown before the upload completes.
    @Attribute(.externalStorage) var localThumbnail: Data?
    var draft: Draft?

    init(id: UUID = UUID(), sortIndex: Int) {
        self.id = id
        self.sortIndex = sortIndex
    }

    var uploadState: PhotoUploadState {
        get { PhotoUploadState(rawValue: uploadStateRaw) ?? .pending }
        set { uploadStateRaw = newValue.rawValue }
    }
}
