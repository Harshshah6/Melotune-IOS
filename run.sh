#!/usr/bin/env bash
#
# Build, install and launch Melotune on an iOS simulator in one step.
#
# Usage:
#   ./run.sh                     # uses "iPhone 17 Pro"
#   ./run.sh "iPhone Air"        # pick any available simulator
#   ./run.sh --list              # show available devices
#
set -euo pipefail
cd "$(dirname "$0")"

DEVICE="${1:-iPhone 17 Pro}"
BUNDLE_ID="com.harsh.shah.melotune"

if [[ "$DEVICE" == "--list" ]]; then
  xcrun simctl list devices available | grep -E "iPhone|iPad"
  exit 0
fi

echo "Building for '$DEVICE'…"
xcodebuild \
  -project Melotune.xcodeproj \
  -scheme Melotune \
  -sdk iphonesimulator \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath build \
  build | grep -E "BUILD (SUCCEEDED|FAILED)|error:" || true

APP="build/Build/Products/Debug-iphonesimulator/Melotune.app"
if [[ ! -d "$APP" ]]; then
  echo "Build failed: $APP not found" >&2
  exit 1
fi

echo "Booting '$DEVICE'…"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator

echo "Installing…"
xcrun simctl install "$DEVICE" "$APP"

echo "Launching…"
xcrun simctl launch "$DEVICE" "$BUNDLE_ID"

echo "Done. Melotune is also on the home screen of '$DEVICE'."
