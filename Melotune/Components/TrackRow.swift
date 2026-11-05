import SwiftUI

/// A single song row, equivalent to the Android `ActivityListSongsItemAdapter` cell.
/// The trailing 3-dot menu mirrors the Android popup ("Play Next" / "Add to Queue").
struct TrackRow: View {
    let index: Int?
    let item: MediaItemModel
    var isPlaying: Bool = false
    var showsMenu: Bool = true
    var action: () -> Void

    @Environment(AudioPlayer.self) private var player
    @Environment(Preferences.self) private var prefs

    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                HStack(spacing: 12) {
                    if let index {
                        Text("\(index + 1)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(isPlaying ? Theme.accent : .secondary)
                            .frame(width: 22, alignment: .trailing)
                    }

                    RemoteImage(urlString: item.image, cornerRadius: 8)
                        .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.body.weight(isPlaying ? .semibold : .regular))
                            .foregroundStyle(isPlaying ? Theme.accent : .primary)
                            .lineLimit(1)
                        if !item.subtitle.isEmpty {
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 4)

                    if isPlaying {
                        Image(systemName: "waveform")
                            .foregroundStyle(Theme.accent)
                            .symbolEffect(.variableColor.iterative)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showsMenu {
                Menu {
                    Button {
                        player.playNext(id: item.id)
                    } label: {
                        Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                    Button {
                        player.addToQueue(id: item.id)
                    } label: {
                        Label("Add to Queue", systemImage: "text.badge.plus")
                    }
                    Button {
                        toggleLike()
                    } label: {
                        Label(isLiked ? "Remove from Liked Songs" : "Add to Liked Songs",
                              systemImage: isLiked ? "heart.fill" : "heart")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 40)
                        .contentShape(Rectangle())
                }
            }
        }
    }

    private var isLiked: Bool { prefs.isSongLiked(item.id) }

    private func toggleLike() {
        prefs.toggleLikedSong(
            SavedLibrary.SavedSong(id: item.id, title: item.title, description: item.subtitle, image: item.image)
        )
    }
}
