import XCTest
@testable import LanScopeMac

final class WiFiNetworkTests: XCTestCase {
    func testSignalPercentIsClampedAndScaled() {
        XCTAssertEqual(WiFiNetwork(ssid: "Strong", bssid: "00:11:22:33:44:55", rssi: -30).signalPercent, 100)
        XCTAssertEqual(WiFiNetwork(ssid: "Weak", bssid: "00:11:22:33:44:66", rssi: -100).signalPercent, 0)
        XCTAssertEqual(WiFiNetwork(ssid: "Middle", bssid: "00:11:22:33:44:77", rssi: -65).signalPercent, 50)
    }

    func testHiddenNetworkDisplayName() {
        let network = WiFiNetwork(ssid: "", bssid: "-", rssi: -72)
        XCTAssertEqual(network.displaySSID, "Hidden Network")
    }
}
