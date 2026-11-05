import SwiftUI

/// Settings tab. Mirrors the Android `SettingsActivity` + `ThemeManager` keys so both
/// apps expose the same options: quality, background playback, language, downloads,
/// theme mode and accent palette.
struct SettingsView: View {
    @Environment(Preferences.self) private var prefs

    private let qualities = ["320kbps", "160kbps", "96kbps", "48kbps", "12kbps"]
    private let formats = ["mp3", "m4a", "ogg"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Playback") {
                    Picker("Track quality", selection: Bindable(prefs).trackQuality) {
                        ForEach(qualities, id: \.self) { Text($0).tag($0) }
                    }
                    Toggle("High quality track", isOn: Bindable(prefs).highQualityTrack)
                    Toggle("Play in background", isOn: Bindable(prefs).playInBackground)
                    Toggle("Autoplay recommendations", isOn: Bindable(prefs).isAutoplayEnabled)
                    Toggle("Player gestures", isOn: Bindable(prefs).playerGestures)
                    Toggle("Tap album art to toggle lyrics", isOn: Bindable(prefs).tapAlbumLyricsToggle)
                }

                Section("Content") {
                    Picker("Home language", selection: Bindable(prefs).homeLanguage) {
                        ForEach(HomeLanguage.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    Toggle("Show explicit content", isOn: Bindable(prefs).explicitContent)
                }

                Section("Downloads") {
                    Picker("Download format", selection: Bindable(prefs).downloadFormat) {
                        ForEach(formats, id: \.self) { Text($0.uppercased()).tag($0) }
                    }
                    Toggle("Download over cellular", isOn: Bindable(prefs).downloadOverCellular)
                    Toggle("Store in cache", isOn: Bindable(prefs).storeInCache)
                }

                Section("Appearance") {
                    Picker("Theme", selection: Bindable(prefs).theme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }

                    Picker("Accent colour", selection: Bindable(prefs).themePalette) {
                        ForEach(Theme.paletteOrder, id: \.self) { key in
                            HStack {
                                Circle()
                                    .fill(Theme.paletteColors[key] ?? Theme.accent)
                                    .frame(width: 16, height: 16)
                                Text(Theme.paletteLabel(key))
                            }
                            .tag(key)
                        }
                    }
                }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }
            }
            .withMiniPlayer()
            .navigationTitle("Settings")
        }
    }
}
