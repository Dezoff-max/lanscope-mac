import Foundation
import XCTest
@testable import LanScopeMac

final class ExportScopeTests: XCTestCase {
    func testContextJSONContainsOnlyExplicitExportScope() throws {
        let selected = Device(ipAddress: "192.0.2.1", customName: "Selected")
        let hidden = Device(ipAddress: "192.0.2.2", customName: "Hidden")
        let scan = ScanHistory(startedAt: Date(), finishedAt: Date(), ipRange: "192.0.2.1-2", totalHosts: 2,
                               foundDevices: 2, devices: [selected, hidden], config: .default)
        let data = try ExportService.jsonData(for: [selected], scan: scan)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let devices = try XCTUnwrap(object["devices"] as? [[String: Any]])
        let context = try XCTUnwrap(object["scan"] as? [String: Any])
        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices[0]["ipAddress"] as? String, selected.ipAddress)
        XCTAssertNil(context["devices"])
        XCTAssertEqual(context["outcome"] as? String, "completed")
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("Hidden"))
    }

    func testSpreadsheetExportsPreventFormulaAndRowInjection() {
        let device = Device(ipAddress: "192.0.2.1", hostname: "\t=HYPERLINK(\"malicious\")\nsecond", notes: "+danger\t\r\nnote")
        let csv = ExportService.csvString(for: [device])
        XCTAssertEqual(csv.split(separator: "\n").count, 2)
        // displayName trims the hostname's leading tab before export.
        XCTAssertTrue(csv.contains("'=HYPERLINK"))
        XCTAssertEqual(ExportService.spreadsheetSafeValue("\t=1\n2"), "' =1 2")
        XCTAssertTrue(csv.contains("'+danger"))
        let tsv = ExportService.tsvString(for: [device])
        let rows = tsv.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].split(separator: "\t", omittingEmptySubsequences: false).count,
                       rows[1].split(separator: "\t", omittingEmptySubsequences: false).count)
    }
}
