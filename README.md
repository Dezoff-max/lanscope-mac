# LanScope Mac

LanScope Mac - нативное macOS 14+ приложение для локального LAN-сканирования. MVP на Swift, SwiftUI, MVVM, async/await и Network.framework.

Use LanScope Mac only on networks you own or are authorized to administer.

## Что уже есть в MVP

- ввод диапазона IP: `192.168.1.1-254`, полный диапазон `192.168.1.10-192.168.1.40`, одиночный IP или CIDR до 4096 хостов;
- автоопределение локального IPv4 диапазона;
- Scan / Stop, прогресс и неблокирующее сканирование;
- ping-based discovery и TCP порт-скан популярных сервисов: SSH, HTTP, HTTPS, SMB, AFP, VNC, RDP, HTTP-alt;
- ограничение параллельности и timeout в Settings;
- ARP cache lookup через `/usr/sbin/arp` без root-доступа;
- локальная IEEE OUI-база `Resources/oui.json` с 39k+ vendor records;
- обновление OUI из Settings и через локальный скрипт `script/update_oui_database.rb`;
- Favorites и History через UserDefaults;
- CSV / JSON export и копирование строк в clipboard;
- быстрые действия: Browser, SSH через Terminal, SMB, VNC, Copy IP, Copy MAC, Favorite, Wake-on-LAN;
- sample data mode в Settings для проверки UI без реального сетевого сканирования.
- app icon и DMG volume icon из `Resources/AppIcon.icns`.

## Installation

См. [INSTALL.md](INSTALL.md) для инструкции установки на русском и английском языке.

See [INSTALL.md](INSTALL.md) for Russian and English installation instructions.

## Запуск в Xcode

1. Откройте `Package.swift` в Xcode.
2. Выберите scheme `LanScopeMac`.
3. Убедитесь, что выбран My Mac.
4. Нажмите Run.

Если Xcode просит принять license, выполните в Terminal:

```bash
sudo xcodebuild -license
```

После этого Xcode/SwiftPM смогут полноценно собирать проект.

## Запуск из Codex/Terminal

```bash
/bin/bash ./script/build_and_run.sh
```

Скрипт собирает SwiftPM target, создает локальный app bundle в `dist/LanScope Mac.app`, копирует resources и запускает приложение как обычное foreground macOS app.

Проверка процесса:

```bash
/bin/bash ./script/build_and_run.sh --verify
```

Статическая проверка, доступная даже до успешной Xcode-сборки:

```bash
/bin/bash ./script/validate_static.sh
```

После принятия Xcode license также стоит выполнить:

```bash
swift test
```

## Vendor / OUI database

Bundled база уже включена в приложение и работает офлайн. Если нужно обновить ее из официального IEEE CSV:

```bash
./script/update_oui_database.rb
```

Источник: `https://standards-oui.ieee.org/oui/oui.csv`.

В приложении то же действие доступно в Settings -> Lookup -> Update OUI from IEEE. Пользовательская база сохраняется в `~/Library/Application Support/LanScope Mac/oui.json` и перекрывает bundled записи.

## DMG

После успешной сборки можно создать локальный DMG:

```bash
/bin/bash ./script/package_dmg.sh
```

Артефакт появится в `dist/LanScope Mac.dmg`. MVP DMG не подписан и не notarized.

DMG содержит приложение с иконкой, volume icon, Finder layout с фоном, README/INSTALL/LICENSE/PRIVACY и ссылку на `/Applications`.

Готовый DMG не хранится в git-репозитории. Для публичной раздачи используйте GitHub Releases.

## Архитектура

- `App/` - entry point и app-level state.
- `Features/Scanner` - экран сканирования.
- `Features/Devices` - таблица, sidebar, detail panel.
- `Features/Favorites` - избранные устройства.
- `Features/History` - история сканов.
- `Features/Settings` - настройки scanner/theme/sample data mode.
- `Core/NetworkScanner` - async scanner, TCP probes, service catalog.
- `Core/ARP` - чтение macOS ARP cache.
- `Core/VendorLookup` - локальный OUI lookup.
- `Core/WakeOnLAN` - UDP magic packet.
- `Core/Export` - CSV/JSON/clipboard export.
- `Models/` - Device, ScannerConfig, ScanHistory.
- `Persistence/` - UserDefaults persistence.
- `Utilities/` - IP parser, local network detection, hostname resolver, actions.

## Ограничения MVP

- ICMP discovery выполняется через системный `/sbin/ping`, без raw sockets и без root-доступа. TCP port scan сделан через Network.framework.
- MAC-адрес виден только если устройство есть в ARP cache macOS.
- Vendor определяется по локальной OUI-базе. Если OUI отсутствует в IEEE MA-L или адрес является randomized/locally administered, приложение показывает `Unknown` или `Locally Administered`.
