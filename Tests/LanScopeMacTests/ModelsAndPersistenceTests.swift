import Foundation
import XCTest
@testable import LanScopeMac

final class ModelsAndPersistenceTests: XCTestCase {
    func testLegacyDeviceAndConfigKeepDataAndDefaultNewFields() throws {
        let payload = #"{"ipAddress":"192.0.2.4","hostname":"NAS","macAddress":"00:11:22:33:44:55","status":"online","isFavorite":true}"#
        let device = try JSONDecoder().decode(Device.self, from: Data(payload.utf8))
        XCTAssertEqual(device.displayName, "NAS")
        XCTAssertTrue(device.isFavorite)
        XCTAssertEqual(device.kind, .unknown)
        XCTAssertNil(device.confirmedAt)
        XCTAssertNil(device.profileID)
        let config = try JSONDecoder().decode(ScannerConfig.self, from: Data(#"{"ipRange":"192.0.2.1-8","ports":[80]}"#.utf8))
        XCTAssertEqual(config.maxConnections, 128)
        XCTAssertEqual(config.ports, [80])
    }

    func testDeviceIdentityRejectsDifferentKnownMACAndDifferentNetworks() {
        let profile = UUID()
        let device = Device(ipAddress: "192.0.2.4", macAddress: "00:11:22:33:44:55", profileID: profile)
        XCTAssertFalse(device.matches(Device(ipAddress: device.ipAddress, macAddress: "00:11:22:33:44:66", profileID: profile)))
        XCTAssertFalse(device.matches(Device(ipAddress: device.ipAddress, macAddress: device.macAddress, profileID: UUID())))
        XCTAssertTrue(device.matches(Device(ipAddress: "192.0.2.8", macAddress: "00-11-22-33-44-55", profileID: profile)))
    }

    func testCorruptPersistenceIsBackedUpBeforeSavingReplacement() throws {
        let suite = "LanScopeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let invalid = Data("damaged payload".utf8)
        defaults.set(invalid, forKey: "LanScopeMac.favorites")
        let store = UserDefaultsStore(defaults: defaults)
        XCTAssertTrue(store.loadFavorites().isEmpty)
        XCTAssertNotNil(store.warning)
        store.saveFavorites([Device(ipAddress: "192.0.2.7", customName: "Мост1", notes: "Крыша", kind: .bridge)])
        XCTAssertEqual(defaults.data(forKey: "LanScopeMac.favorites.unreadableBackup"), invalid)
        XCTAssertEqual(store.loadFavorites().first?.customName, "Мост1")
    }

    func testMetadataAndProfilesRoundTrip() throws {
        let suite = "LanScopeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsStore(defaults: defaults)
        let profile = NetworkProfile(name: "Склад", config: .default)
        store.saveProfiles([profile])
        store.saveDeviceMetadata([Device(ipAddress: "192.0.2.4", profileID: profile.id, customName: "Мост1", tags: ["Важно"], kind: .bridge)])
        XCTAssertEqual(store.loadProfiles(), [profile])
        XCTAssertEqual(store.loadDeviceMetadata().first?.profileID, profile.id)
        XCTAssertEqual(store.loadDeviceMetadata().first?.tags, ["Важно"])
    }

    func testFirstSavePreservesAllLegacyPayloadsOnceBeforeSchemaUpgrade() throws {
        let suite = "LanScopeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let originals = [
            "LanScopeMac.config": Data(#"{"ipRange":"192.0.2.1-8","ports":[80]}"#.utf8),
            "LanScopeMac.favorites": Data(#"[{"ipAddress":"192.0.2.4","status":"online"}]"#.utf8),
            "LanScopeMac.history": Data("[]".utf8)
        ]
        originals.forEach { defaults.set($0.value, forKey: $0.key) }
        let store = UserDefaultsStore(defaults: defaults)
        store.saveFavorites([Device(ipAddress: "192.0.2.4", status: .cached)])
        XCTAssertEqual(defaults.integer(forKey: "LanScopeMac.schemaVersion"), 3)
        for (key, original) in originals {
            XCTAssertEqual(defaults.data(forKey: "\(key).schemaBackup.v0_2"), original)
        }
        store.saveConfig(.default)
        store.saveHistory([])
        store.saveFavorites([])
        for (key, original) in originals {
            XCTAssertEqual(defaults.data(forKey: "\(key).schemaBackup.v0_2"), original)
        }
    }

    func testNormalizedConcurrencyMatchesScannerHostLimit() {
        var config = ScannerConfig.default
        config.concurrencyLimit = 512
        XCTAssertEqual(config.normalized().concurrencyLimit, 128)
        config.concurrencyLimit = 0
        XCTAssertEqual(config.normalized().concurrencyLimit, 1)
    }

    func testPortRangesAreValidatedWithoutSilentlyDroppingErrors() throws {
        XCTAssertEqual(try PortListParser.validate("443, 22, 8000-8002, 443"), [22, 443, 8000, 8001, 8002])
        for input in ["", "0", "65536", "22,garbage", "100-1", "1-65535", "80--90"] {
            XCTAssertThrowsError(try PortListParser.validate(input), input)
        }
    }

    func testComparisonTracksAddressAndPortsAndRejectsPartialCoverage() {
        let profile = UUID()
        var config = ScannerConfig.default
        config.profileID = profile
        let old = Device(ipAddress: "192.0.2.2", macAddress: "00:11:22:33:44:55", openPorts: [80], profileID: profile)
        let new = Device(ipAddress: "192.0.2.3", macAddress: old.macAddress, openPorts: [22, 80], profileID: profile)
        let before = snapshot(devices: [old], config: config)
        let after = snapshot(devices: [new], config: config)
        let comparison = ScanComparison(previous: before, current: after)
        XCTAssertTrue(comparison.isComparable)
        XCTAssertEqual(comparison.addressChangedCount, 1)
        XCTAssertEqual(comparison.servicesChangedCount, 1)
        XCTAssertEqual(comparison.addedCount + comparison.missingCount, 0)
        var partial = after
        partial.outcome = .cancelled
        partial.completedHosts = 1
        let incomplete = ScanComparison(previous: before, current: partial)
        XCTAssertFalse(incomplete.isComparable)
        XCTAssertTrue(incomplete.changes.isEmpty)
        XCTAssertNotNil(incomplete.explanation)
    }

    func testComparisonDoesNotTreatARPEntryAsConfirmedResponse() {
        let config = ScannerConfig.default
        let old = Device(ipAddress: "192.0.2.2", status: .online)
        let cached = Device(ipAddress: old.ipAddress, status: .cached)
        let comparison = ScanComparison(previous: snapshot(devices: [old], config: config), current: snapshot(devices: [cached], config: config))
        XCTAssertEqual(comparison.missingCount, 1)
        XCTAssertEqual(comparison.addedCount, 0)
        var changedPorts = config
        changedPorts.ports = [443]
        XCTAssertFalse(ScanComparison(previous: snapshot(devices: [old], config: config), current: snapshot(devices: [old], config: changedPorts)).isComparable)
    }

    private func snapshot(devices: [Device], config: ScannerConfig) -> ScanHistory {
        ScanHistory(startedAt: Date(), finishedAt: Date(), ipRange: "192.0.2.1-8", totalHosts: 8,
                    foundDevices: devices.count, devices: devices, profileID: config.profileID, config: config)
    }
}
