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

The MVP does not require root access. MAC lookup uses the local macOS ARP cache through `/usr/sbin/arp`. If a MAC address is not present in the ARP cache, the app shows `Unknown`.
