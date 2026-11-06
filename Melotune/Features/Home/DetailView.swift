import SwiftUI

struct DetailView: View {
    @Environment(AudioPlayer.self) private var player
    @State private var model: DetailViewModel
    @State private var confirmRemove = false

    init(target: DetailTarget) {
        _model = State(initialValue: DetailViewModel(target: target))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                content
            }
            .padding(.bottom, 24)
        }
        .withMiniPlayer()
        .navigationTitle(model.title.isEmpty ? "Loading…" : model.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .toolbar {
            if model.supportsLibrary {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if model.isInLibrary {
                            confirmRemove = true
                        } else {
                            model.saveToLibrary()
                        }
                    } label: {
                        Image(systemName: model.isInLibrary ? "bookmark.fill" : "bookmark")
                    }
                    .tint(model.isInLibrary ? Theme.accent : nil)
                    .disabled(model.isLoading)
                }
            }
        }
        .confirmationDialog(
            "Remove from library?",
            isPresented: $confirmRemove,
            titleVisibility: .visible
        ) {
            Button("Remove from Library", role: .destructive) {
                model.removeFromLibrary()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will be removed from your Library.")
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            RemoteImage(urlString: model.image, cornerRadius: 20)
                .frame(width: 210, height: 210)
                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)

            VStack(spacing: 4) {
                Text(model.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                if !model.subtitle.isEmpty {
                    Text(model.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if !model.songs.isEmpty {
                HStack(spacing: 12) {
                    GlassButton {
                        player.setQueue(model.songs.map { $0.id }, startAt: 0)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .font(.headline)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 6)
                    }

                    GlassButton {
                        player.isShuffleEnabled = true
                        let ids = model.songs.map { $0.id }.shuffled()
                        player.setQueue(ids, startAt: 0)
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                            .font(.headline)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 6)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.songs.isEmpty {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
        } else {
            if !model.songs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(model.songs.enumerated()), id: \.offset) { index, item in
                        TrackRow(
                            index: index,
                            item: item,
                            isPlaying: player.currentTrack?.id == item.id
                        ) {
                            player.setQueue(model.songs.map { $0.id }, startAt: index)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                    }
                }
            }

            if !model.albums.isEmpty {
                HorizontalSection(title: "Albums") {
                    ForEach(model.albums) { album in
                        NavigationLink(value: DetailTarget.album(id: album.id, title: album.title)) {
                            MediaCard(item: album)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !model.singles.isEmpty {
                HorizontalSection(title: "Singles") {
                    ForEach(Array(model.singles.enumerated()), id: \.offset) { index, single in
                        Button {
                            player.setQueue(model.singles.map { $0.id }, startAt: index)
                        } label: {
                            MediaCard(item: single)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if model.songs.isEmpty && model.albums.isEmpty && model.singles.isEmpty {
                ContentUnavailableView("Nothing here", systemImage: "music.note.list")
                    .padding(.top, 40)
            }
        }
    }
}
