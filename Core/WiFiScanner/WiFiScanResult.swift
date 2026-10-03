import Foundation

struct WiFiScanResult {
    var interfaceName: String
    var networks: [WiFiNetwork]
    var scannedAt: Date
    var currentBSSID: String? = nil
    var currentSSID: String? = nil
}
