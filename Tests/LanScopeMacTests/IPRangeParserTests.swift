import XCTest
@testable import LanScopeMac

final class IPRangeParserTests: XCTestCase {
    func testShortHyphenRange() throws {
        let hosts = try IPRangeParser.hosts(in: "192.168.1.1-3")
        XCTAssertEqual(hosts, ["192.168.1.1", "192.168.1.2", "192.168.1.3"])
    }

    func testFullHyphenRange() throws {
        let hosts = try IPRangeParser.hosts(in: "10.0.0.8-10.0.0.10")
        XCTAssertEqual(hosts, ["10.0.0.8", "10.0.0.9", "10.0.0.10"])
    }

    func testCIDRSkipsNetworkAndBroadcast() throws {
        let hosts = try IPRangeParser.hosts(in: "192.168.50.0/30")
        XCTAssertEqual(hosts, ["192.168.50.1", "192.168.50.2"])
    }

    func testRejectsTooLargeRange() {
        XCTAssertThrowsError(try IPRangeParser.hosts(in: "10.10.0.0/16"))
    }
}
