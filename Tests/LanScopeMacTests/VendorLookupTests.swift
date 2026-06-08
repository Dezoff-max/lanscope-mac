import XCTest
@testable import LanScopeMac

final class VendorLookupTests: XCTestCase {
    func testKnownOUIVendor() {
        let lookup = VendorLookup()
        XCTAssertEqual(lookup.vendor(for: "DC:A9:71:6A:6F:E4"), "Intel Corporate")
    }

    func testBundledOUIDatabaseIncludesScannedVendor() {
        let lookup = VendorLookup()
        XCTAssertGreaterThan(lookup.vendorCount, 30_000)
        XCTAssertEqual(
            lookup.vendor(for: "98:EE:CB:EE:E6:72"),
            "Wistron Infocomm (Zhongshan) Corporation"
        )
    }

    func testLocallyAdministeredAddress() {
        let lookup = VendorLookup()
        XCTAssertEqual(lookup.vendor(for: "AE:62:14:32:31:1F"), "Locally Administered")
    }

    func testUnknownGloballyAdministeredAddress() {
        let lookup = VendorLookup()
        XCTAssertEqual(lookup.vendor(for: "FC:FF:FF:AA:BB:CC"), "Unknown")
    }
}
