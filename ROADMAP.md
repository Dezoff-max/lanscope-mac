# Roadmap

## Implemented in 0.3 development

- Accurate ARP-only status, cancellation, connection budgets, interface selection and IPv4 bounds.
- Profiles, device names/types/notes/tags, safe history outcomes and scan comparison.
- Latency/loss monitoring, in-app state changes and explicit opt-in notifications.
- Russian UI, configurable columns (14.4+), compatible compact table (14.0+), resizable inspector and accessible motion.
- Wi-Fi signal history, channel overlap, SSID grouping, current connection and scoped export.
- Bonjour/mDNS enrichment, bounded to confirmed hosts.
- Automated tests, packaging/signature checks and migration backup.

## Next iterations

- Confirmed protocol fingerprints, additional SSDP/SMB hints, IPv6/NDP.
- Long-term storage with an explicit retention policy and import/export archive.
- Optional SNMP inventory and credential storage in Keychain if authentication is introduced.
- PDF site reports and data-backed/manual topology.
- Broader minimum-OS/architecture runtime coverage and signed updater.

## Distribution gate

Developer ID signing configuration is supported, but a valid developer certificate and notarization credentials must be supplied by the owner before a notarized public release. Never disable Gatekeeper globally as an installation step.
