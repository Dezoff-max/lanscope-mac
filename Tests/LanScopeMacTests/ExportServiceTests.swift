import XCTest
@testable import LanScopeMac

final class ExportServiceTests: XCTestCase {
    func testCSVExportEscapesQuotes() {
        let device = Device(
            ipAddress: "192.168.1.12",
            hostname: "Office \"NAS\"",
            macAddress: "00:11:32:AA:BB:CC",
            vendor: "Synology Incorporated",
            openPorts: [22, 445],
            services: [ServiceCatalog.service(for: 22), ServiceCatalog.service(for: 445)],
            lastSeen: Date(timeIntervalSince1970: 0)
        )

        let csv = ExportService.csvString(for: [device])
        XCTAssertTrue(csv.contains("\"Office \"\"NAS\"\"\""))
        XCTAssertTrue(csv.contains("\"192.168.1.12\""))
        XCTAssertTrue(csv.contains("\"22, 445\""))
    }
}
