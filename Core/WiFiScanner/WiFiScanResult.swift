import Foundation

struct WiFiScanResult {
    var interfaceName: String
    var networks: [WiFiNetwork]
    var scannedAt: Date
}
