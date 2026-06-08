#!/bin/bash
set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
if [[ "$SCRIPT_DIR" == "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="."
fi
cd "$SCRIPT_DIR/.."
ROOT_DIR="$PWD"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/LanScope Mac.app"
DMG_PATH="$DIST_DIR/LanScope Mac.dmg"
DMG_RW_PATH="$DIST_DIR/LanScope Mac.rw.dmg"
STAGING_DIR="$DIST_DIR/dmg-staging"
ICON_FILE="$ROOT_DIR/Resources/AppIcon.icns"
BACKGROUND_FILE="$ROOT_DIR/Resources/DMGBackground.png"
VOLUME_NAME="LanScope Mac"

if [[ ! -x "$APP_BUNDLE/Contents/MacOS/LanScopeMac" ]]; then
  echo "app bundle missing, building it first..."
  /bin/bash ./script/build_and_run.sh --bundle-only
else
  echo "using existing app bundle: $APP_BUNDLE"
fi

echo "staging DMG contents..."
rm -rf "$STAGING_DIR" "$DMG_PATH" "$DMG_RW_PATH"
mkdir -p "$STAGING_DIR/.background"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
codesign --verify --deep --strict --verbose=2 "$STAGING_DIR/LanScope Mac.app"
cp README.md INSTALL.md LICENSE PRIVACY.md "$STAGING_DIR/"
cp "$ICON_FILE" "$STAGING_DIR/.VolumeIcon.icns"
cp "$BACKGROUND_FILE" "$STAGING_DIR/.background/DMGBackground.png"
ln -s /Applications "$STAGING_DIR/Applications"

echo "creating read-write DMG..."
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDRW \
  "$DMG_RW_PATH" >/dev/null

echo "mounting DMG for Finder layout..."
MOUNT_OUTPUT="$(hdiutil attach -readwrite -nobrowse "$DMG_RW_PATH")"
MOUNT_POINT="$(printf '%s\n' "$MOUNT_OUTPUT" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')"

cleanup_mount() {
  if [[ -n "${MOUNT_POINT:-}" ]] && mount | grep -Fq "on $MOUNT_POINT "; then
    hdiutil detach "$MOUNT_POINT" >/dev/null || hdiutil detach "$MOUNT_POINT" -force >/dev/null || true
  fi
}
trap cleanup_mount EXIT

if command -v SetFile >/dev/null 2>&1; then
  SetFile -a C "$MOUNT_POINT"
fi

echo "applying Finder layout..."
if ! osascript <<OSA
with timeout of 10 seconds
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {120, 120, 780, 540}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 96
    try
      set background picture of theViewOptions to (POSIX file "$MOUNT_POINT/.background/DMGBackground.png")
    end try
    set position of item "LanScope Mac.app" of container window to {190, 225}
    set position of item "Applications" of container window to {470, 225}
    set position of item "README.md" of container window to {190, 335}
    set position of item "INSTALL.md" of container window to {330, 335}
    set position of item "PRIVACY.md" of container window to {470, 335}
    set position of item "LICENSE" of container window to {330, 425}
    delay 1
    close
  end tell
end tell
end timeout
OSA
then
  echo "warning: Finder DMG layout automation failed; continuing with packaged files" >&2
fi

sync
echo "detaching DMG..."
hdiutil detach "$MOUNT_POINT" >/dev/null || hdiutil detach "$MOUNT_POINT" -force >/dev/null
MOUNT_POINT=""
trap - EXIT

echo "compressing DMG..."
hdiutil convert "$DMG_RW_PATH" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH" >/dev/null

rm -f "$DMG_RW_PATH"

echo "applying DMG file icon..."
if command -v Rez >/dev/null 2>&1 && command -v SetFile >/dev/null 2>&1; then
  ICON_RESOURCE_FILE="$DIST_DIR/dmg-file-icon.r"
  printf "read 'icns' (-16455) \"Resources/AppIcon.icns\";\n" > "$ICON_RESOURCE_FILE"
  Rez "$ICON_RESOURCE_FILE" -append -o "$DMG_PATH"
  SetFile -a C "$DMG_PATH"
  rm -f "$ICON_RESOURCE_FILE"
else
  echo "warning: Rez or SetFile not found; DMG file will keep the default Finder icon" >&2
fi

rm -rf "$STAGING_DIR"
echo "$DMG_PATH"
