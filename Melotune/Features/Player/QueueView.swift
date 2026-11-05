import SwiftUI

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

@Observable
@MainActor
final class QueueViewModel {
    private(set) var items: [MediaItemModel] = []
    private(set) var isLoading = false
    private var lastLoadedIds: [String] = []

    func load(ids: [String]) async {
        guard ids != lastLoadedIds else { return }
        lastLoadedIds = ids
        guard !ids.isEmpty else {
            items = []
            return
        }
        isLoading = true
        defer { isLoading = false }

        var resolved: [String: Song] = [:]
        for chunk in ids.chunked(into: 25) {
            if let response = try? await ApiClient.shared.retrieveSongsByIds(chunk.joined(separator: ",")),
               let data = response.data {
                for song in data {
                    if let id = song.id { resolved[id] = song }
                }
            }
        }

        items = ids.map { id in
            guard let song = resolved[id] else {
                return MediaItemModel(id: id, title: "Unknown track", subtitle: "", image: "")
            }
            let artists = song.artists?.all?.compactMap { $0.name }.joined(separator: ", ") ?? ""
            return MediaItemModel(id: id, title: song.displayName, subtitle: artists, image: song.artworkURL)
        }
    }
}

struct QueueView: View {
    @Environment(AudioPlayer.self) private var player
    @Environment(\.dismiss) private var dismiss
    @State private var model = QueueViewModel()

    var body: some View {
        NavigationStack {
            List {
                if model.items.isEmpty {
                    ContentUnavailableView("Queue is empty", systemImage: "list.bullet")
                } else {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        TrackRow(
                            index: index,
                            item: item,
                            isPlaying: player.currentTrack?.id == item.id,
                            showsMenu: true
                        ) {
                            player.setQueue(player.queue, startAt: index)
                            dismiss()
                        }
                        .listRowBackground(
                            index == player.queuePosition ? Theme.accent.opacity(0.15) : Color.clear
                        )
                    }
                    .onMove { source, destination in
                        player.moveInQueue(from: source, to: destination)
                        Task { await model.load(ids: player.queue) }
                    }
                    .onDelete { offsets in
                        player.removeFromQueue(at: offsets)
                        Task { await model.load(ids: player.queue) }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .task(id: player.queue) {
                await model.load(ids: player.queue)
            }
        }
    }
}
