import SwiftUI

/// Persistent mini player. Port of the Android `MiniPlayerHelper`: artwork, title,
/// play/pause, next, and a colour-adaptive progress bar, floating on Liquid Glass.
struct MiniPlayerView: View {
    @Environment(AudioPlayer.self) private var player
    @State private var showFullPlayer = false

    var body: some View {
        if let track = player.currentTrack {
            VStack(spacing: 0) {
                progressBar
                HStack(spacing: 12) {
                    RemoteImage(urlString: track.artworkURL, cornerRadius: 8)
                        .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.displayName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(artistLine(track))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)

                    Button {
                        player.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.body)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 10)
            }
            .glassSurface(in: RoundedRectangle(cornerRadius: 16, style: .continuous), interactive: true)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
            .onTapGesture { showFullPlayer = true }
            .fullScreenCover(isPresented: $showFullPlayer) {
                NowPlayingView()
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: max(0, progress * geo.size.width))
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    private var progress: CGFloat {
        guard player.duration > 0 else { return 0 }
        return CGFloat(min(max(player.currentTime / player.duration, 0), 1))
    }

    private func artistLine(_ track: Song) -> String {
        let artists = track.artists?.all?.compactMap { $0.name }.joined(separator: ", ") ?? ""
        return artists.isEmpty ? (track.language ?? "Melotune") : artists
    }
}
