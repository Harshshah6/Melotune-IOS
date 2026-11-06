# Handoff / working context

Context for whoever (or whichever session) picks this repo up next.

## What this repo is

A native **SwiftUI** iOS app that mirrors the Android app
[Melotune / SaavnMp3-Android](https://github.com/harshshah6/SaavnMp3-Android)
feature-for-feature. It talks to the same API
(`https://melotune.harshbits.com/api/`) with the same endpoints and query parameters —
the ports are deliberate line-by-line translations of the Kotlin sources.

It was extracted from the `ios/` folder of the Android repo into its own repository so the
two can be versioned, built and released independently. The Android app was never modified.

## Current state

**Working and verified** (built, launched, and screenshotted on an iOS 26.5 simulator):

- Home browse: language chips, Popular Songs/Artists/Albums, Playlists, Recently Played,
  "Recommended For You"
- Search with recent-query history and Songs/Albums/Artists/Playlists filters
- Album / playlist / artist detail with **save to library** (bookmark)
- Playback (AVPlayer): queue-of-ids model, quality selection, shuffle/repeat, autoplay,
  lock-screen controls
- Mini player + full player (artwork swipe-to-skip, scrubbing, 3-dot menu)
- Reorderable queue
- **Synced lyrics** from LrcLib (highlight + auto-scroll + tap-to-seek)
- Liked songs / recently played / saved playlists
- Caching & offline: disk API response cache with offline fallback, artwork URLCache,
  and a 300 MB audio cache so played tracks work offline (Settings → Storage to clear)
- Settings: quality, language, downloads, theme mode, accent palette
- About screen with links + GitHub contributors
- Liquid Glass surfaces, with `.ultraThinMaterial` fallback below iOS 26

**Not ported yet** — see the "Not yet ported" list in `README.md`. The big one is the
**download / offline manager** (Android uses FFmpegKit + JAudioTagger; iOS needs
`AVAssetExportSession` + a tagger such as TagLib).

## Ground rules that matter

- **Xcode 26+ is mandatory.** The Liquid Glass APIs live in the iOS 26 SDK; an older SDK
  fails to compile even though the calls are wrapped in `#available(iOS 26, *)`.
- **Verify visually with the debug launch flags**, not by tapping. The headless sandbox has
  no way to synthesise taps (`osascript` assistive access is denied). Flags:
  `-startTab N`, `-autoplayId <songId>`, `-openPlayer`, `-showLyrics`, `-openAlbum <id>`,
  `-openArtist <id>`, `-openAbout`, `-offlineMode`. They are `#if DEBUG` and ignored in release.
- **A simulator only shows apps installed on that device.** `simctl install` onto the same
  device you have open, or the icon will be missing.
- Leave the Android repo alone — this app is additive.

## Quick commands

```bash
./run.sh                                  # build + install + launch on iPhone 17 Pro
./run.sh "iPhone Air"                     # pick a device
./run.sh --list

# health check
xcodebuild -project Melotune.xcodeproj -scheme Melotune \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build

# release (what CI does)
xcodebuild -project Melotune.xcodeproj -scheme Melotune -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
```

## Getting set up again

```bash
git init && git add -A && git commit -m "Melotune iOS 1.0.22"
git remote add origin https://github.com/harshshah6/Melotune-IOS.git
git push -u origin main
git tag v1.0.22 && git push origin v1.0.22   # triggers the release workflow
```
