import Foundation

// MARK: - Shared primitives

struct JImage: Codable {
    let quality: String?
    let url: String?
}

struct JDownloadUrl: Codable {
    let quality: String?
    let url: String?
}

struct ArtistEntry: Codable {
    let id: String?
    let name: String?
    let url: String?
    let role: String?
    let type: String?
    let image: [JImage]?
}

struct ArtistSet: Codable {
    let primary: [ArtistEntry]?
    let featured: [ArtistEntry]?
    let all: [ArtistEntry]?
}

// MARK: - Song

struct Song: Codable, Identifiable {
    let id: String?
    let name: String?
    let type: String?
    let year: String?
    let releaseDate: String?
    let duration: Double?
    let label: String?
    let explicitContent: Bool?
    let playCount: Int?
    let language: String?
    let hasLyrics: Bool?
    let lyricsId: String?
    let lyrics: Lyrics?
    let url: String?
    let copyright: String?
    let album: AlbumRef?
    let artists: ArtistSet?
    let image: [JImage]?
    let downloadUrl: [JDownloadUrl]?

    var displayName: String { HtmlText.parse(name) }

    /// Highest resolution artwork URL, matching the Android `image.last().url` behaviour.
    var artworkURL: String? { image?.last?.url }

    struct Lyrics: Codable {
        let lyrics: String?
        let copyright: String?
        let snippet: String?
    }

    struct AlbumRef: Codable {
        let id: String?
        let name: String?
        let url: String?
    }
}

// MARK: - Song endpoints

struct SongResponse: Codable {
    let success: Bool?
    let data: [Song]?
}

struct SongSearch: Codable {
    let success: Bool?
    let data: Data?

    struct Data: Codable {
        let total: Int?
        let start: Int?
        let results: [Song]?
    }
}

struct LyricsSearch: Codable {
    let success: Bool?
    let data: Data?

    struct Data: Codable {
        let lyrics: String?
        let copyright: String?
        let snippet: String?
    }
}

// MARK: - Albums

struct AlbumsSearch: Codable {
    let success: Bool?
    let data: Data?

    struct Data: Codable {
        let total: Int?
        let start: Int?
        let results: [Result]?
    }

    struct Result: Codable {
        let id: String?
        let name: String?
        let description: String?
        let url: String?
        let year: Int?
        let type: String?
        let playCount: Int?
        let language: String?
        let explicitContent: Bool?
        let artists: ArtistSet?
        let image: [JImage]?

        var displayName: String { HtmlText.parse(name) }
        var artworkURL: String? { image?.last?.url }
    }
}

struct AlbumSearch: Codable {
    let success: Bool?
    let data: Data?

    struct Data: Codable {
        let id: String?
        let name: String?
        let url: String?
        let description: String?
        let year: Int?
        let playCount: Int?
        let language: String?
        let explicitContent: Bool?
        let artists: ArtistSet?
        let image: [JImage]?
        let songs: [Song]?

        var displayName: String { HtmlText.parse(name) }
        var artworkURL: String? { image?.last?.url }
    }
}

// MARK: - Artists

struct ArtistsSearch: Codable {
    let success: Bool?
    let data: Data?

    struct Data: Codable {
        let total: Int?
        let start: Int?
        let results: [Result]?
    }

    struct Result: Codable {
        let id: String?
        let name: String?
        let role: String?
        let type: String?
        let url: String?
        let image: [JImage]?

        var displayName: String { HtmlText.parse(name) }
        var artworkURL: String? { image?.last?.url }
    }
}

struct ArtistSearch: Codable {
    let success: Bool?
    let data: Data?

    struct Data: Codable {
        let id: String?
        let name: String?
        let url: String?
        let type: String?
        let followerCount: Int?
        let fanCount: Int?
        let isVerified: Bool?
        let dominantLanguage: String?
        let dominantType: String?
        let bio: [Bio]?
        let image: [JImage]?
        let topSongs: [Song]?
        let topAlbums: [AlbumsSearch.Result]?
        let singles: [Song]?
        let similarArtists: [SimilarArtist]?

        var displayName: String { HtmlText.parse(name) }
        var artworkURL: String? { image?.last?.url }

        struct Bio: Codable {
            let text: String?
            let title: String?
            let sequence: Int?
        }

        struct SimilarArtist: Codable {
            let id: String?
            let name: String?
        }
    }
}

struct ArtistAllSongs: Codable {
    let success: Bool?
    let data: Data?

    struct Data: Codable {
        let total: Int?
        let songs: [Song]?
    }
}

struct ArtistAllAlbum: Codable {
    let success: Bool?
    let data: Data?

    struct Data: Codable {
        let total: Int?
        let albums: [AlbumsSearch.Result]?
    }
}

// MARK: - Playlists

struct PlaylistsSearch: Codable {
    let success: Bool?
    let data: Data?

    struct Data: Codable {
        let total: Int?
        let start: Int?
        let results: [Result]?
    }

    struct Result: Codable {
        let id: String?
        let name: String?
        let type: String?
        let url: String?
        let image: [JImage]?
        let songCount: Int?
        let language: String?
        let explicitContent: Bool?

        var displayName: String { HtmlText.parse(name) }
        var artworkURL: String? { image?.last?.url }
    }
}

struct PlaylistSearch: Codable {
    let success: Bool?
    let data: Data?

    struct Data: Codable {
        let id: String?
        let name: String?
        let url: String?
        let description: String?
        let type: String?
        let year: Int?
        let playCount: Int?
        let songCount: Int?
        let language: String?
        let explicitContent: Bool?
        let artists: [ArtistEntry]?
        let image: [JImage]?
        let songs: [Song]?

        var displayName: String { HtmlText.parse(name) }
        var artworkURL: String? { image?.last?.url }
    }
}

// MARK: - Global search

struct GlobalSearch: Codable {
    let success: Bool?
    let data: Data?

    struct Data: Codable {
        let topQuery: Section<TopQueryResult>?
        let songs: Section<SongResult>?
        let albums: Section<AlbumResult>?
        let artists: Section<ArtistResult>?
        let playlists: Section<PlaylistResult>?
    }

    struct Section<T: Codable>: Codable {
        let results: [T]?
        let position: Int?
    }

    struct TopQueryResult: Codable {
        let id: String?
        let title: String?
        let image: [JImage]?
        let url: String?
        let type: String?
        let description: String?

        var displayTitle: String { HtmlText.parse(title) }
        var artworkURL: String? { image?.last?.url }
    }

    struct SongResult: Codable {
        let id: String?
        let title: String?
        let image: [JImage]?
        let album: String?
        let url: String?
        let type: String?
        let description: String?
        let primaryArtists: String?
        let singers: String?
        let language: String?

        var displayTitle: String { HtmlText.parse(title) }
        var artworkURL: String? { image?.last?.url }
    }

    struct AlbumResult: Codable {
        let id: String?
        let title: String?
        let image: [JImage]?
        let artist: String?
        let url: String?
        let type: String?
        let description: String?
        let year: String?
        let songIds: String?
        let language: String?

        var displayTitle: String { HtmlText.parse(title) }
        var artworkURL: String? { image?.last?.url }
    }

    struct ArtistResult: Codable {
        let id: String?
        let title: String?
        let image: [JImage]?
        let type: String?
        let description: String?

        var displayTitle: String { HtmlText.parse(title) }
        var artworkURL: String? { image?.last?.url }
    }

    struct PlaylistResult: Codable {
        let id: String?
        let title: String?
        let image: [JImage]?
        let url: String?
        let type: String?
        let language: String?
        let description: String?

        var displayTitle: String { HtmlText.parse(title) }
        var artworkURL: String? { image?.last?.url }
    }
}
