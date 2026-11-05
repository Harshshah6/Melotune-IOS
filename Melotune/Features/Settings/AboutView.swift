import SwiftUI

/// Port of the Android `AboutActivity`: app info, links and GitHub contributors.
struct AboutView: View {
    @State private var contributors: [Contributors.Contributor] = []

    private let version = "1.0.22"

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                linksSection
                contributorsSection
                footer
            }
            .padding(.vertical, 20)
        }
        .withMiniPlayer()
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadContributors() }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 92, height: 92)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            Text("Melotune").font(.title.weight(.bold))
            Text("Free, ad-free music streaming and offline listening. No account required.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("Version \(version)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var linksSection: some View {
        VStack(spacing: 0) {
            linkRow("Email", systemImage: "envelope", url: "mailto:harshsandeep23@gmail.com", utm: nil)
            Divider().padding(.leading, 52)
            linkRow("Source Code", systemImage: "chevron.left.forwardslash.chevron.right",
                    url: "https://github.com/harshshah6/Melotune-IOS", utm: ("about", "source_code"))
            Divider().padding(.leading, 52)
            linkRow("Website", systemImage: "globe",
                    url: "https://harshshah6.github.io/melotune-web/", utm: ("about", "website"))
            Divider().padding(.leading, 52)
            linkRow("Instagram", systemImage: "camera",
                    url: "https://www.instagram.com/harsh_.s._shah/", utm: nil)
            Divider().padding(.leading, 52)
            linkRow("Telegram", systemImage: "paperplane",
                    url: "https://t.me/mel0tune", utm: nil)
            Divider().padding(.leading, 52)
            linkRow("Rate on GitHub", systemImage: "star",
                    url: "https://github.com/harshshah6/Melotune-IOS", utm: ("about", "rate"))
        }
        .glassSurface(in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func linkRow(_ title: String, systemImage: String, url: String, utm: (String, String)?) -> some View {
        let resolved = utm.map { url.withUtm(campaign: $0.0, content: $0.1) } ?? url
        Link(destination: URL(string: resolved) ?? URL(string: "https://melotune.harshbits.com")!) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .frame(width: 24)
                    .foregroundStyle(Theme.accent)
                Text(title).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private var contributorsSection: some View {
        if !contributors.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Contributors").font(.headline).padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(contributors) { contributor in
                            Link(destination: URL(string: contributor.profile.withUtm(campaign: "about", content: "contributor")) ?? URL(string: "https://github.com")!) {
                                VStack(spacing: 8) {
                                    RemoteImage(urlString: contributor.avatar, cornerRadius: 30)
                                        .frame(width: 60, height: 60)
                                    Text(contributor.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .frame(width: 76)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private var footer: some View {
        Text("Melotune is not affiliated with JioSaavn. Licensed under the MIT License.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }

    private func loadContributors() async {
        guard let response = try? await ApiClient.shared.contributors() else { return }
        contributors = response.contributors ?? []
    }
}

private extension String {
    /// Matches the Android `withUtmParameters` helper (source tag differs per platform).
    func withUtm(campaign: String, content: String) -> String {
        guard var components = URLComponents(string: self),
              let scheme = components.scheme, scheme == "http" || scheme == "https" else {
            return self
        }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "utm_source", value: "melotune_ios"))
        items.append(URLQueryItem(name: "utm_medium", value: "app"))
        items.append(URLQueryItem(name: "utm_campaign", value: campaign))
        items.append(URLQueryItem(name: "utm_content", value: content))
        components.queryItems = items
        return components.url?.absoluteString ?? self
    }
}
