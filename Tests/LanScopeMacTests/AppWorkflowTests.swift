import XCTest
@testable import LanScopeMac

final class AppWorkflowTests: XCTestCase {
    @MainActor
    private func state() -> (AppState, UserDefaults, String) {
        let name = "LanScopeWorkflowTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        return (AppState(persistence: UserDefaultsStore(defaults: defaults)), defaults, name)
    }
    @MainActor
    func testFinishKeepsSelectionAndOriginalConfig() {
        let (state, defaults, name) = state(); defer { defaults.removePersistentDomain(forName: name) }
        let original = state.config
        state.currentScanConfig = original; state.currentScanStartedAt = Date()
        state.handleScanEvent(.started(total: 1))
        let device = Device(ipAddress: "192.0.2.10", profileID: original.profileID)
        state.handleScanEvent(.deviceFound(device, completed: 1, total: 1))
        state.selectedDeviceIDs = [device.id]
        state.config.ipRange = "198.51.100.1"
        state.finishScan(outcome: .cancelled)
        XCTAssertEqual(state.selectedDeviceIDs, [device.id])
        XCTAssertEqual(state.history.first?.ipRange, original.ipRange)
        XCTAssertEqual(state.history.first?.outcome, .cancelled)
    }
    @MainActor
    func testUnresolvedEarlyResultCannotEraseFavoriteMAC() {
        let (state, defaults, name) = state(); defer { defaults.removePersistentDomain(forName: name) }
        let favorite = Device(ipAddress: "192.0.2.10", macAddress: "00:11:22:33:44:55", isFavorite: true, profileID: state.config.profileID)
        state.favorites = [favorite]
        state.handleScanEvent(.deviceFound(Device(ipAddress: favorite.ipAddress, profileID: favorite.profileID), completed: 1, total: 1))
        XCTAssertEqual(state.favorites.first?.macAddress, favorite.macAddress)
        let replacement = Device(ipAddress: favorite.ipAddress, macAddress: "00:11:22:33:44:66", profileID: favorite.profileID)
        state.handleScanEvent(.completed([replacement], total: 1))
        XCTAssertFalse(state.devices[0].isFavorite)
        XCTAssertEqual(state.favorites.first?.macAddress, favorite.macAddress)
    }
    @MainActor
    func testExportAndRemovalHonorFilteredSelection() {
        let (state, defaults, name) = state(); defer { defaults.removePersistentDomain(forName: name) }
        let a = Device(ipAddress: "192.0.2.1", isFavorite: true, profileID: state.config.profileID, customName: "NAS")
        let b = Device(ipAddress: "192.0.2.2", isFavorite: true, profileID: state.config.profileID, customName: "Camera")
        state.favorites = [a,b]; state.selectedSection = .favorites
        state.selectedDeviceIDs = [a.id,b.id]; state.searchText = "NAS"
        XCTAssertEqual(state.exportDevices(scope: .filtered).map(\.id), [a.id])
        XCTAssertEqual(state.exportDevices(scope: .selected).map(\.id), [a.id])
        state.removeSelectedFavorites()
        XCTAssertEqual(state.favorites.map(\.id), [b.id])
        state.undoRemoveFavorites(); XCTAssertEqual(state.favorites.count, 2)
    }
    @MainActor
    func testRecheckCannotReplaceFavoriteIdentity() {
        let (state, defaults, name) = state(); defer { defaults.removePersistentDomain(forName: name) }
        let original = Device(ipAddress: "192.0.2.1", macAddress: "00:11:22:33:44:55", openPorts: [80], isFavorite: true, profileID: state.config.profileID, customName: "Server")
        state.favorites = [original]; state.devices = [original]
        let replacement = Device(ipAddress: original.ipAddress, macAddress: "00:11:22:33:44:66", profileID: original.profileID)
        state.applyRecheckResult(replacement, to: original)
        XCTAssertEqual(state.favorites.first?.normalizedMAC, original.normalizedMAC)
        XCTAssertEqual(state.favorites.first?.status, .unknown)
        XCTAssertEqual(state.favorites.first?.openPorts, [])
        XCTAssertNil(state.currentScanRecord)
    }
    @MainActor
    func testEarlyRowMetadataAndFavoriteDoNotMutateKnownMAC() {
        let (state, defaults, name) = state(); defer { defaults.removePersistentDomain(forName: name) }
        let known = Device(ipAddress: "192.0.2.1", macAddress: "00:11:22:33:44:55", isFavorite: true, profileID: state.config.profileID, customName: "Server")
        state.favorites = [known]; state.deviceMetadata = [known]
        let early = Device(ipAddress: known.ipAddress, profileID: known.profileID)
        state.updateDeviceMetadata(early, name: "New", kind: .camera, notes: "", tags: [])
        XCTAssertEqual(state.favorites.first?.customName, "Server")
        XCTAssertEqual(state.deviceMetadata.first(where: { $0.normalizedMAC == known.normalizedMAC })?.customName, "Server")
        state.toggleFavorite(early)
        XCTAssertTrue(state.favorites.contains(where: { $0.id == known.id }))
    }
    @MainActor
    func testHistoryUsesCurrentFavoritesWithoutChangingMeasurements() {
        let (state, defaults, name) = state(); defer { defaults.removePersistentDomain(forName: name) }
        let device = Device(ipAddress: "192.0.2.1", status: .online, profileID: state.config.profileID)
        state.currentScanConfig = state.config; state.currentScanStartedAt = Date()
        state.handleScanEvent(.started(total: 1))
        state.handleScanEvent(.completed([device], total: 1))
        state.finishScan(outcome: .completed)
        state.selectedSection = .history
        state.toggleFavorite(device)
        XCTAssertTrue(state.visibleDevices[0].isFavorite)
        XCTAssertFalse(state.history[0].devices[0].isFavorite)
        XCTAssertEqual(state.visibleDevices[0].status, .online)
        state.toggleFavorite(device)
        XCTAssertFalse(state.visibleDevices[0].isFavorite)
    }
    @MainActor
    func testProfileWithSavedDataCannotBeOrphaned() {
        let (state, defaults, name) = state(); defer { defaults.removePersistentDomain(forName: name) }
        let id = state.config.profileID!
        state.favorites = [Device(ipAddress: "192.0.2.1", profileID: id)]
        state.saveProfile(name: "Other")
        state.deleteProfile(id)
        XCTAssertTrue(state.profiles.contains { $0.id == id })
    }
    func testWiFiAnonymousIdentityAndRestrictions() {
        var a = WiFiNetwork(ssid: "", bssid: "-", rssi: -60, channel: 6)
        let b = WiFiNetwork(ssid: "", bssid: "-", rssi: -60, channel: 6)
        XCTAssertNotEqual(a.id, b.id)
        a.namesRestricted = true
        XCTAssertEqual(a.displaySSID, "Имя недоступно macOS")
    }
}
