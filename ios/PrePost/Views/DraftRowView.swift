import SwiftData
import SwiftUI
import UIKit

struct DraftRowView: View {
    let draft: Draft

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(draft.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(draft.caption.isEmpty ? .secondary : .primary)
                Text(photoSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(draft.updatedAt, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
            statusBadge
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = draft.orderedPhotos.first?.localThumbnail, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "photo.on.rectangle").foregroundStyle(.secondary)
                }
        }
    }

    private var photoSummary: String {
        switch draft.postKind {
        case nil: "No photos"
        case .single: "Single image"
        case .carousel: "Carousel · \(draft.photos.count)"
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch draft.status {
        case .editing:
            EmptyView()
        case .publishing:
            Label("Publishing", systemImage: "arrow.up.circle")
                .labelStyle(.iconOnly)
                .foregroundStyle(.blue)
                .accessibilityLabel("Publishing")
        case .failed:
            Label("Failed", systemImage: "exclamationmark.circle.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(.red)
                .accessibilityLabel("Publish failed")
        }
    }
}

#Preview {
    let drafts = (try? ModelContainer.preview.mainContext.fetch(FetchDescriptor<Draft>())) ?? []
    List(drafts) { DraftRowView(draft: $0) }
        .modelContainer(.preview)
}
