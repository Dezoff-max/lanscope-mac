import Darwin
import Network
import XCTest
@testable import LanScopeMac

final class CoreBonjourTests: XCTestCase {
    func testAdvertisementsOnlyEnrichCurrentlyConfirmedDevices() {
        let now = Date()
        let online = Device(ipAddress: "192.0.2.1", status: .online, lastSeen: now,
                            observationSource: "ICMP", confirmedAt: now)
        let cached = Device(ipAddress: "192.0.2.2", status: .cached, observationSource: "ARP-кэш")
        let unconfirmed = Device(ipAddress: "192.0.2.3", status: .online)
        let records = ["192.0.2.1", "192.0.2.2", "192.0.2.3", "192.0.2.99"].map {
            BonjourRecord(ipAddress: $0, hostname: "office-mac.local", serviceType: "_workstation._tcp.", port: 9)
        }
        let result = BonjourDiscovery.enrich([online, cached, unconfirmed], records: records)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].id, online.id)
        XCTAssertEqual(result[0].hostname, "office-mac.local")
        XCTAssertEqual(result[0].kind, .computer)
        XCTAssertEqual(result[0].confirmedAt, now)
        XCTAssertEqual(result[0].lastSeen, now)
        XCTAssertEqual(result[0].observationSource, "ICMP + Bonjour")
        XCTAssertEqual(result[1], cached)
        XCTAssertEqual(result[2], unconfirmed)
    }

    func testBonjourDoesNotInventOpenPortsOrReplaceExistingIdentity() {
        let device = Device(ipAddress: "192.0.2.1", hostname: "dns-name.example", status: .online,
            openPorts: [8443], services: [NetworkService(port: 8443, name: "TCP", scheme: nil)],
            customName: "Мост1", kind: .bridge, observationSource: "TCP", confirmedAt: Date())
        let records = [
            BonjourRecord(ipAddress: device.ipAddress, hostname: "mdns-name.local", serviceType: "_https._tcp.", port: 8443),
            BonjourRecord(ipAddress: device.ipAddress, hostname: "mdns-name.local", serviceType: "_ssh._tcp.", port: 22),
            BonjourRecord(ipAddress: device.ipAddress, hostname: "mdns-name.local", serviceType: "_ipp._tcp.", port: 631)
        ]
        let result = BonjourDiscovery.enrich([device], records: records)[0]
        XCTAssertEqual(result.hostname, "dns-name.example")
        XCTAssertEqual(result.customName, "Мост1")
        XCTAssertEqual(result.kind, .bridge)
        XCTAssertEqual(result.openPorts, [8443])
        XCTAssertEqual(result.services, [NetworkService(port: 8443, name: "HTTPS", scheme: "https")])
        XCTAssertEqual(BonjourDiscovery.enrich([result], records: records)[0].observationSource, "TCP + Bonjour")
    }

    func testIPv4ServiceAddressParsingRejectsTruncatedAndIPv6Data() {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        inet_pton(AF_INET, "192.0.2.17", &address.sin_addr)
        let data = withUnsafeBytes(of: &address) { Data($0) }
        XCTAssertEqual(BonjourDiscovery.ipv4Address(from: data), "192.0.2.17")
        XCTAssertNil(BonjourDiscovery.ipv4Address(from: Data(data.prefix(8))))
        var invalid = data
        invalid[1] = UInt8(AF_INET6)
        XCTAssertNil(BonjourDiscovery.ipv4Address(from: invalid))
    }

    func testExplicitInterfaceSkipsUnscopedDiscovery() async {
        let result = await BonjourDiscovery().discover(allowedHosts: ["192.0.2.1"], interfaceName: "en0")
        XCTAssertTrue(result.isEmpty)
    }

    @MainActor
    func testScannerUsesInjectedDiscoveryAndHonorsDisabledConfiguration() async throws {
        let discovery = FakeBonjourDiscovery()
        let scanner = NetworkScanner(arpResolver: EmptyBonjourARP(), hostnameResolver: EmptyBonjourHostname(),
                                     probes: BonjourTestProbes(), bonjourDiscovery: discovery)
        var config = ScannerConfig(ipRange: "192.0.2.1", ports: [80], timeout: 0.2, concurrencyLimit: 1,
                                   vendorLookupEnabled: false, theme: .system)
        let enabled = try await scanner.scan(config: config) { _ in }
        XCTAssertEqual(enabled.first?.hostname, "test-host.local")
        let hosts = await discovery.lastAllowedHosts
        XCTAssertEqual(hosts, ["192.0.2.1"])
        config.bonjourEnabled = false
        let disabled = try await scanner.scan(config: config) { _ in }
        XCTAssertEqual(disabled.first?.hostname, "")
        let calls = await discovery.calls
        XCTAssertEqual(calls, 1)
    }
}

private actor FakeBonjourDiscovery: BonjourDiscovering {
    private(set) var calls = 0
    private(set) var lastAllowedHosts: Set<String> = []
    func discover(allowedHosts: Set<String>, interfaceName: String?) async -> [BonjourRecord] {
        calls += 1
        lastAllowedHosts = allowedHosts
        return [BonjourRecord(ipAddress: "192.0.2.1", hostname: "test-host.local", serviceType: "_http._tcp.", port: 80)]
    }
}

private struct EmptyBonjourARP: ARPResolving {
    func resolvedIPv4Entries() -> [String: String] { [:] }
}
private struct EmptyBonjourHostname: HostnameResolving {
    func hostname(for ipAddress: String) async -> String? { nil }
}
private struct BonjourTestProbes: ScannerProbing {
    func ping(host: String, timeout: TimeInterval, interfaceName: String?) async -> PingMeasurement {
        PingMeasurement(reachable: true, latencyMS: 1)
    }
    func isPortOpen(host: String, port: Int, timeout: TimeInterval, interface: NWInterface?) async -> Bool { true }
}
