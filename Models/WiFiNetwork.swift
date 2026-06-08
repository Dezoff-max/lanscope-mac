import Foundation

struct WiFiNetwork: Hashable, Identifiable {
    var id: String
    var ssid: String
    var bssid: String
    var rssi: Int
    var noise: Int?
    var channel: Int?
    var band: String
    var channelWidth: String
    var security: String
    var phyModes: [String]
    var lastSeen: Date

    init(
        ssid: String,
        bssid: String,
        rssi: Int,
        noise: Int? = nil,
        channel: Int? = nil,
        band: String = "Unknown",
        channelWidth: String = "Unknown",
        security: String = "Unknown",
        phyModes: [String] = [],
        lastSeen: Date = Date()
    ) {
        self.ssid = ssid
        self.bssid = bssid
        self.rssi = rssi
        self.noise = noise
        self.channel = channel
        self.band = band
        self.channelWidth = channelWidth
        self.security = security
        self.phyModes = phyModes
        self.lastSeen = lastSeen
        self.id = bssid == "-" ? "\(ssid)-\(channel ?? 0)-\(rssi)" : bssid.lowercased()
    }

    var displaySSID: String {
        ssid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Hidden Network" : ssid
    }

    var signalPercent: Int {
        let clamped = min(max(rssi, -100), -30)
        return Int(round((Double(clamped + 100) / 70.0) * 100.0))
    }

    var signalQuality: String {
        switch signalPercent {
        case 80...:
            return "Excellent"
        case 60..<80:
            return "Good"
        case 40..<60:
            return "Fair"
        default:
            return "Weak"
        }
    }

    var channelDisplay: String {
        guard let channel else {
            return "-"
        }
        return "\(channel)"
    }

    var noiseDisplay: String {
        guard let noise else {
            return "-"
        }
        return "\(noise) dBm"
    }

    var phyDisplay: String {
        phyModes.isEmpty ? "-" : phyModes.joined(separator: ", ")
    }

    var ssidSortValue: String {
        displaySSID.localizedLowercase
    }

    var bssidSortValue: String {
        bssid.localizedLowercase
    }

    var signalSortValue: Int {
        rssi
    }

    var channelSortValue: Int {
        channel ?? Int.max
    }

    var bandSortValue: String {
        band
    }

    var securitySortValue: String {
        security.localizedLowercase
    }
}
