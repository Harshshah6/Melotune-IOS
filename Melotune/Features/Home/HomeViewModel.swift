import Foundation
import Observation

/// Home screen state. Mirrors the Android `MainActivity.showData()` flow, including the
/// randomized seed queries and the language filter, plus locally cached recently played
/// and personalized recommendations.
@Observable
@MainActor
final class HomeViewModel {
    var language: HomeLanguage {
        didSet { Preferences.shared.homeLanguage = language.rawValue }
    }

    private(set) var popularSongs: [MediaItemModel] = []
    private(set) var popularArtists: [MediaItemModel] = []
    private(set) var popularAlbums: [MediaItemModel] = []
    private(set) var playlists: [MediaItemModel] = []
    private(set) var recentlyPlayed: [MediaItemModel] = []
    private(set) var recommended: [MediaItemModel] = []
    private(set) var recommendedTitle = "Recommended For You"
    private(set) var recommendedSubtitle = ""

    private(set) var isLoading = false

    init() {
        language = HomeLanguage(rawValue: Preferences.shared.homeLanguage) ?? .all
    }

    var hasNewReleases: Bool {
        !(popularSongs.isEmpty && popularArtists.isEmpty && popularAlbums.isEmpty && playlists.isEmpty)
    }

    func refresh() async {
        loadRecentlyPlayed()
        isLoading = true
        defer { isLoading = false }

        let seeds = seeds(for: language)
        async let songs: Void = loadSongs(seeds.songs.randomElement() ?? "Hits")
        async let artists: Void = loadArtists(seeds.artists.randomElement() ?? " ")
        async let albums: Void = loadAlbums(seeds.albums.randomElement() ?? "Hits")
        async let lists: Void = loadPlaylists(seeds.playlists.randomElement() ?? "Hits")
        async let recs: Void = loadRecommendations()
        _ = await (songs, artists, albums, lists, recs)
    }

    private func loadRecentlyPlayed() {
        recentlyPlayed = Preferences.shared.recentlyPlayed.map {
            MediaItemModel(id: $0.id, title: $0.title, subtitle: $0.description, image: $0.image)
        }
    }

    private func loadSongs(_ query: String) async {
        guard let response = try? await ApiClient.shared.searchSongs(query, page: 0, limit: 15),
              response.success == true, let results = response.data?.results else { return }
        popularSongs = results.map { song in
            MediaItemModel(
                id: song.id,
                title: song.displayName,
                subtitle: "\(song.language ?? "") \(song.year ?? "")".trimmingCharacters(in: .whitespaces),
                image: song.artworkURL
            )
        }
    }

    private func loadArtists(_ query: String) async {
        guard let response = try? await ApiClient.shared.searchArtists(query, page: 0, limit: 15),
              response.success == true, let results = response.data?.results else { return }
        popularArtists = results.map { artist in
            MediaItemModel(id: artist.id, title: artist.displayName, subtitle: "", image: artist.artworkURL)
        }
    }

    private func loadAlbums(_ query: String) async {
        guard let response = try? await ApiClient.shared.searchAlbums(query, page: 0, limit: 15),
              response.success == true, let results = response.data?.results else { return }
        popularAlbums = results.map { album in
            MediaItemModel(
                id: album.id,
                title: album.displayName,
                subtitle: "\(album.language ?? "") \(album.year.map(String.init) ?? "")".trimmingCharacters(in: .whitespaces),
                image: album.artworkURL
            )
        }
    }

    private func loadPlaylists(_ query: String) async {
        guard let response = try? await ApiClient.shared.searchPlaylists(query),
              response.success == true, let results = response.data?.results else { return }
        playlists = results.map { list in
            MediaItemModel(id: list.id, title: list.displayName, subtitle: "", image: list.artworkURL)
        }
    }

    private func loadRecommendations() async {
        let section = await RecommendationService.homePersonalized()
        recommendedTitle = section.title
        recommendedSubtitle = section.subtitle
        recommended = section.items
    }

    private struct Seeds {
        let songs: [String]
        let artists: [String]
        let albums: [String]
        let playlists: [String]
    }

    private func seeds(for language: HomeLanguage) -> Seeds {
        guard language != .all else {
            return Seeds(
                songs: ["2025", "2026", "Hits", "Latest", "Romantic", "Chill", "Lo-Fi", "Dance", "Hindi", "Sad", "Love", "Workout", " "],
                artists: [" "],
                albums: ["2025", "2026", "Hits", "Latest", "New", "Sad", "Lo-Fi", "Romantic", "Rock", "Pop", "Classic", "Party", " "],
                playlists: ["2025", "2026", "Hits", "Latest", "Trending", "Party", "Devotional", "Chill", "Love", "Sad", "Top", "Classic", " "]
            )
        }
        let lang = language.rawValue
        return Seeds(
            songs: ["\(lang) Hits", "\(lang) 2026", "\(lang) Latest", "\(lang) Romantic", "\(lang) Top", lang],
            artists: [lang],
            albums: ["\(lang) Hits", "\(lang) 2026", "\(lang) Latest", lang],
            playlists: ["\(lang) Hits", "Best of \(lang)", "\(lang) Top 50", lang]
        )
    }
}
