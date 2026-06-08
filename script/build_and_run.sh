#!/bin/bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="LanScopeMac"
DISPLAY_NAME="LanScope Mac"
BUNDLE_ID="com.lanscope.mac"
MIN_SYSTEM_VERSION="14.0"
ICON_FILE="AppIcon.icns"
APP_VERSION="0.1.4"
APP_BUILD="1"
APP_COPYRIGHT="Copyright © 2026 @rootoff. All rights reserved."

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
if [[ "$SCRIPT_DIR" == "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="."
fi
cd "$SCRIPT_DIR/.."
ROOT_DIR="$PWD"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

echo "stopping existing $DISPLAY_NAME..."
pkill -x "$APP_NAME" >/dev/null 2>&1 || true

echo "building SwiftPM target..."
swift build
BUILD_DIR="$(swift build --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"

echo "staging app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

find "$BUILD_DIR" -maxdepth 1 \( -name '*.bundle' -o -name '*.resources' \) -exec cp -R {} "$APP_RESOURCES/" \;
cp "$ROOT_DIR/Resources/$ICON_FILE" "$APP_RESOURCES/$ICON_FILE"
cp "$ROOT_DIR/Resources/oui.json" "$APP_RESOURCES/oui.json"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>$ICON_FILE</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>NSHumanReadableCopyright</key>
  <string>$APP_COPYRIGHT</string>
  <key>NSLocationUsageDescription</key>
  <string>LanScope Mac uses location permission only to display nearby Wi-Fi network names and BSSIDs locally.</string>
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>LanScope Mac uses location permission only to display nearby Wi-Fi network names and BSSIDs locally.</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSQuitAlwaysKeepsWindows</key>
  <false/>
</dict>
</plist>
PLIST

echo "signing app bundle..."
find "$APP_BUNDLE" \( -name _CodeSignature -o -name CodeResources \) -prune -exec rm -rf {} +
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

open_app() {
  echo "launching $APP_BUNDLE..."
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  --bundle-only|bundle)
    echo "$APP_BUNDLE"
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--bundle-only|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
