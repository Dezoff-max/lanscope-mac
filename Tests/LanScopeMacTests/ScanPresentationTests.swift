import XCTest
@testable import LanScopeMac

final class ScanPresentationTests: XCTestCase {
    @MainActor
    func testDiscoveredDeviceIsImmediatelyExportableWithoutForcingSelection() async throws {
        let suite = "LanScopeMacTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(persistence: UserDefaultsStore(defaults: defaults))
        let device = Device(ipAddress: "192.0.2.10")

        state.handleScanEvent(.deviceFound(device, completed: 1, total: 2))

        XCTAssertEqual(state.exportableSelection.map(\.id), [device.id])
        XCTAssertTrue(state.selectedDeviceIDs.isEmpty)
        XCTAssertEqual(state.progress, 0.5)
    }

    @MainActor
    func testCompletionImmediatelyPublishesEnrichedAndARPOnlyDevices() async throws {
        let suite = "LanScopeMacTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(persistence: UserDefaultsStore(defaults: defaults))
        var discovered = Device(ipAddress: "192.0.2.10")
        let arpOnly = Device(ipAddress: "192.0.2.2", macAddress: "00:11:22:33:44:55")
        state.favorites = [arpOnly]
        state.handleScanEvent(.deviceFound(discovered, completed: 1, total: 2))
        state.selectedDeviceIDs = [discovered.id]
        discovered.vendor = "Example Vendor"
        discovered.macAddress = "00:11:22:33:44:66"

        state.handleScanEvent(.completed([discovered, arpOnly], total: 2))

        XCTAssertEqual(state.devices.map(\.ipAddress), ["192.0.2.2", "192.0.2.10"])
        XCTAssertTrue(state.devices[0].isFavorite)
        XCTAssertEqual(state.selectedDevice?.vendor, "Example Vendor")
        XCTAssertEqual(state.selectedDevice?.macAddress, discovered.macAddress)
        XCTAssertEqual(state.progress, 1)
        state.selectedDeviceIDs = []
        XCTAssertEqual(state.exportableSelection.count, 2)
    }
}
