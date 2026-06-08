#!/bin/bash
set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
if [[ "$SCRIPT_DIR" == "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="."
fi
cd "$SCRIPT_DIR/.."
ROOT_DIR="$PWD"

echo "running static validation..."

required_dirs=(
  App
  Features/Scanner
  Features/WiFi
  Features/Devices
  Features/Favorites
  Features/History
  Features/Settings
  Core/NetworkScanner
  Core/WiFiScanner
  Core/ARP
  Core/VendorLookup
  Core/WakeOnLAN
  Core/Export
  Models
  Persistence
  Utilities
  Resources
  Tests/LanScopeMacTests
)

for dir in "${required_dirs[@]}"; do
  test -d "$dir" || {
    echo "missing directory: $dir" >&2
    exit 1
  }
done

bash -n script/build_and_run.sh
bash -n script/package_dmg.sh
bash -n script/release.sh
jq empty Resources/oui.json
test -f Resources/AppIcon.icns || {
  echo "missing app icon: Resources/AppIcon.icns" >&2
  exit 1
}
test -f Resources/DMGBackground.png || {
  echo "missing DMG background: Resources/DMGBackground.png" >&2
  exit 1
}

ds_store_file="$(find App Features Core Models Persistence Utilities Resources Tests script -name .DS_Store -print -quit)"
if [[ -n "$ds_store_file" ]]; then
  echo "unexpected .DS_Store files found" >&2
  find App Features Core Models Persistence Utilities Resources Tests script -name .DS_Store -print >&2
  exit 1
fi

forbidden_pattern="TODO|FIXME|fatalError|try!|\\.white\\b|Color\\.white\\b|NSPrivate|private API"
scan_files=(
  Package.swift
  README.md
  CHANGELOG.md
  ROADMAP.md
  PRIVACY.md
  script/build_and_run.sh
  script/package_dmg.sh
  script/release.sh
  script/update_oui_database.rb
)

file_list="$(mktemp "${TMPDIR:-/tmp}/lanscope-static-files.XXXXXX")"
trap 'rm -f "$file_list"' EXIT

find App Features Core Models Persistence Utilities Tests \
  -type f \( -name '*.swift' -o -name '*.md' -o -name '*.sh' -o -name '*.rb' \) -print >"$file_list"
printf '%s\n' "${scan_files[@]}" >>"$file_list"

if xargs grep -nE "$forbidden_pattern" <"$file_list"; then
  echo "static validation found forbidden markers" >&2
  exit 1
fi

echo "static validation passed"
