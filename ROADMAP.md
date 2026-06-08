# Roadmap

## Phase 1 - MVP

- SwiftUI shell with sidebar, scan table, detail panel, and settings.
- TCP-based discovery with Network.framework.
- Common service ports and service mapping.
- ARP cache MAC lookup.
- Full local IEEE OUI database and update flow from Settings.
- Favorites, history, CSV export, and JSON export.
- Sample data mode.
- Compact macOS split layout.
- App icon, DMG icon, DMG Finder layout, and installation instructions.

## Phase 2 - Scanner Quality

- Better host discovery strategies: Bonjour/mDNS, NetBIOS hints, and optional UDP probes.
- Improved cancellation for active port probes.
- Adaptive timeout based on observed latency.
- Saved port profiles.
- Additional OUI sources such as MA-M, MA-S, and CID if broader vendor coverage is needed.

## Phase 3 - Admin Workflows

- Bulk actions for selected devices.
- Device notes and tags.
- Diff view for comparing two scans.
- Filters by vendor, service, subnet, and status.
- PDF scan reports.

## Phase 4 - Distribution

- Developer ID signed `.app`.
- Hardened Runtime.
- Notarized DMG.
- Release automation.
- Optional Sparkle update feed for direct distribution outside the App Store.

## Phase 5 - Advanced Visibility

- Optional privileged helper only if raw ICMP or lower-level ARP scanning becomes necessary.
- Passive local-network monitoring.
- SNMP and UPnP inventory plugins.
- Secure credential vault integration for admin actions.
