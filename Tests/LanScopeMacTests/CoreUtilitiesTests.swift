import XCTest
@testable import LanScopeMac

final class CoreUtilitiesTests: XCTestCase {
    func testFullIPv4RangeIsRejectedWithoutOverflow() {
        XCTAssertThrowsError(try IPRangeParser.hosts(in: "0.0.0.0-255.255.255.255")) { error in
            guard case IPRangeError.tooLarge(let count) = error else {
                return XCTFail("Expected range size validation, received \(error)")
            }
            XCTAssertEqual(count, 4_294_967_296)
        }
        XCTAssertThrowsError(try IPRangeParser.hosts(in: "0.0.0.0/0"))
    }

    func testIPv4BoundaryHostsAndPointToPointRanges() throws {
        XCTAssertEqual(try IPRangeParser.hosts(in: "255.255.255.255/32"), ["255.255.255.255"])
        XCTAssertEqual(try IPRangeParser.hosts(in: "0.0.0.0/32"), ["0.0.0.0"])
        XCTAssertEqual(try IPRangeParser.hosts(in: "255.255.255.254/31"), ["255.255.255.254", "255.255.255.255"])
        XCTAssertEqual(try IPRangeParser.hosts(in: "255.255.255.254-255.255.255.255"), ["255.255.255.254", "255.255.255.255"])
    }

    func testEmptyAndMalformedRangeComponentsAreRejected() {
        for value in [
            ",", "192.168.1.1,", ",192.168.1.1", "192.168.1.1,,192.168.1.2",
            "192.168.1.1, ,192.168.1.2", "192.168.1.1-", "-192.168.1.1",
            "192.168.1.1--2", "192.168.1.1/", "192.168.1.1//24",
            "192..168.1.1", ".192.168.1.1", "192.168.1.1.", "192.168.1.+1",
            "192.168.1.1/+24", "192.168.1.1-+2"
        ] {
            XCTAssertThrowsError(try IPRangeParser.hosts(in: value), "Should reject \(value)")
        }
    }

    func testWhitespaceAndOverlappingRangesAreHandled() throws {
        XCTAssertEqual(
            try IPRangeParser.hosts(in: " 192.168.1.1 - 3, 192.168.1.2 ,192.168.1.0 / 30 "),
            ["192.168.1.1", "192.168.1.2", "192.168.1.3"]
        )
    }

    func testAggregateHostLimitIsEnforced() {
        XCTAssertThrowsError(try IPRangeParser.hosts(in: "10.0.0.0-10.0.15.255,10.0.16.0"))
    }
}
