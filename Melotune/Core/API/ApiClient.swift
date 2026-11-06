import Foundation

/// Port of the Android `ApiManager`. Talks to the same Melotune / JioSaavn REST API
/// (`https://melotune.harshbits.com/api/`) with the same query parameters.
final class ApiClient {
    static let shared = ApiClient()

    private let session: URLSession
    private let decoder = JSONDecoder()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 40
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }

    // MARK: - Endpoint constants (kept identical to ApiManager)

    static let baseURL = "https://melotune.harshbits.com/api/"
    static let searchURL = baseURL + "search"
    static let songsURL = baseURL + "songs"
    static let albumsURL = baseURL + "albums"
    static let artistsURL = baseURL + "artists"
    static let playlistsURL = baseURL + "playlists"
    static let contributorsURL = "https://androsketchui.vercel.app/api/github/harshshah6/Melotune-IOS/contributors"

    enum SortBy: String {
        case popularity, latest, alphabetical
    }

    enum SortOrder: String {
        case asc, desc
    }

    // MARK: - Search

    func globalSearch(_ query: String) async throws -> GlobalSearch {
        try await get(Self.searchURL, params: ["query": query])
    }

    func searchSongs(_ query: String, page: Int? = nil, limit: Int? = nil) async throws -> SongSearch {
        try await get(Self.searchURL + "/songs", params: params(page: page, limit: limit, query: query))
    }

    func searchAlbums(_ query: String, page: Int? = nil, limit: Int? = nil) async throws -> AlbumsSearch {
        try await get(Self.searchURL + "/albums", params: params(page: page, limit: limit, query: query))
    }

    func searchArtists(_ query: String, page: Int? = nil, limit: Int? = nil) async throws -> ArtistsSearch {
        try await get(Self.searchURL + "/artists", params: params(page: page, limit: limit, query: query))
    }

    func searchPlaylists(_ query: String, page: Int? = nil, limit: Int? = nil) async throws -> PlaylistsSearch {
        try await get(Self.searchURL + "/playlists", params: params(page: page, limit: limit, query: query))
    }

    // MARK: - Songs

    func retrieveSongsByIds(_ ids: String) async throws -> SongResponse {
        try await get(Self.songsURL, params: ["ids": ids])
    }

    func retrieveSongByLink(_ link: String) async throws -> SongResponse {
        try await get(Self.songsURL, params: ["link": link])
    }

    func retrieveSongById(_ id: String, lyrics: Bool? = nil) async throws -> SongResponse {
        var p: [String: String] = [:]
        if let lyrics { p["lyrics"] = lyrics ? "true" : "false" }
        return try await get("\(Self.songsURL)/\(id)", params: p)
    }

    func retrieveLyricsById(_ id: String) async throws -> LyricsSearch {
        try await get("\(Self.songsURL)/\(id)/lyrics", params: [:])
    }

    func retrieveSongSuggestions(_ id: String, limit: Int? = nil) async throws -> SongResponse {
        var p: [String: String] = [:]
        if let limit { p["limit"] = String(limit) }
        return try await get("\(Self.songsURL)/\(id)/suggestions", params: p)
    }

    // MARK: - Albums

    func retrieveAlbumById(_ id: String) async throws -> AlbumSearch {
        try await get(Self.albumsURL, params: ["id": id])
    }

    func retrieveAlbumByLink(_ link: String) async throws -> AlbumSearch {
        try await get(Self.albumsURL, params: ["link": link])
    }

    // MARK: - Artists

    func retrieveArtistById(
        _ id: String,
        page: Int? = nil,
        songCount: Int? = nil,
        albumCount: Int? = nil,
        sortBy: SortBy? = nil,
        sortOrder: SortOrder? = nil
    ) async throws -> ArtistSearch {
        var p: [String: String] = [:]
        if let page { p["page"] = String(page) }
        if let songCount { p["songCount"] = String(songCount) }
        if let albumCount { p["albumCount"] = String(albumCount) }
        if let sortBy { p["sortBy"] = sortBy.rawValue }
        if let sortOrder { p["sortOrder"] = sortOrder.rawValue }
        return try await get("\(Self.artistsURL)/\(id)", params: p)
    }

    func retrieveArtistSongs(
        _ id: String,
        page: Int = 0,
        sortBy: SortBy? = nil,
        sortOrder: SortOrder? = nil
    ) async throws -> ArtistAllSongs {
        var p: [String: String] = ["page": String(page < 0 ? 0 : page)]
        if let sortBy { p["sortBy"] = sortBy.rawValue }
        if let sortOrder { p["sortOrder"] = sortOrder.rawValue }
        return try await get("\(Self.artistsURL)/\(id)/songs", params: p)
    }

    func retrieveArtistAlbums(
        _ id: String,
        page: Int = 0,
        sortBy: SortBy? = nil,
        sortOrder: SortOrder? = nil
    ) async throws -> ArtistAllAlbum {
        var p: [String: String] = ["page": String(page < 0 ? 0 : page)]
        if let sortBy { p["sortBy"] = sortBy.rawValue }
        if let sortOrder { p["sortOrder"] = sortOrder.rawValue }
        return try await get("\(Self.artistsURL)/\(id)/albums", params: p)
    }

    // MARK: - Playlists

    func retrievePlaylistById(_ id: String, page: Int? = nil, limit: Int? = nil) async throws -> PlaylistSearch {
        var p: [String: String] = ["id": id]
        if let page { p["page"] = String(page) }
        if let limit { p["limit"] = String(limit) }
        return try await get(Self.playlistsURL, params: p)
    }

    func retrievePlaylistByLink(_ link: String, page: Int? = nil, limit: Int? = nil) async throws -> PlaylistSearch {
        var p: [String: String] = ["link": link]
        if let page { p["page"] = String(page) }
        if let limit { p["limit"] = String(limit) }
        return try await get(Self.playlistsURL, params: p)
    }

    // MARK: - About

    func contributors() async throws -> Contributors {
        guard let url = URL(string: Self.contributorsURL) else {
            throw ApiError.invalidURL(Self.contributorsURL)
        }
        return try await get(url)
    }

    // MARK: - Transport

    private func params(page: Int?, limit: Int?, query: String) -> [String: String] {
        var p: [String: String] = ["query": query]
        if let page { p["page"] = String(page) }
        if let limit { p["limit"] = String(limit) }
        return p
    }

    private func get<T: Decodable>(_ urlString: String, params: [String: String]) async throws -> T {
        guard var components = URLComponents(string: urlString) else {
            throw ApiError.invalidURL(urlString)
        }
        if !params.isEmpty {
            components.queryItems = params
                .sorted { $0.key < $1.key }
                .map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return try await get(components.url ?? URL(string: urlString)!)
    }

    /// Debug-only: `-offlineMode` serves responses from cache only, so offline behaviour
    /// can be verified without actually cutting the network.
    private static var isOfflineMode: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-offlineMode")
        #else
        return false
        #endif
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        if Self.isOfflineMode {
            if let cached = ResponseCache.shared.data(for: url),
               let value = try? decoder.decode(T.self, from: cached) {
                return value
            }
            throw ApiError.noResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Melotune-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        do {
            let (body, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw ApiError.noResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                throw ApiError.badStatus(http.statusCode)
            }
            data = body
        } catch {
            // Network or HTTP failure: serve the cached response so screens keep
            // working offline (mirrors the Android cached-response fallback).
            if let cached = ResponseCache.shared.data(for: url),
               let value = try? decoder.decode(T.self, from: cached) {
                return value
            }
            throw error
        }

        do {
            let value = try decoder.decode(T.self, from: data)
            ResponseCache.shared.store(data, for: url)
            return value
        } catch {
            throw ApiError.decoding(error)
        }
    }
}

enum ApiError: LocalizedError {
    case invalidURL(String)
    case noResponse
    case badStatus(Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "Invalid URL: \(url)"
        case .noResponse: return "No response from server"
        case .badStatus(let code): return "Server returned status \(code)"
        case .decoding(let error): return "Could not read response: \(error.localizedDescription)"
        }
    }
}
