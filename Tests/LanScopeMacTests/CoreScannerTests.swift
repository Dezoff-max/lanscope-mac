import Foundation
import Network
import XCTest
@testable import LanScopeMac

final class CoreScannerTests: XCTestCase {
    @MainActor
    func testCachedARPDoesNotClaimCurrentReachability() async throws {
        let probes = FakeScannerProbes(reachable: false, portOpen: false)
        let scanner = NetworkScanner(arpResolver: FakeARP(entries: ["192.0.2.1": "00:11:22:33:44:55"]),
            hostnameResolver: FakeHostname(), probes: probes)
        var config = configuration()
        config.ipRange = "192.0.2.1"
        let results = try await scanner.scan(config: config) { _ in }
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.status, .cached)
        XCTAssertEqual(results.first?.observationSource, "ARP-кэш")
        XCTAssertNil(results.first?.confirmedAt)
        XCTAssertEqual(results.first?.profileID, config.profileID)
    }

    @MainActor
    func testEnrichmentPreservesPublishedRowIdentityAndEvidence() async throws {
        let probes = FakeScannerProbes(reachable: true, portOpen: false)
        let scanner = NetworkScanner(arpResolver: FakeARP(entries: ["192.0.2.1": "00:11:22:33:44:55"]),
            hostnameResolver: FakeHostname(), probes: probes)
        var config = configuration()
        config.ipRange = "192.0.2.1"
        var published: Device?
        let results = try await scanner.scan(config: config) { event in
            if case .deviceFound(let device, _, _) = event { published = device }
        }
        XCTAssertEqual(results.first?.id, published?.id)
        XCTAssertEqual(results.first?.confirmedAt, published?.confirmedAt)
        XCTAssertEqual(results.first?.latencyMS, 2.5)
        XCTAssertEqual(results.first?.observationSource, "ICMP")
        XCTAssertEqual(results.first?.status, .online)
    }

    @MainActor
    func testTCPBudgetAppliesAcrossAllHostsAndPorts() async throws {
        let probes = FakeScannerProbes(reachable: false, portOpen: true, delay: 2_000_000)
        let scanner = NetworkScanner(arpResolver: FakeARP(entries: [:]), hostnameResolver: FakeHostname(), probes: probes)
        let config = configuration()
        let results = try await scanner.scan(config: config) { _ in }
        let peak = await probes.peakConnections
        let active = await probes.activeConnections
        XCTAssertEqual(results.count, 20)
        XCTAssertEqual(peak, 3)
        XCTAssertEqual(active, 0)
        XCTAssertTrue(results.allSatisfy { $0.openPorts.count == config.ports.count })
    }

    @MainActor
    func testCancelledScanStopsQueuedProbesAndDoesNotPublishCompleted() async throws {
        let probes = FakeScannerProbes(reachable: false, portOpen: true, delay: 5_000_000_000)
        let scanner = NetworkScanner(arpResolver: FakeARP(entries: [:]), hostnameResolver: FakeHostname(), probes: probes)
        let config = configuration()
        var publishedCompletion = false
        let task = Task {
            try await scanner.scan(config: config) { event in
                if case .completed = event { publishedCompletion = true }
            }
        }
        for _ in 0..<100 {
            if await probes.activeConnections > 0 { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled scan must throw") }
        catch { XCTAssertTrue(error is CancellationError) }
        let active = await probes.activeConnections
        let started = await probes.startedConnections
        XCTAssertEqual(active, 0)
        XCTAssertLessThanOrEqual(started, config.maxConnections)
        XCTAssertFalse(publishedCompletion)
    }

    func testPingMeasurementParserAndInterfaceBindingArguments() {
        XCTAssertEqual(PingProbe.latency(in: "64 bytes from 192.0.2.1: icmp_seq=0 ttl=64 time=2.514 ms"), 2.514)
        XCTAssertNil(PingProbe.latency(in: "Request timeout for icmp_seq 0"))
        XCTAssertEqual(PingProbe.commandArguments(host: "192.0.2.1", timeout: 0.8, interfaceName: "en7"),
            ["-c", "1", "-W", "800", "-b", "en7", "192.0.2.1"])
    }

    func testDNSDeadlineDoesNotWaitForBlockingSystemLookup() async {
        let gate = DispatchSemaphore(value: 0)
        defer { gate.signal() }
        let resolver = HostnameResolver(timeout: 0.02) { _ in
            gate.wait()
            return "late.example"
        }
        let completed = expectation(description: "DNS caller returns by its deadline")
        Task {
            let result = await resolver.hostname(for: "192.0.2.1")
            XCTAssertNil(result)
            completed.fulfill()
        }
        await fulfillment(of: [completed], timeout: 1)
    }

    func testCallbackBridgeHandlesCancellationBeforeRegistrationAndIgnoresLateReply() async {
        let completion = ProbeResult<String?>()
        completion.finish(nil)
        let value = await withCheckedContinuation { continuation in
            completion.install(continuation)
            completion.finish("late")
        }
        XCTAssertNil(value)
    }

    private func configuration() -> ScannerConfig {
        ScannerConfig(ipRange: "192.0.2.1-20", ports: [22, 80, 443, 445, 8080, 5900], timeout: 0.2,
            concurrencyLimit: 20, vendorLookupEnabled: false, theme: .system, maxConnections: 3, profileID: UUID())
    }
}

private struct FakeARP: ARPResolving {
    let entries: [String: String]
    func resolvedIPv4Entries() -> [String: String] { entries }
}

private struct FakeHostname: HostnameResolving {
    func hostname(for ipAddress: String) async -> String? { nil }
}

private actor FakeScannerProbes: ScannerProbing {
    let reachable: Bool
    let portOpen: Bool
    let delay: UInt64
    private(set) var activeConnections = 0
    private(set) var peakConnections = 0
    private(set) var startedConnections = 0

    init(reachable: Bool, portOpen: Bool, delay: UInt64 = 0) {
        self.reachable = reachable
        self.portOpen = portOpen
        self.delay = delay
    }
    func ping(host: String, timeout: TimeInterval, interfaceName: String?) async -> PingMeasurement {
        PingMeasurement(reachable: reachable, latencyMS: reachable ? 2.5 : nil)
    }
    func isPortOpen(host: String, port: Int, timeout: TimeInterval, interface: NWInterface?) async -> Bool {
        activeConnections += 1
        startedConnections += 1
        peakConnections = max(peakConnections, activeConnections)
        defer { activeConnections -= 1 }
        do { if delay > 0 { try await Task.sleep(nanoseconds: delay) } }
        catch { return false }
        return portOpen
    }
}
