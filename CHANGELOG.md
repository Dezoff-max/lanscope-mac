# Changelog

All notable changes to LanScope Mac are documented in this file.

The project uses semantic versioning while it is in MVP development.

## [Unreleased]

No unreleased changes yet.

## [0.1.2] - 2026-06-08

### Added

- Wi-Fi scanner section for nearby network discovery with SSID, BSSID, signal strength, security, channel, band, width, PHY mode, and noise.
- Release workflow documentation and `script/release.sh` for repeatable DMG/tag/GitHub Release publishing.
- Total release downloads badge in the README.

### Changed

- Updated GitHub Actions checkout to `actions/checkout@v6`.
- Cleaned up SwiftPM local excludes to avoid CI warnings.
- Improved bundled OUI loading for app bundles by preferring `Bundle.main` resources.

## [0.1.1] - 2026-06-08

### Added

- Full custom About window with app icon, version/build number, developer attribution, copyright, rights, license, and project links.

### Changed

- Updated the bundled app metadata to version `0.1.1`.
- Published a dedicated `v0.1.1` GitHub Release with a refreshed DMG and checksum.

## [0.1.0] - 2026-06-08

### Added

- Native macOS 14+ SwiftUI LAN scanner MVP.
- IP range input, local range detection, Scan / Stop controls, progress reporting, and non-blocking scanning.
- Ping-based discovery and TCP port scanning for common LAN services.
- ARP cache MAC lookup and offline OUI vendor lookup.
- Device table, detail panel, favorites, scan history, export, and quick device actions.
- Sample data mode for UI testing without real network scans.
- App icon, DMG volume icon, Finder layout, DMG file icon, and installation instructions.
- Public GitHub repository with README, installation guide, privacy note, security policy, roadmap, screenshots, and CI.

[Unreleased]: https://github.com/Dezoff-max/lanscope-mac/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/Dezoff-max/lanscope-mac/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/Dezoff-max/lanscope-mac/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/Dezoff-max/lanscope-mac/releases/tag/v0.1.0
