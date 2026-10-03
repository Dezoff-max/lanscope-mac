import AppKit
import UniformTypeIdentifiers

@MainActor
enum WiFiExportService {
    static func save(_ networks: [WiFiNetwork], asJSON: Bool) throws -> Bool {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = asJSON ? "lanscope-wifi.json" : "lanscope-wifi.csv"
        panel.allowedContentTypes = [asJSON ? .json : .commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        let data: Data
        if asJSON {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
            data = try encoder.encode(networks)
        } else {
            func safe(_ value: String) -> String {
                let value = value.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\t", with: " ")
                let protected = ["=", "+", "-", "@"].contains(String(value.first ?? " ")) ? "'" + value : value
                return "\"" + protected.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            let header = ["SSID", "BSSID", "RSSI dBm", "Noise dBm", "Channel", "Band", "Width", "Security", "Scanned at"]
            let rows = networks.map { [$0.displaySSID, $0.bssid, String($0.rssi), $0.noise.map(String.init) ?? "", $0.channelDisplay, $0.band, $0.channelWidth, $0.security, $0.lastSeen.ISO8601Format()] }
            data = Data(([header] + rows).map { $0.map(safe).joined(separator: ",") }.joined(separator: "\n").utf8)
        }
        try data.write(to: url, options: .atomic); return true
    }
}
