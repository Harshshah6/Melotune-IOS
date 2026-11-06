# Melotune for iOS

A free, ad-free music streaming and offline-listening app for iOS, built with SwiftUI and
**Liquid Glass**. It is the iOS counterpart to
[Melotune for Android](https://github.com/harshshah6/SaavnMp3-Android) and talks to the
**same** Melotune / JioSaavn API (`https://melotune.harshbits.com/api/`) with the same
endpoints and query parameters, so both apps surface the same catalogue and behaviour.

Source: **https://github.com/harshshah6/Melotune-IOS**

## Why a separate app (and not Kotlin Multiplatform)

Real **Liquid Glass** is an Apple SwiftUI/UIKit material — Compose Multiplatform does not
produce it. Because the iOS UI had to be native SwiftUI anyway, this app shares the API
contract and feature behaviour, not code. That keeps the shipping Android app at zero risk
of regression.

## Requirements

- **Xcode 26 or newer** (built and verified with Xcode 26.5, iOS 26.5 simulator).
  The Liquid Glass APIs are part of the iOS 26 SDK, so an older Xcode will not compile.
- Deployment target: iOS 18.0. Liquid Glass surfaces light up automatically on iOS 26+ and
  fall back to `.ultraThinMaterial` on iOS 18–25.
- No third-party dependencies — artwork uses `AsyncImage`, playback uses `AVPlayer`.

## Build & run

Open the project and press Run (Xcode handles the simulator and install):

```bash
open Melotune.xcodeproj
```

Or build, install and launch from the terminal in one step:

```bash
./run.sh                      # defaults to "iPhone 17 Pro"
./run.sh "iPhone Air"         # any available simulator
./run.sh --list               # list devices
```

Manual build:

```bash
xcodebuild -project Melotune.xcodeproj -scheme Melotune \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

A simulator only shows apps installed on **that** device, so install onto the device you
have open: `xcrun simctl install "iPhone 17 Pro" <path-to-Melotune.app>`.

## Releases

`.github/workflows/ios-release.yml` builds the app on every version tag (`v*`) and attaches
an **unsigned `.ipa`** plus a zipped `.app` to the GitHub release.

```bash
git tag v1.0.22
git push origin v1.0.22
```

The archive is **unsigned** because code signing needs your Apple developer certificate,
which is not stored in the repository. To install it on a device, re-sign it with your own
certificate (Xcode, [AltStore](https://altstore.io), [Sideloadly](https://sideloadly.io),
etc.) or build from source.

## Architecture

```
Melotune/
  MelotuneApp.swift            App entry, injects shared state
  Core/
    API/ApiClient.swift        Port of Android ApiManager (same endpoints/params)
    Models/Models.swift        Codable ports of the Android `records` package
    Models/HtmlText.swift      Port of TextParserUtil.parseHtmlText
    Models/Lyrics.swift        LRC / plain lyrics parser
    Player/AudioPlayer.swift   Port of MusicPlayerManager (AVPlayer + queue + lock screen)
    Player/RecommendationService.swift  Port of RecommendationManager
    Player/LyricsService.swift Port of the lrclib lyrics flow (LrcLib + API fallback)
    Storage/Preferences.swift  Port of SharedPreferenceManager + settings keys
  Features/
    RootView.swift             TabView shell + persistent mini player
    Home/                      Home browse + album/playlist/artist detail
    Search/                    Global search with history + category filters
    Library/                   Liked, recently played, saved playlists
    Player/                    Mini player, full player, lyrics, queue
    Settings/                  Track quality, language, theme, About
  Components/                  Cards, rows, artwork loader
  Theme/Theme.swift            Liquid Glass surfaces (iOS 26) with material fallback
```

## Feature parity

Ported:

- Home browse with language filter chips and randomized seed queries
- Popular songs / artists / albums / playlists carousels
- Personalized "Recommended For You" + Recently Played
- Global search with recent-query history and category filters
- Album / playlist / artist detail screens, with **save to library** (bookmark toggle)
- Playback: queue-of-ids model, stream-quality selection, shuffle/repeat, autoplay
- Mini player + full player with artwork swipe-to-skip and scrubbing
- 3-dot overflow menus (track rows, album/playlist cards, player screen)
- **Synchronized LRC lyrics** from LrcLib with active-line highlight and tap-to-seek
- Reorderable queue
- Lock-screen / Control Centre controls and now-playing metadata
- Liked songs, recently played, saved playlists
- Settings: quality, language, downloads, **theme mode (system/light/dark)** and
  **accent palette** (emerald, ocean, purple, crimson, amber)
- About screen with links and GitHub contributors

Not yet ported (Android-only subsystems that need iOS equivalents):

- **Downloads / offline manager** — Android uses FFmpegKit + JAudioTagger; iOS needs an
  `AVAssetExportSession`/TagLib-based pipeline.
- **Home-screen widgets** — Android AppWidgets; iOS equivalent is WidgetKit.
- **Deep links** for `jiosaavn.com` share URLs (`DeepLinkingActivity`).
- **Playlist create/import/export** JSON backup (saving existing albums/playlists works).
- **Sleep timer**, equalizer, update checker, AMOLED/Material-You dynamic colour.

## Caching & offline

- **API responses** are cached on disk (`Library/Caches/api-cache`) and served as a fallback
  whenever a request fails, so browsing, search and detail screens keep working offline.
  Mirrors the Android app's cached responses.
- **Artwork** uses a large shared `URLCache` (64 MB memory / 256 MB disk) that persists
  between launches.
- **Audio** streams are also downloaded into `Library/Caches/audio-cache` (300 MB LRU) while
  they play, so tracks that have been played work offline. This is skipped on cellular
  connections and when "Store in cache" is off.
- **Settings → Storage** shows the cache size and clears it.

## Liquid Glass notes

`Theme.glassSurface` is the single place platform chrome is decided: it applies
`glassEffect` on iOS 26 and falls back to `.ultraThinMaterial` on iOS 18–25. The tab bar
and navigation bars adopt Liquid Glass automatically because the app is built against the
iOS 26 SDK.

## Debug launch flags

DEBUG builds accept these arguments (ignored in release) so screens can be driven for
screenshots and UI checks without tapping:

| Flag | Effect |
| --- | --- |
| `-startTab N` | Open tab 0=Home, 1=Search, 2=Library, 3=Settings |
| `-autoplayId <songId>` / `-autoplayDemo` | Start playback of a track |
| `-openPlayer` | Present the full-screen player |
| `-showLyrics` | Force the lyrics panel open (with `-openPlayer`) |
| `-openAlbum <albumId>` | Present an album detail screen |
| `-openAbout` | Present the About screen |
| `-openArtist <artistId>` | Present an artist detail screen |
| `-offlineMode` | Serve API responses from cache only (verify offline behaviour) |

Example:

```bash
xcrun simctl launch "iPhone 17" com.harsh.shah.melotune -openPlayer -autoplayId rjkrTnma -showLyrics
```

## Credits

- [saavn.sumit.co](https://github.com/sumitkolhe/jiosaavn-api) — the unofficial JioSaavn API.
- [LrcLib](https://lrclib.net/) — synchronized lyrics.
- The Android app, [Melotune / SaavnMp3-Android](https://github.com/harshshah6/SaavnMp3-Android),
  which this app mirrors feature-for-feature.

## License

MIT — see [LICENSE](LICENSE). Melotune is not affiliated with JioSaavn.
