import Foundation

struct WiFiNetwork: Codable, Hashable, Identifiable {
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
    var namesRestricted: Bool = false

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
        self.id = bssid == "-" || bssid.isEmpty ? UUID().uuidString : bssid.lowercased()
    }

    var displaySSID: String {
        ssid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (namesRestricted ? "Имя недоступно macOS" : "Скрытая сеть") : ssid
    }

    var signalPercent: Int {
        let clamped = min(max(rssi, -100), -30)
        return Int(round((Double(clamped + 100) / 70.0) * 100.0))
    }

    var signalQuality: String {
        switch signalPercent {
        case 80...:
            return "Отличный"
        case 60..<80:
            return "Хороший"
        case 40..<60:
            return "Средний"
        default:
            return "Слабый"
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

struct WiFiSignalSample: Identifiable {
    let id = UUID()
    let date: Date
    let rssi: Int
}

extension WiFiNetwork {
    var snr: Int? { noise.map { rssi - $0 } }
    var centerFrequency: Double? {
        guard let channel else { return nil }
        switch band {
        case "2.4 GHz": return channel == 14 ? 2484 : Double(2407 + channel * 5)
        case "5 GHz": return Double(5000 + channel * 5)
        case "6 GHz": return channel == 2 ? 5935 : Double(5950 + channel * 5)
        default: return nil
        }
    }
    var widthMHz: Double { Double(channelWidth.split(separator: " ").first ?? "20") ?? 20 }
}
