import Foundation

/// Stored as `Draft.statusRaw`. Raw strings keep stored data readable if cases are added later.
nonisolated enum DraftStatus: String, CaseIterable, Sendable {
    case editing
    case publishing
    case failed
}

/// Stored as `DraftPhoto.uploadStateRaw`.
nonisolated enum PhotoUploadState: String, CaseIterable, Sendable {
    case pending
    case uploading
    case uploaded
    case failed
}

nonisolated enum PostKind: Equatable, Sendable {
    case single
    case carousel
}

/// Instagram publishing limits. Verified 2026-10-21 against Meta's Graph API
/// error-code reference: captions over the limit are rejected, not truncated.
nonisolated enum InstagramLimits {
    static let captionMaxCharacters = 2_200
    static let carouselMaxItems = 10
}
