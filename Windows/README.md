# LanScope Windows

LanScope Windows is the native Windows port of LanScope Mac. It keeps the same local-first workflow and stores scan data only on the current PC.

Use it only on networks you own or are authorized to administer.

## Features

- IPv4 input as one address, short/full range, or CIDR (maximum 4096 hosts).
- Automatic detection of the physical local IPv4 subnet.
- Asynchronous ping discovery and TCP probing with configurable timeout and parallelism.
- Common services: SSH, HTTP, HTTPS, SMB, AFP, RDP, VNC, and HTTP-alt.
- Windows ARP cache lookup and offline vendor lookup through the bundled IEEE OUI database.
- Nearby Wi-Fi networks through the Windows WLAN command interface.
- Favorites and the latest 25 scan-history entries in `%LocalAppData%\LanScope Windows`.
- CSV/JSON export, tab-separated clipboard copy, and device search.
- Quick actions for Browser, SSH, SMB, Remote Desktop, copy IP/MAC, and Wake-on-LAN.
- System, Light, and Dark themes.
- Animated subnet sweep with packets, device nodes, pulse feedback, and a disabled Scan button while scanning.

## Installer

Download and run `LanScope-Windows-Setup-x64.exe`. The installer is per-user by default, creates Start Menu shortcuts, supports an optional Desktop shortcut, and includes a standard uninstaller.

## Portable build

The release archive contains a self-contained executable and `Resources\oui.json`. Keep both together. An installed .NET runtime is not required.

1. Extract `LanScope-Windows-win-x64.zip`.
2. Run `LanScope.Windows.exe`.
3. If Windows Firewall asks about network access, allow it only for the network profiles where you want to scan.

## Build from source

Requirements:

- Windows 10 or Windows 11, x64 or ARM64.
- .NET 8 SDK.
- PowerShell 5.1 or newer.
- Inno Setup 6 or 7 to produce `Setup.exe` (optional; the portable ZIP does not need it).

From the repository root:

```powershell
.\Windows\Build-Windows.ps1
```

For ARM64:

```powershell
.\Windows\Build-Windows.ps1 -Runtime win-arm64
```

The script runs the core tests, publishes a self-contained single-file application, creates a portable ZIP, and builds `Setup.exe` when the Inno Setup compiler is available. Artifacts are written under `Windows\dist`.

## Windows architecture

- `LanScope.Core` - models, parsers, scanner, ARP/OUI, Wi-Fi parsing, persistence, export, and Wake-on-LAN.
- `LanScope.Windows` - WPF UI and application view model.
- `LanScope.Core.Tests` - dependency-free executable test suite.

## Platform differences

- macOS `Network.framework` is replaced with `Ping`, `TcpClient`, and Windows networking APIs.
- the Darwin routing-table ARP reader is replaced with parsing of `arp -a`.
- CoreWLAN is replaced with `netsh wlan show networks mode=bssid`.
- VNC quick action is replaced with Windows Remote Desktop (RDP).

Wi-Fi fields depend on the wireless adapter/driver and the language-specific `netsh` output. SSID, BSSID, signal, channel, security, and radio type are supported for English and Russian Windows field names.
