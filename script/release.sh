#!/bin/bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  /bin/bash ./script/release.sh <version>

Example:
  /bin/bash ./script/release.sh 0.1.2

What it does:
  - requires a clean git working tree, except optional CHANGELOG.md edits
  - updates the app version in release metadata
  - runs validation and tests
  - builds the app bundle and DMG
  - verifies the DMG checksum
  - commits the version bump
  - creates and pushes tag v<version>
  - creates a GitHub Release with the DMG, checksum, and preview image
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -ne 1 ]]; then
  usage
  exit 0
fi

VERSION="${1#v}"
TAG="v$VERSION"
export VERSION

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: version must use semantic version format, for example 0.1.2" >&2
  exit 2
fi

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
if [[ "$SCRIPT_DIR" == "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="."
fi
cd "$SCRIPT_DIR/.."
ROOT_DIR="$PWD"
DMG_PATH="$ROOT_DIR/dist/LanScope Mac.dmg"
SHA_PATH="$ROOT_DIR/dist/LanScope Mac.dmg.sha256"
NOTES_PATH="$ROOT_DIR/dist/release-notes-$TAG.md"

DIRTY_FILES="$(git status --porcelain | awk '{print $2}' | sort -u)"
if [[ -n "$DIRTY_FILES" && "$DIRTY_FILES" != "CHANGELOG.md" ]]; then
  echo "error: working tree has changes outside CHANGELOG.md. Commit or stash them before releasing." >&2
  git status --short >&2
  exit 1
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "error: local tag $TAG already exists" >&2
  exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "error: remote tag $TAG already exists" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "error: GitHub CLI (gh) is required" >&2
  exit 1
fi

gh auth status >/dev/null

echo "updating app version to $VERSION..."
perl -0pi -e 's/APP_VERSION="[0-9]+\.[0-9]+\.[0-9]+"/"APP_VERSION=\"$ENV{VERSION}\""/e' script/build_and_run.sh
perl -0pi -e 's/(CFBundleShortVersionString"\) as\? String \?\? ")[0-9]+\.[0-9]+\.[0-9]+(")/$1 . $ENV{VERSION} . $2/ge' App/AboutWindowController.swift
perl -0pi -e 's#Latest version: \[v[0-9]+\.[0-9]+\.[0-9]+\]\(https://github\.com/Dezoff-max/lanscope-mac/releases/tag/v[0-9]+\.[0-9]+\.[0-9]+\)#"Latest version: [v$ENV{VERSION}](https://github.com/Dezoff-max/lanscope-mac/releases/tag/v$ENV{VERSION})"#e' README.md

echo "running validation..."
/bin/bash ./script/validate_static.sh
swift test

echo "building app bundle and DMG..."
/bin/bash ./script/build_and_run.sh --bundle-only

BUNDLE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' 'dist/LanScope Mac.app/Contents/Info.plist')"
if [[ "$BUNDLE_VERSION" != "$VERSION" ]]; then
  echo "error: app bundle version is $BUNDLE_VERSION, expected $VERSION" >&2
  exit 1
fi

/bin/bash ./script/package_dmg.sh
shasum -a 256 "$DMG_PATH" | tee "$SHA_PATH" >/dev/null
hdiutil verify "$DMG_PATH"

echo "preparing release notes..."
mkdir -p "$ROOT_DIR/dist"
awk -v version="$VERSION" '
  $0 ~ "^## \\[" version "\\]" { found = 1; print; next }
  found && /^## \[/ { exit }
  found { print }
' CHANGELOG.md > "$NOTES_PATH"

if [[ ! -s "$NOTES_PATH" ]]; then
  cat > "$NOTES_PATH" <<NOTES
## LanScope Mac $TAG

See CHANGELOG.md for release details.
NOTES
fi

echo "committing version bump..."
git add App/AboutWindowController.swift script/build_and_run.sh README.md CHANGELOG.md
git commit -m "Release $TAG"

echo "creating tag $TAG..."
git tag -a "$TAG" -m "LanScope Mac $TAG"

echo "pushing branch and tag..."
git push origin HEAD:main
git push origin "$TAG"

echo "creating GitHub Release..."
gh release create "$TAG" \
  "$DMG_PATH#LanScope.Mac.dmg" \
  "$SHA_PATH#LanScope.Mac.dmg.sha256" \
  --title "LanScope Mac $TAG" \
  --notes-file "$NOTES_PATH"

echo "released $TAG"
