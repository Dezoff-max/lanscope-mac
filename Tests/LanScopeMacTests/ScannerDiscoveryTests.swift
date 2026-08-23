import Foundation
import XCTest
@testable import LanScopeMac

final class ScannerDiscoveryTests: XCTestCase {
    func testPingTimeoutConvertsSecondsToMilliseconds() {
        XCTAssertEqual(
            PingProbe.commandArguments(host: "192.0.2.1", timeout: 0.8),
            ["-c", "1", "-W", "800", "192.0.2.1"]
        )
    }

    func testLegacyConfigDropsRemovedMockMode() throws {
        let legacyJSON = #"{"ipRange":"192.168.1.1-254","ports":[22,80],"timeout":0.8,"concurrencyLimit":64,"vendorLookupEnabled":true,"mockMode":true,"theme":"system"}"#
        let config = try JSONDecoder().decode(ScannerConfig.self, from: Data(legacyJSON.utf8))
        let encoded = try JSONEncoder().encode(config)
        let encodedJSON = try XCTUnwrap(String(data: encoded, encoding: .utf8))

        XCTAssertEqual(config.ipRange, "192.168.1.1-254")
        XCTAssertFalse(encodedJSON.contains("mockMode"))
    }

    func testARPAddressNormalization() {
        XCTAssertEqual(
            ARPResolver.normalizedMACAddress([0xB4, 0xB0, 0x24, 0x00, 0x51, 0xA8]),
            "B4:B0:24:00:51:A8"
        )
        XCTAssertNil(ARPResolver.normalizedMACAddress([0xB4, 0xB0]))
    }
}
