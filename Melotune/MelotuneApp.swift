import SwiftUI

@main
struct MelotuneApp: App {
    @State private var player = AudioPlayer.shared
    @State private var preferences = Preferences.shared

    init() {
        // Keep artwork and network responses on disk between launches.
        URLCache.shared = URLCache(memoryCapacity: 64 * 1024 * 1024, diskCapacity: 256 * 1024 * 1024)
        _ = NetworkMonitor.shared

        #if DEBUG
        // Debug-only: `-autoplayDemo` (or `-autoplayId <songId>`) starts a track so the
        // player UI can be inspected without tapping. Ignored in release builds.
        let args = ProcessInfo.processInfo.arguments
        var demoId: String?
        if let index = args.firstIndex(of: "-autoplayId"), index + 1 < args.count {
            demoId = args[index + 1]
        } else if args.contains("-autoplayDemo") {
            demoId = "qPSAZiFW"
        }
        if let demoId {
            Task { @MainActor in
                AudioPlayer.shared.setQueue([demoId], startAt: 0)
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(player)
                .environment(preferences)
                .tint(Theme.accent)
        }
    }
}
