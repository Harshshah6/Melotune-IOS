import SwiftUI

struct SearchView: View {
    @Environment(AudioPlayer.self) private var player
    @State private var model = SearchViewModel()
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            content
                .navigationDestination(for: DetailTarget.self) { DetailView(target: $0) }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

            if model.isLoading {
                ProgressView().padding(.top, 40)
                Spacer()
            } else if model.hasSearched {
                results
            } else {
                historyPanel
                Spacer()
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Songs, albums, artists…", text: $model.query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($fieldFocused)
                .onSubmit { Task { await model.submit() } }
            if !model.query.isEmpty {
                Button {
                    model.reset()
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassSurface(in: Capsule())
    }

    // MARK: - History

    @ViewBuilder
    private var historyPanel: some View {
        if model.history.isEmpty {
            ContentUnavailableView("Search Melotune", systemImage: "magnifyingglass", description: Text("Find songs, albums, artists and playlists."))
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent searches").font(.headline)
                    Spacer()
                    Button("Clear") { model.clearHistory() }
                        .font(.subheadline)
                }
                .padding(.horizontal, 20)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(model.history, id: \.self) { query in
                            Button {
                                model.query = query
                                Task { await model.submit(query) }
                            } label: {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
                                    Text(query).foregroundStyle(.primary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .glassSurface(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .withMiniPlayer()
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Results

    private var results: some View {
        VStack(spacing: 0) {
            Picker("Category", selection: $model.category) {
                ForEach(SearchCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 4) {
                    if model.currentResults.isEmpty {
                        ContentUnavailableView("No results", systemImage: "magnifyingglass")
                            .padding(.top, 40)
                    } else {
                        ForEach(Array(model.currentResults.enumerated()), id: \.offset) { index, item in
                            resultRow(item, index: index)
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .withMiniPlayer()
        }
    }

    @ViewBuilder
    private func resultRow(_ item: MediaItemModel, index: Int) -> some View {
        switch model.category {
        case .songs:
            TrackRow(index: nil, item: item, isPlaying: player.currentTrack?.id == item.id) {
                player.setQueue(model.songs.map { $0.id }, startAt: index)
            }
        case .albums:
            NavigationLink(value: DetailTarget.album(id: item.id, title: item.title)) {
                rowContent(item, systemImage: "square.stack")
            }
            .buttonStyle(.plain)
        case .artists:
            NavigationLink(value: DetailTarget.artist(id: item.id, title: item.title)) {
                rowContent(item, systemImage: "person")
            }
            .buttonStyle(.plain)
        case .playlists:
            NavigationLink(value: DetailTarget.playlist(id: item.id, title: item.title)) {
                rowContent(item, systemImage: "music.note.list")
            }
            .buttonStyle(.plain)
        }
    }

    private func rowContent(_ item: MediaItemModel, systemImage: String) -> some View {
        HStack(spacing: 12) {
            RemoteImage(urlString: item.image, cornerRadius: 8).frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).lineLimit(1)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: systemImage).foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}
