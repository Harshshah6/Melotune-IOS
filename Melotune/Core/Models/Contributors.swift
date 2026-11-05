import Foundation

/// Port of the Android `model.aboutus.Contributors`.
struct Contributors: Codable {
    let contributors: [Contributor]?

    struct Contributor: Codable, Identifiable {
        let login: String?
        let avatar_url: String?
        let html_url: String?

        var id: String { login ?? html_url ?? UUID().uuidString }
        var name: String { login ?? "" }
        var avatar: String { avatar_url ?? "" }
        var profile: String { html_url ?? "" }
    }
}
