import SwiftUI

/// Library tab: mirrors the Android `SavedLibrariesActivity` plus recently played and
/// liked songs kept in local storage.
struct LibraryView: View {
    @Environment(AudioPlayer.self) private var player
    @Environment(Preferences.self) private var prefs

    private var recentlyPlayed: [MediaItemModel] {
        prefs.recentlyPlayed.map { MediaItemModel(id: $0.id, title: $0.title, subtitle: $0.description, image: $0.image) }
    }

    private var liked: [MediaItemModel] {
        prefs.likedSongs.map { MediaItemModel(id: $0.id, title: $0.title, subtitle: $0.description, image: $0.image) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    songSection("Liked Songs", items: liked, emptyIcon: "heart")
                    songSection("Recently Played", items: recentlyPlayed, emptyIcon: "clock")
                    savedLibrariesSection
                }
                .padding(.vertical, 12)
            }
            .withMiniPlayer()
            .navigationTitle("Library")
            .navigationDestination(for: DetailTarget.self) { DetailView(target: $0) }
        }
    }

    @ViewBuilder
    private func songSection(_ title: String, items: [MediaItemModel], emptyIcon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.weight(.bold)).padding(.horizontal, 20)
            if items.isEmpty {
                Label("Nothing here yet", systemImage: emptyIcon)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            Button {
                                player.setQueue(items.map { $0.id }, startAt: index)
                            } label: {
                                MediaCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private var savedLibrariesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Playlists").font(.title3.weight(.bold)).padding(.horizontal, 20)
            if prefs.savedLibraries.isEmpty {
                Label("Create playlists to see them here", systemImage: "music.note.list")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            } else {
                let columns = [GridItem(.adaptive(minimum: 148), spacing: 16)]
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(prefs.savedLibraries) { library in
                        savedLibraryCard(library)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func savedLibraryCard(_ library: SavedLibrary) -> some View {
        NavigationLink(value: DetailTarget.playlist(id: library.id, title: library.name)) {
            MediaCard(
                item: MediaItemModel(
                    id: library.id,
                    title: library.name,
                    subtitle: "\(library.songs.count) songs",
                    image: library.image
                )
            )
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            Menu {
                Button {
                    let ids = library.songs.map { $0.id }.filter { !$0.isEmpty }
                    guard !ids.isEmpty else { return }
                    player.setQueue(ids, startAt: 0)
                } label: {
                    Label("Play All", systemImage: "play.fill")
                }
                Button {
                    player.isShuffleEnabled = true
                    let ids = library.songs.map { $0.id }.filter { !$0.isEmpty }.shuffled()
                    guard !ids.isEmpty else { return }
                    player.setQueue(ids, startAt: 0)
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                }
                Button(role: .destructive) {
                    prefs.removeLibrary(id: library.id)
                } label: {
                    Label("Delete Playlist", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                    .glassSurface(in: Circle(), interactive: true)
                    .padding(6)
            }
        }
    }
}
