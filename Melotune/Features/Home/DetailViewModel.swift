import Foundation
import Observation

@Observable
@MainActor
final class DetailViewModel {
    let target: DetailTarget

    var title = ""
    var subtitle = ""
    var image = ""
    var songs: [MediaItemModel] = []
    var albums: [MediaItemModel] = []
    var singles: [MediaItemModel] = []
    var isLoading = true

    init(target: DetailTarget) {
        self.target = target
    }

    // MARK: - Save to library

    /// Albums and playlists can be saved; artists cannot (matches Android `ListActivity`).
    var supportsLibrary: Bool {
        switch target {
        case .album, .playlist: return true
        case .artist: return false
        }
    }

    private var libraryId: String? {
        switch target {
        case .album(let id, _), .playlist(let id, _): return id
        case .artist: return nil
        }
    }

    private var isAlbum: Bool {
        if case .album = target { return true }
        return false
    }

    var isInLibrary: Bool {
        guard let libraryId else { return false }
        return Preferences.shared.savedLibraries.contains { $0.id == libraryId }
    }

    @discardableResult
    func saveToLibrary() -> Bool {
        guard supportsLibrary, let id = libraryId else { return false }
        guard !isInLibrary else { return true }
        let library = SavedLibrary(
            id: id,
            isCreatedByUser: false,
            isAlbum: isAlbum,
            name: title,
            image: image,
            description: subtitle,
            songs: songs.map {
                SavedLibrary.SavedSong(id: $0.id, title: $0.title, description: $0.subtitle, image: $0.image)
            }
        )
        Preferences.shared.addLibrary(library)
        return true
    }

    func removeFromLibrary() {
        guard let libraryId else { return }
        Preferences.shared.removeLibrary(id: libraryId)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        switch target {
        case .album(let id, let fallbackTitle):
            await loadAlbum(id: id, fallbackTitle: fallbackTitle)
        case .playlist(let id, let fallbackTitle):
            await loadPlaylist(id: id, fallbackTitle: fallbackTitle)
        case .artist(let id, let fallbackTitle):
            await loadArtist(id: id, fallbackTitle: fallbackTitle)
        }
    }

    private func loadAlbum(id: String, fallbackTitle: String) async {
        guard let response = try? await ApiClient.shared.retrieveAlbumById(id), let data = response.data else {
            title = fallbackTitle
            return
        }
        title = data.displayName.isEmpty ? fallbackTitle : data.displayName
        image = data.artworkURL ?? ""
        let artists = data.artist?.all?.compactMap { $0.name }.joined(separator: ", ") ?? ""
        subtitle = [artists, data.year.map(String.init), "\(data.songs?.count ?? 0) songs"]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
        songs = (data.songs ?? []).map(Self.mediaItem(from:))
    }

    private func loadPlaylist(id: String, fallbackTitle: String) async {
        guard let response = try? await ApiClient.shared.retrievePlaylistById(id), let data = response.data else {
            title = fallbackTitle
            return
        }
        title = data.displayName.isEmpty ? fallbackTitle : data.displayName
        image = data.artworkURL ?? ""
        let artists = data.artists?.compactMap { $0.name }.joined(separator: ", ") ?? ""
        subtitle = [artists, "\(data.songs?.count ?? data.songCount ?? 0) songs"]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
        songs = (data.songs ?? []).map(Self.mediaItem(from:))
    }

    private func loadArtist(id: String, fallbackTitle: String) async {
        guard let response = try? await ApiClient.shared.retrieveArtistById(id), let data = response.data else {
            title = fallbackTitle
            return
        }
        title = data.displayName.isEmpty ? fallbackTitle : data.displayName
        image = data.artworkURL ?? ""
        subtitle = data.dominantLanguage ?? ""
        songs = (data.topSongs ?? []).map(Self.mediaItem(from:))
        albums = (data.topAlbums ?? []).compactMap(Self.mediaItem(from:))
        singles = (data.singles ?? []).compactMap(Self.mediaItem(from:))
    }

    private static func mediaItem(from song: Song) -> MediaItemModel {
        let artists = song.artists?.all?.compactMap { $0.name }.joined(separator: ", ") ?? ""
        return MediaItemModel(
            id: song.id,
            title: song.displayName,
            subtitle: artists.isEmpty
                ? "\(song.language ?? "") \(song.year ?? "")".trimmingCharacters(in: .whitespaces)
                : artists,
            image: song.artworkURL
        )
    }

    private static func mediaItem(from album: AlbumsSearch.Result) -> MediaItemModel? {
        guard let id = album.id else { return nil }
        return MediaItemModel(
            id: id,
            title: album.displayName,
            subtitle: "\(album.language ?? "") \(album.year.map(String.init) ?? "")".trimmingCharacters(in: .whitespaces),
            image: album.artworkURL
        )
    }
}
