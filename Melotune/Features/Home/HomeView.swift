import SwiftUI

struct HomeView: View {
    var onOpenSearch: () -> Void = {}

    @Environment(AudioPlayer.self) private var player
    @State private var model = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    languageChips
                    sections
                }
                .padding(.vertical, 12)
            }
            .withMiniPlayer()
            .navigationTitle("Melotune")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onOpenSearch()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .navigationDestination(for: DetailTarget.self) { target in
                DetailView(target: target)
            }
            .refreshable { await model.refresh() }
        }
        .task { await model.refresh() }
    }

    // MARK: - Language chips

    private var languageChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HomeLanguage.allCases) { language in
                    let selected = model.language == language
                    Button {
                        guard model.language != language else { return }
                        model.language = language
                        Task { await model.refresh() }
                    } label: {
                        Text(language.rawValue)
                            .font(.subheadline.weight(selected ? .semibold : .regular))
                            .foregroundStyle(selected ? Color.white : Theme.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                    .glassSurface(
                        in: Capsule(),
                        tint: selected ? Theme.accent : nil,
                        interactive: true
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var sections: some View {
        if !model.recentlyPlayed.isEmpty {
            songRow("Recently Played", items: model.recentlyPlayed)
        }

        if model.isLoading && !model.hasNewReleases {
            skeleton
        } else {
            if !model.recommended.isEmpty {
                songRow(model.recommendedTitle, subtitle: model.recommendedSubtitle, items: model.recommended)
            }

            if !model.popularSongs.isEmpty {
                songRow("Popular Songs", items: model.popularSongs)
            }

            if !model.popularArtists.isEmpty {
                HorizontalSection(title: "Popular Artists") {
                    ForEach(model.popularArtists) { artist in
                        NavigationLink(value: DetailTarget.artist(id: artist.id, title: artist.title)) {
                            ArtistCard(item: artist)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !model.popularAlbums.isEmpty {
                HorizontalSection(title: "Popular Albums") {
                    ForEach(model.popularAlbums) { album in
                        NavigationLink(value: DetailTarget.album(id: album.id, title: album.title)) {
                            MediaCard(item: album)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !model.playlists.isEmpty {
                HorizontalSection(title: "Playlists") {
                    ForEach(model.playlists) { list in
                        NavigationLink(value: DetailTarget.playlist(id: list.id, title: list.title)) {
                            MediaCard(item: list)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func songRow(_ title: String, subtitle: String? = nil, items: [MediaItemModel]) -> some View {
        HorizontalSection(title: title, subtitle: subtitle) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button {
                    player.setQueue(items.map { $0.id }, startAt: index)
                } label: {
                    MediaCard(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var skeleton: some View {
        HorizontalSection(title: "Loading…") {
            ForEach(0..<6, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 14).fill(.quaternary).frame(width: 148, height: 148)
                    RoundedRectangle(cornerRadius: 4).fill(.quaternary).frame(width: 110, height: 12)
                    RoundedRectangle(cornerRadius: 4).fill(.quaternary).frame(width: 70, height: 10)
                }
                .frame(width: 148, alignment: .leading)
            }
        }
    }
}
