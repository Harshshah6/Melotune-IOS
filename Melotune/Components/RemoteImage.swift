import SwiftUI

/// Artwork loader. The Android app uses Glide; here we use `AsyncImage` so the app has
/// no third-party dependencies to fetch or install (keeps the build fully offline-capable).
struct RemoteImage: View {
    let urlString: String?
    var contentMode: ContentMode = .fill
    var cornerRadius: CGFloat = Theme.cornerSmall

    var body: some View {
        Group {
            if let urlString, !urlString.isEmpty, let url = URL(string: urlString) {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: contentMode)
                    case .failure:
                        placeholder
                    case .empty:
                        placeholder.redacted(reason: .placeholder)
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            Image(systemName: "music.note")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}
