import SwiftUI

/// Full-screen player. Port of the Android `MusicOverviewActivity`: adaptive artwork,
/// swipe-to-skip gesture, scrubbable progress, transport controls, shuffle/repeat,
/// a 3-dot "more" menu (quality, speed, album, queue, like) and an accessible queue.
struct NowPlayingView: View {
    @Environment(AudioPlayer.self) private var player
    @Environment(Preferences.self) private var prefs
    @Environment(\.dismiss) private var dismiss
    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0
    @State private var showQueue = false
    @State private var showAlbum = false
    @State private var dragOffset: CGFloat = 0
    @State private var lyrics: [LrcLine] = []
    @State private var lyricsSynced = false
    @State private var lyricsLoading = false
    @State private var hasLyrics = false
    @State private var showLyrics = false

    private let qualities = ["320kbps", "160kbps", "96kbps", "48kbps", "12kbps"]
    private let speeds: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer(minLength: 8)
                    lyricsOrArtwork
                    titleBlock
                    progressBlock
                    transportControls
                    actionRow
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 28)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down").font(.headline)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    moreMenu
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showQueue) { QueueView() }
            .task(id: player.currentTrack?.id) { await loadLyrics() }
            .navigationDestination(isPresented: $showAlbum) {
                if let album = player.currentTrack?.album, let id = album.id {
                    DetailView(target: .album(id: id, title: HtmlText.parse(album.name)))
                }
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Theme.accent.opacity(0.35), Color.black.opacity(0.9)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - 3-dot menu

    private var moreMenu: some View {
        Menu {
            Button { showQueue = true } label: {
                Label("Play Queue", systemImage: "list.bullet")
            }
            Button { toggleLike() } label: {
                Label(isLiked ? "Remove from Liked Songs" : "Add to Liked Songs",
                      systemImage: isLiked ? "heart.fill" : "heart")
            }
            if let album = player.currentTrack?.album, album.id != nil {
                Button { showAlbum = true } label: {
                    Label("Go to Album", systemImage: "square.stack")
                }
            }
            Button {
                player.playNext(id: player.currentTrack?.id ?? "")
            } label: {
                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            Button {
                player.addToQueue(id: player.currentTrack?.id ?? "")
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }

            Divider()

            Menu {
                Picker("Quality", selection: qualityBinding) {
                    ForEach(qualities, id: \.self) { Text($0).tag($0) }
                }
            } label: {
                Label("Track Quality (\(prefs.trackQuality))", systemImage: "waveform.badge.magnifyingglass")
            }

            Menu {
                Picker("Speed", selection: speedBinding) {
                    ForEach(speeds, id: \.self) { Text(speedLabel($0)).tag($0) }
                }
            } label: {
                Label("Playback Speed", systemImage: "gauge.with.dots.needle.50percent")
            }
        } label: {
            Image(systemName: "ellipsis.circle").font(.headline)
        }
    }

    private var qualityBinding: Binding<String> {
        Binding(
            get: { prefs.trackQuality },
            set: { newValue in
                prefs.trackQuality = newValue
                if let id = player.currentTrack?.id { player.playTrack(id: id) }
            }
        )
    }

    private var speedBinding: Binding<Float> {
        Binding(get: { player.playbackSpeed }, set: { player.playbackSpeed = $0 })
    }

    private func speedLabel(_ speed: Float) -> String {
        speed == Float(Int(speed)) ? String(format: "%.1fx", speed) : String(format: "%.2fx", speed)
    }

    // MARK: - Lyrics

    private var lyricsOrArtwork: some View {
        Group {
            if showLyrics {
                LyricsView(
                    lines: lyrics,
                    synced: lyricsSynced,
                    currentTime: player.currentTime,
                    isLoading: lyricsLoading,
                    onSeek: { player.seek(to: $0) }
                )
                .frame(maxWidth: .infinity)
                .frame(height: 340)
            } else {
                artwork
            }
        }
    }

    private func toggleLyrics() {
        guard hasLyrics else { return }
        withAnimation(.easeInOut(duration: 0.2)) { showLyrics.toggle() }
    }

    private func loadLyrics() async {
        guard let track = player.currentTrack else {
            lyrics = []
            hasLyrics = false
            showLyrics = false
            return
        }
        lyricsLoading = true
        let result = await LyricsService.lyrics(for: track)
        guard !Task.isCancelled else { return }
        lyrics = result?.lines ?? []
        lyricsSynced = result?.synced ?? false
        hasLyrics = !lyrics.isEmpty
        lyricsLoading = false
        if !hasLyrics { showLyrics = false }
        #if DEBUG
        if hasLyrics, ProcessInfo.processInfo.arguments.contains("-showLyrics") { showLyrics = true }
        #endif
    }

    // MARK: - Artwork

    private var artwork: some View {
        RemoteImage(urlString: player.currentTrack?.artworkURL, cornerRadius: 24)
            .aspectRatio(1, contentMode: .fit)
            .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
            .scaleEffect(1 - min(abs(dragOffset) / 1200, 0.06))
            .offset(x: dragOffset)
            .gesture(skipGesture)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: dragOffset)
            .overlay(alignment: .bottomTrailing) {
                if hasLyrics {
                    Image(systemName: "quote.bubble.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(8)
                        .glassSurface(in: Circle(), interactive: true)
                        .padding(10)
                }
            }
            .onTapGesture {
                if prefs.tapAlbumLyricsToggle { toggleLyrics() }
            }
    }

    private var skipGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard prefs.playerGestures else { return }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                guard prefs.playerGestures else { return }
                if value.translation.width < -80 {
                    player.next()
                } else if value.translation.width > 80 {
                    player.previous()
                }
                withAnimation { dragOffset = 0 }
            }
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text(player.currentTrack?.displayName ?? "Not Playing")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(artistLine)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
    }

    private var progressBlock: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubValue : player.currentTime },
                    set: { scrubValue = $0 }
                ),
                in: 0...max(player.duration, 1)
            ) { editing in
                if editing {
                    isScrubbing = true
                    scrubValue = player.currentTime
                } else {
                    player.seek(to: scrubValue)
                    isScrubbing = false
                }
            }
            .tint(.white)

            HStack {
                Text(timeString(isScrubbing ? scrubValue : player.currentTime))
                Spacer()
                Text("-" + timeString(max(0, player.duration - (isScrubbing ? scrubValue : player.currentTime))))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var transportControls: some View {
        HStack(spacing: 34) {
            Button {
                player.isShuffleEnabled.toggle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundStyle(player.isShuffleEnabled ? Theme.accent : .white)
            }

            Button { player.previous() } label: {
                Image(systemName: "backward.fill").font(.title)
            }

            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 68))
            }

            Button { player.next() } label: {
                Image(systemName: "forward.fill").font(.title)
            }

            Button {
                player.repeatMode = nextRepeatMode
            } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.title3)
                    .foregroundStyle(player.repeatMode == .off ? .white : Theme.accent)
            }
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private var actionRow: some View {
        HStack(spacing: 28) {
            Button { toggleLike() } label: {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .foregroundStyle(isLiked ? Theme.accent : .white)
            }

            Button { toggleLyrics() } label: {
                Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                    .foregroundStyle(showLyrics ? Theme.accent : .white)
            }
            .disabled(!hasLyrics)
            .opacity(hasLyrics ? 1 : 0.35)

            if let urlString = player.currentTrack?.url, let url = URL(string: urlString) {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up").foregroundStyle(.white)
                }
            }

            Spacer()

            if player.isBuffering {
                Text("Buffering…").font(.caption).foregroundStyle(.white.opacity(0.6))
                Spacer()
            }

            Button { showQueue = true } label: {
                Image(systemName: "list.bullet").foregroundStyle(.white)
            }
        }
        .font(.title3)
        .buttonStyle(.plain)
    }

    private var nextRepeatMode: AudioPlayer.RepeatMode {
        switch player.repeatMode {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }

    private var isLiked: Bool {
        prefs.isSongLiked(player.currentTrack?.id)
    }

    private func toggleLike() {
        guard let track = player.currentTrack else { return }
        prefs.toggleLikedSong(
            SavedLibrary.SavedSong(
                id: track.id ?? "",
                title: track.displayName,
                description: artistLine,
                image: track.artworkURL ?? ""
            )
        )
    }

    private var artistLine: String {
        guard let track = player.currentTrack else { return "" }
        let artists = track.artists?.all?.compactMap { $0.name }.joined(separator: ", ") ?? ""
        return artists.isEmpty ? (track.language ?? "") : artists
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
