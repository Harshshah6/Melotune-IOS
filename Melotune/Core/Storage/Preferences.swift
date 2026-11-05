import Foundation
import Observation

/// Port of the Android `SharedPreferenceManager` + `SettingsSharedPrefManager`.
/// Uses the same logical keys and default values so the two apps behave identically.
@Observable
final class Preferences {
    static let shared = Preferences()

    private enum Key {
        // settings prefs (Android "settings" SharedPreferences)
        static let downloadOverCellular = "download_over_cellular"
        static let highQualityTrack = "high_quality_track"
        static let storeInCache = "store_in_cache"
        static let explicit = "explicit"
        static let playInBackground = "play_in_background"
        static let downloadFormat = "download_format"
        static let theme = "theme"
        static let gestures = "player_gestures"
        static let tapLyrics = "tap_album_lyrics_toggle"
        static let themePalette = "theme_palette"
        // cache prefs (Android Room key/value store)
        static let trackQuality = "track_quality"
        static let homeLanguage = "home_language_filter"
        static let autoplay = "autoplay_recommendations"
        static let likedSongs = "user_liked_songs"
        static let recentlyPlayed = "user_recently_played_songs"
        static let savedLibraries = "saved_libraries"
        static let lastArtistId = "last_played_artist_id"
        static let lastArtistName = "last_played_artist_name"
        // search history
        static let searchHistory = "queries"
    }

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private static let maxHistory = 8
    private static let maxRecentlyPlayed = 30

    // MARK: - Settings

    var trackQuality: String { didSet { defaults.set(trackQuality, forKey: Key.trackQuality) } }
    var homeLanguage: String { didSet { defaults.set(homeLanguage, forKey: Key.homeLanguage) } }
    var isAutoplayEnabled: Bool { didSet { defaults.set(isAutoplayEnabled, forKey: Key.autoplay) } }
    var playInBackground: Bool { didSet { defaults.set(playInBackground, forKey: Key.playInBackground) } }
    var downloadOverCellular: Bool { didSet { defaults.set(downloadOverCellular, forKey: Key.downloadOverCellular) } }
    var highQualityTrack: Bool { didSet { defaults.set(highQualityTrack, forKey: Key.highQualityTrack) } }
    var storeInCache: Bool { didSet { defaults.set(storeInCache, forKey: Key.storeInCache) } }
    var explicitContent: Bool { didSet { defaults.set(explicitContent, forKey: Key.explicit) } }
    var playerGestures: Bool { didSet { defaults.set(playerGestures, forKey: Key.gestures) } }
    var tapAlbumLyricsToggle: Bool { didSet { defaults.set(tapAlbumLyricsToggle, forKey: Key.tapLyrics) } }
    var downloadFormat: String { didSet { defaults.set(downloadFormat, forKey: Key.downloadFormat) } }
    var theme: String { didSet { defaults.set(theme, forKey: Key.theme) } }
    var themePalette: String { didSet { defaults.set(themePalette, forKey: Key.themePalette) } }

    // MARK: - Collections

    private(set) var recentlyPlayed: [SavedLibrary.SavedSong] { didSet { persist(recentlyPlayed, Key.recentlyPlayed) } }
    private(set) var likedSongs: [SavedLibrary.SavedSong] { didSet { persist(likedSongs, Key.likedSongs) } }
    var savedLibraries: [SavedLibrary] { didSet { persist(savedLibraries, Key.savedLibraries) } }
    private(set) var searchHistory: [String] { didSet { defaults.set(searchHistory, forKey: Key.searchHistory) } }

    var lastPlayedArtistId: String? { didSet { defaults.set(lastPlayedArtistId, forKey: Key.lastArtistId) } }
    var lastPlayedArtistName: String? { didSet { defaults.set(lastPlayedArtistName, forKey: Key.lastArtistName) } }

    private init() {
        let d = UserDefaults.standard
        trackQuality = d.string(forKey: Key.trackQuality) ?? "320kbps"
        homeLanguage = d.string(forKey: Key.homeLanguage) ?? "All"
        isAutoplayEnabled = d.object(forKey: Key.autoplay) as? Bool ?? true
        playInBackground = d.object(forKey: Key.playInBackground) as? Bool ?? true
        downloadOverCellular = d.object(forKey: Key.downloadOverCellular) as? Bool ?? true
        highQualityTrack = d.object(forKey: Key.highQualityTrack) as? Bool ?? true
        storeInCache = d.object(forKey: Key.storeInCache) as? Bool ?? true
        explicitContent = d.object(forKey: Key.explicit) as? Bool ?? true
        playerGestures = d.object(forKey: Key.gestures) as? Bool ?? true
        tapAlbumLyricsToggle = d.object(forKey: Key.tapLyrics) as? Bool ?? true
        downloadFormat = d.string(forKey: Key.downloadFormat) ?? "m4a"
        theme = d.string(forKey: Key.theme) ?? "system"
        themePalette = d.string(forKey: Key.themePalette) ?? "emerald"

        recentlyPlayed = Self.load([SavedLibrary.SavedSong].self, from: d.string(forKey: Key.recentlyPlayed), decoder: JSONDecoder()) ?? []
        likedSongs = Self.load([SavedLibrary.SavedSong].self, from: d.string(forKey: Key.likedSongs), decoder: JSONDecoder()) ?? []
        savedLibraries = Self.load([SavedLibrary].self, from: d.string(forKey: Key.savedLibraries), decoder: JSONDecoder()) ?? []
        searchHistory = d.stringArray(forKey: Key.searchHistory) ?? []
        lastPlayedArtistId = d.string(forKey: Key.lastArtistId)
        lastPlayedArtistName = d.string(forKey: Key.lastArtistName)
    }

    // MARK: - Recently played

    func addRecentlyPlayed(_ song: SavedLibrary.SavedSong, artistId: String? = nil, artistName: String? = nil) {
        guard !song.id.isEmpty else { return }
        var list = recentlyPlayed.filter { $0.id != song.id }
        list.insert(song, at: 0)
        if list.count > Self.maxRecentlyPlayed {
            list = Array(list.prefix(Self.maxRecentlyPlayed))
        }
        recentlyPlayed = list
        if let artistId, !artistId.isEmpty { lastPlayedArtistId = artistId }
        if let artistName, !artistName.isEmpty { lastPlayedArtistName = artistName }
    }

    // MARK: - Liked songs

    func isSongLiked(_ id: String?) -> Bool {
        guard let id else { return false }
        return likedSongs.contains { $0.id == id }
    }

    @discardableResult
    func toggleLikedSong(_ song: SavedLibrary.SavedSong) -> Bool {
        if let index = likedSongs.firstIndex(where: { $0.id == song.id }) {
            likedSongs.remove(at: index)
            return false
        }
        likedSongs.insert(song, at: 0)
        return true
    }

    // MARK: - Saved libraries

    func addLibrary(_ library: SavedLibrary) {
        var list = savedLibraries
        if let index = list.firstIndex(where: { $0.id == library.id }) {
            list[index] = library
        } else {
            list.insert(library, at: 0)
        }
        savedLibraries = list
    }

    func removeLibrary(id: String) {
        savedLibraries.removeAll { $0.id == id }
    }

    // MARK: - Search history

    func addSearchQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var history = searchHistory.filter { $0 != trimmed }
        history.insert(trimmed, at: 0)
        if history.count > Self.maxHistory {
            history = Array(history.prefix(Self.maxHistory))
        }
        searchHistory = history
    }

    func clearSearchHistory() {
        searchHistory = []
    }

    // MARK: - Helpers

    private func persist<T: Encodable>(_ value: T, _ key: String) {
        guard let data = try? encoder.encode(value), let json = String(data: data, encoding: .utf8) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(json, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, from json: String?, decoder: JSONDecoder) -> T? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? decoder.decode(type, from: data)
    }
}
