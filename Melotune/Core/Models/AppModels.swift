import Foundation

/// Mirrors the Android `AlbumItem` used as a generic list cell model.
struct MediaItemModel: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let image: String

    init(id: String?, title: String?, subtitle: String?, image: String?) {
        self.id = id ?? ""
        self.title = title ?? ""
        self.subtitle = subtitle ?? ""
        self.image = image ?? ""
    }
}

/// Mirrors the Android `SavedLibraries` record (user + album libraries).
struct SavedLibrary: Codable, Identifiable {
    var id: String
    var isCreatedByUser: Bool
    var isAlbum: Bool
    var name: String
    var image: String
    var description: String
    var songs: [SavedSong]

    struct SavedSong: Codable, Identifiable, Hashable {
        var id: String
        var title: String
        var description: String
        var image: String
    }
}

/// The four global search result categories.
enum SearchCategory: String, CaseIterable, Identifiable {
    case songs = "Songs"
    case albums = "Albums"
    case artists = "Artists"
    case playlists = "Playlists"

    var id: String { rawValue }
}

/// Home screen language filter chips, matching the Android chip group.
enum HomeLanguage: String, CaseIterable, Identifiable {
    case all = "All"
    case hindi = "Hindi"
    case english = "English"
    case punjabi = "Punjabi"
    case tamil = "Tamil"
    case telugu = "Telugu"
    case malayalam = "Malayalam"
    case kannada = "Kannada"
    case bhojpuri = "Bhojpuri"
    case gujarati = "Gujarati"
    case marathi = "Marathi"
    case bengali = "Bengali"

    var id: String { rawValue }
}
