import SwiftUI

/// Root shell. Uses the native TabView so the tab bar picks up Liquid Glass chrome
/// automatically on iOS 26. The mini player is attached per screen via
/// `withMiniPlayer()` so it never covers content.
struct RootView: View {
    @Environment(Preferences.self) private var prefs
    @State private var selection = RootView.initialTab()
    @State private var showDebugPlayer = RootView.hasLaunchFlag("-openPlayer")
    @State private var debugAlbumId = RootView.launchValue("-openAlbum")
    @State private var showDebugAlbum = RootView.launchValue("-openAlbum") != nil
    @State private var showDebugAbout = RootView.hasLaunchFlag("-openAbout")

    private static func hasLaunchFlag(_ flag: String) -> Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains(flag)
        #else
        return false
        #endif
    }

    private static func launchValue(_ key: String) -> String? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: key), index + 1 < args.count { return args[index + 1] }
        #endif
        return nil
    }

    /// Debug-only: `-startTab N` opens a specific tab so screenshots/UI checks can target
    /// it without tapping. Ignored in release builds.
    private static func initialTab() -> Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-startTab"), index + 1 < args.count,
           let tab = Int(args[index + 1]) {
            return tab
        }
        #endif
        return 0
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView(onOpenSearch: { selection = 1 })
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(1)

            LibraryView()
                .tabItem { Label("Library", systemImage: "square.stack.fill") }
                .tag(2)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .preferredColorScheme(colorScheme)
        .fullScreenCover(isPresented: $showDebugPlayer) { NowPlayingView() }
        .sheet(isPresented: $showDebugAlbum) {
            if let id = debugAlbumId {
                NavigationStack { DetailView(target: .album(id: id, title: "Album")) }
            }
        }
        .sheet(isPresented: $showDebugAbout) {
            NavigationStack { AboutView() }
        }
    }

    private var colorScheme: ColorScheme? {
        switch prefs.theme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
