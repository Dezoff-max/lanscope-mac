# Privacy

LanScope Mac runs locally on your Mac.

## Stored Data

The app can store the following data in UserDefaults:

- scanner settings
- favorite devices
- recent scan history
- IP address, hostname, MAC address, vendor, ports, services, and last-seen timestamps for discovered devices

## Network Activity

The app sends only the local network requests required for the range selected by the user:

- TCP connection probes for configured ports
- system `/sbin/ping` probes for local discovery
- Wake-on-LAN UDP magic packets when the user explicitly presses Wake

## External Services

By default, LanScope Mac does not send data to external services, does not use analytics, and does not call cloud APIs.

If the user explicitly presses `Update OUI from IEEE` in Settings, the app downloads public vendor assignment data from:

```text
https://standards-oui.ieee.org/oui/oui.csv
```

That request does not include discovered IP addresses, MAC addresses, hostnames, favorites, or scan history.

## Permissions

The MVP does not require root access. On macOS 15 and later, the system asks for Local Network access before scanning. MAC lookup reads the local macOS routing table directly. If a MAC address is not present in the ARP cache, the app shows `Unknown`.


## Version 0.3 additions

Profiles, custom names, tags and notes are stored locally. Before writing the new data format, the app retains the previous config/favorites/history as local backup keys. Scan export explicitly uses the selected scope; context metadata does not include devices outside that scope.

Wi-Fi scanning may request Location permission so macOS can reveal SSID/BSSID. No location coordinates are collected or transmitted by LanScope. RSSI chart samples and ping monitoring samples remain in memory. Monitoring does not start automatically and pauses during sleep or loss of connectivity. System notifications are requested only when the user presses the enable-notifications control.

Optional Bonjour/mDNS sends local service-discovery queries during a user-started scan. It is skipped when an explicit interface is selected. Service advertisements only enrich confirmed hosts and are not treated as proof of current availability.
