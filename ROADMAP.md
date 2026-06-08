# ROADMAP

## Phase 1 - MVP

- SwiftUI shell: sidebar, scan table, detail panel, settings.
- TCP-based discovery через Network.framework.
- Популярные порты и service mapping.
- ARP cache MAC lookup.
- Полная локальная IEEE OUI-база и обновление из Settings.
- Favorites, History, CSV/JSON export.
- Sample data mode.
- Компактный macOS split layout, app icon и DMG icon/layout.

## Phase 2 - Scanner quality

- Более точные host discovery стратегии: Bonjour/mDNS, NetBIOS hints, UDP probes.
- Улучшенная отмена активных port probes.
- Adaptive timeout на основе latency.
- Сохранение профилей портов.
- Дополнительные OUI источники: MA-M/MA-S/CID, если понадобится более широкий vendor coverage.

## Phase 3 - Admin workflows

- Массовые действия по выбранным устройствам.
- Device notes/tags.
- Сравнение двух сканов.
- Фильтры по vendor, service, subnet, status.
- Экспорт scan report в PDF.

## Phase 4 - Distribution

- Подписанный `.app`.
- DMG layout.
- Notarization pipeline.
- Sparkle-based update feed, если нужен self-update вне App Store.

## Phase 5 - Advanced visibility

- Optional privileged helper только если появится явная потребность в raw ICMP/ARP scan.
- Passive monitoring локальной сети.
- SNMP/UPnP inventory plugins.
- Secure credential vault integration для админ-действий.
