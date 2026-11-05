import SwiftUI

/// Navigation destination for album / playlist / artist screens.
enum DetailTarget: Hashable {
    case album(id: String, title: String)
    case playlist(id: String, title: String)
    case artist(id: String, title: String)
}

/// Album / playlist / artist card. Equivalent to the Android `ActivityMain*Adapter` cells.
struct MediaCard: View {
    let item: MediaItemModel
    var width: CGFloat = 148

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RemoteImage(urlString: item.image, cornerRadius: 14)
                .frame(width: width, height: width)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .foregroundStyle(.primary)

            if !item.subtitle.isEmpty {
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
    }
}

/// Circular artist avatar.
struct ArtistCard: View {
    let item: MediaItemModel
    var width: CGFloat = 118

    var body: some View {
        VStack(spacing: 8) {
            RemoteImage(urlString: item.image, cornerRadius: width / 2)
                .frame(width: width, height: width)
            Text(item.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: width)
        }
        .frame(width: width)
    }
}

/// A titled horizontal carousel of cards, matching the Android home sections.
struct HorizontalSection<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var onSeeMore: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3.weight(.bold))
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let onSeeMore {
                    Button("See all", action: onSeeMore)
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    content()
                }
                .padding(.horizontal, 20)
            }
        }
    }
}
