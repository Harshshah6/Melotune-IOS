import Foundation

/// Port of the Android lyrics flow: fetch synchronized lyrics from LrcLib
/// (`lrclib.net`), falling back to the Melotune API's plain lyrics.
enum LyricsService {
    struct Result {
        let lines: [LrcLine]
        let synced: Bool
    }

    private struct LrcLibTrack: Codable {
        let id: Int?
        let trackName: String?
        let artistName: String?
        let duration: Double?
        let plainLyrics: String?
        let syncedLyrics: String?
    }

    static func lyrics(for song: Song) async -> Result? {
        if let synced = await syncedLyrics(for: song) {
            let lines = LrcParser.parse(synced)
            if !lines.isEmpty, lines.contains(where: { $0.isSynced }) {
                return Result(lines: lines, synced: true)
            }
        }

        if let id = song.id,
           let response = try? await ApiClient.shared.retrieveLyricsById(id),
           let text = response.data?.lyrics, !text.isEmpty {
            let parsed = LrcParser.parse(text)
            if !parsed.isEmpty {
                return Result(lines: parsed, synced: parsed.contains(where: { $0.isSynced }))
            }
        }

        if let inline = song.lyrics?.lyrics, !inline.isEmpty {
            let parsed = LrcParser.parse(inline)
            if !parsed.isEmpty {
                return Result(lines: parsed, synced: parsed.contains(where: { $0.isSynced }))
            }
        }

        return nil
    }

    // MARK: - LrcLib

    private static func syncedLyrics(for song: Song) async -> String? {
        let title = song.displayName
        guard !title.isEmpty else { return nil }
        let artist = song.artists?.primary?.first?.name
            ?? song.artists?.all?.first?.name
            ?? ""

        let duration = Int(song.duration ?? 0)

        // First try with the artist (most precise), then fall back to title only, which
        // catches cases where the API's primary artist differs from the track artist.
        if let match = await search(title: title, artist: artist, album: song.album?.name, duration: duration) {
            return match
        }
        if !artist.isEmpty {
            return await search(title: title, artist: nil, album: nil, duration: duration)
        }
        return nil
    }

    private static func search(title: String, artist: String?, album: String?, duration: Int) async -> String? {
        var components = URLComponents(string: "https://lrclib.net/api/search")
        var items = [URLQueryItem(name: "track_name", value: title)]
        if let artist, !artist.isEmpty {
            items.append(URLQueryItem(name: "artist_name", value: artist))
        }
        if let album, !album.isEmpty {
            items.append(URLQueryItem(name: "album_name", value: HtmlText.parse(album)))
        }
        components?.queryItems = items
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Melotune iOS (https://github.com/harshshah6/Melotune-IOS)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let tracks = try? JSONDecoder().decode([LrcLibTrack].self, from: data) else {
            return nil
        }

        let synced = tracks.filter { $0.syncedLyrics != nil }
        guard !synced.isEmpty else { return nil }

        // Prefer the closest duration match (±2s), matching the Android `bestMatchingFor`.
        if duration > 0,
           let match = synced.first(where: { abs(Int($0.duration ?? 0) - duration) <= 2 }) {
            return match.syncedLyrics
        }
        return synced.first?.syncedLyrics
    }
}
