import Foundation
import Observation

@Observable
@MainActor
final class SearchViewModel {
    var query = ""
    var category: SearchCategory = .songs

    private(set) var songs: [MediaItemModel] = []
    private(set) var albums: [MediaItemModel] = []
    private(set) var artists: [MediaItemModel] = []
    private(set) var playlists: [MediaItemModel] = []
    private(set) var isLoading = false
    private(set) var hasSearched = false

    var history: [String] { Preferences.shared.searchHistory }

    var currentResults: [MediaItemModel] {
        switch category {
        case .songs: return songs
        case .albums: return albums
        case .artists: return artists
        case .playlists: return playlists
        }
    }

    func submit(_ text: String? = nil) async {
        if let text { query = text }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Preferences.shared.addSearchQuery(trimmed)
        isLoading = true
        hasSearched = true
        defer { isLoading = false }

        guard let response = try? await ApiClient.shared.globalSearch(trimmed),
              response.success == true, let data = response.data else { return }

        songs = (data.songs?.results ?? []).map { result in
            MediaItemModel(
                id: result.id,
                title: result.displayTitle,
                subtitle: [result.primaryArtists, result.singers, result.album]
                    .compactMap { $0 }.first { !$0.isEmpty } ?? "",
                image: result.artworkURL
            )
        }
        albums = (data.albums?.results ?? []).map { result in
            MediaItemModel(id: result.id, title: result.displayTitle, subtitle: result.artist ?? "", image: result.artworkURL)
        }
        artists = (data.artists?.results ?? []).map { result in
            MediaItemModel(id: result.id, title: result.displayTitle, subtitle: result.description ?? "", image: result.artworkURL)
        }
        playlists = (data.playlists?.results ?? []).map { result in
            MediaItemModel(id: result.id, title: result.displayTitle, subtitle: result.description ?? "", image: result.artworkURL)
        }
    }

    func clearHistory() {
        Preferences.shared.clearSearchHistory()
    }

    func reset() {
        query = ""
        hasSearched = false
    }
}
