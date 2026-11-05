import SwiftUI

/// Synchronized lyrics panel. Port of the Android `MusicOverviewActivity` lyrics
/// RecyclerView: active line highlighted, auto-scrolled into view, tap to seek.
struct LyricsView: View {
    let lines: [LrcLine]
    let synced: Bool
    let currentTime: Double
    let isLoading: Bool
    let onSeek: (Double) -> Void

    private var activeIndex: Int? {
        guard synced else { return nil }
        var index: Int?
        for (i, line) in lines.enumerated() where line.time <= currentTime + 0.2 {
            index = i
        }
        return index
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView().tint(.white)
            } else if lines.isEmpty {
                ContentUnavailableView("No lyrics available", systemImage: "quote.bubble")
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                                Text(line.text.isEmpty ? "♪" : line.text)
                                    .font(.title3.weight(index == activeIndex ? .bold : .regular))
                                    .foregroundStyle(index == activeIndex ? Color.white : Color.white.opacity(0.45))
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .id(index)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if synced { onSeek(line.time) }
                                    }
                            }
                        }
                        .padding(.vertical, 28)
                        .padding(.horizontal, 20)
                    }
                    .onChange(of: activeIndex) { _, newValue in
                        guard let newValue else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
    }
}
