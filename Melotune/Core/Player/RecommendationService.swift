import Foundation

/// Port of the Android `RecommendationManager`.
enum RecommendationService {

    /// Song recommendations. Strategy: song suggestions → primary artist top songs → search.
    static func recommendations(for song: Song, limit: Int = 15) async -> [Song] {
        guard let songId = song.id, !songId.isEmpty else { return [] }
        let api = ApiClient.shared

        if let response = try? await api.retrieveSongSuggestions(songId, limit: limit),
           response.success == true,
           let data = response.data {
            let suggestions = data.filter { $0.id != songId }
            if !suggestions.isEmpty {
                return Array(suggestions.prefix(limit))
            }
        }

        if let artistId = song.artists?.primary?.first?.id, !artistId.isEmpty,
           let response = try? await api.retrieveArtistSongs(artistId, page: 0, sortBy: .popularity, sortOrder: .desc),
           response.success == true,
           let songs = response.data?.songs {
            let filtered = songs.filter { $0.id != song.id }
            if !filtered.isEmpty {
                return Array(filtered.prefix(limit))
            }
        }

        let query = song.artists?.primary?.first?.name
            ?? song.language
            ?? song.displayName
        if let response = try? await api.searchSongs(query, page: 0, limit: limit + 5),
           response.success == true,
           let results = response.data?.results {
            let filtered = results.filter { $0.id != song.id }
            if !filtered.isEmpty {
                return Array(filtered.prefix(limit))
            }
        }

        return []
    }

    struct HomeSection {
        let title: String
        let subtitle: String
        let items: [MediaItemModel]
    }

    /// Personalized home recommendations based on recent activity, or trending seeds.
    static func homePersonalized() async -> HomeSection {
        let prefs = Preferences.shared
        let api = ApiClient.shared

        if let artistId = prefs.lastPlayedArtistId, let artistName = prefs.lastPlayedArtistName,
           !artistId.isEmpty, !artistName.isEmpty {
            if let response = try? await api.retrieveArtistSongs(artistId, page: 0, sortBy: .popularity, sortOrder: .desc),
               response.success == true,
               let songs = response.data?.songs, !songs.isEmpty {
                let items = songs.prefix(15).map { song in
                    MediaItemModel(
                        id: song.id,
                        title: song.displayName,
                        subtitle: "\(song.language ?? "") \(song.year ?? "")".trimmingCharacters(in: .whitespaces),
                        image: song.artworkURL
                    )
                }
                return HomeSection(title: "Recommended For You", subtitle: "Because you listened to \(artistName)", items: items)
            }
            return await trending()
        }

        if let first = prefs.recentlyPlayed.first {
            let query = first.title.isEmpty ? "Hits" : first.title
            if let response = try? await api.searchSongs(query, page: 0, limit: 15),
               response.success == true,
               let results = response.data?.results, !results.isEmpty {
                let items = results.map { song in
                    MediaItemModel(
                        id: song.id,
                        title: song.displayName,
                        subtitle: "\(song.language ?? "") \(song.year ?? "")".trimmingCharacters(in: .whitespaces),
                        image: song.artworkURL
                    )
                }
                return HomeSection(title: "Recommended For You", subtitle: "Based on \(first.title)", items: items)
            }
            return await trending()
        }

        return await trending()
    }

    private static func trending() async -> HomeSection {
        let queries = ["Trending", "Hits", "Top Songs", "Featured", "Romance"]
        let query = queries.randomElement() ?? "Trending"
        if let response = try? await ApiClient.shared.searchSongs(query, page: 0, limit: 15),
           response.success == true,
           let results = response.data?.results, !results.isEmpty {
            let items = results.map { song in
                MediaItemModel(
                    id: song.id,
                    title: song.displayName,
                    subtitle: "\(song.language ?? "") \(song.year ?? "")".trimmingCharacters(in: .whitespaces),
                    image: song.artworkURL
                )
            }
            return HomeSection(title: "Made For You", subtitle: "Trending Hits", items: items)
        }
        return HomeSection(title: "Made For You", subtitle: "Curated Selection", items: [])
    }
}
