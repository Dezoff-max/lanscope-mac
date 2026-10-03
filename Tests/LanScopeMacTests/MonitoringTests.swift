import XCTest
@testable import LanScopeMac

final class MonitoringTests: XCTestCase {
    func testDeviceIdentitySeparatesProfilesAndFollowsMACAcrossDHCPChanges() {
        var first = Device(ipAddress: "192.0.2.10", macAddress: "00:11:22:33:44:55")
        first.profileID = UUID()
        var moved = first
        moved.ipAddress = "192.0.2.11"
        moved.macAddress = "00-11-22-33-44-55"
        XCTAssertEqual(DeviceMonitorKey(device: first), DeviceMonitorKey(device: moved))
        moved.profileID = UUID()
        XCTAssertNotEqual(DeviceMonitorKey(device: first), DeviceMonitorKey(device: moved))
    }

    func testHistoryIsBoundedByTimeAndCountAndLossIncludesMissingReplies() {
        var snapshot = DeviceMonitorSnapshot()
        let start = Date(timeIntervalSince1970: 1_000)
        for index in 0..<601 {
            snapshot.append(
                MonitorSample(timestamp: start.addingTimeInterval(Double(index)), reachable: index % 2 == 0, latencyMS: 12),
                historyDuration: 300,
                maximumSamples: 300
            )
        }
        XCTAssertEqual(snapshot.samples.count, 300)
        XCTAssertGreaterThanOrEqual(snapshot.samples.first!.timestamp, start.addingTimeInterval(300))
        XCTAssertEqual(snapshot.lossPercent, 50)
        XCTAssertEqual(snapshot.averageLatencyMS, 12)
        XCTAssertNil(snapshot.samples.first(where: { !$0.reachable })?.latencyMS)
    }

    @MainActor
    func testThresholdSuppressesSingleLossAndEmitsOnlyOneOfflineAndRecoveryEvent() async {
        let sequence = MeasurementSequence([true, false, true, false, false, false, false, true, true])
        let store = DeviceMonitorStore(observeSystem: false, probe: { _, _, _ in await sequence.next() })
        let device = Device(ipAddress: "192.0.2.10")
        var changes: [Bool] = []
        store.onStatusChange = { _, reachable in changes.append(reachable) }
        let initialCalls = await sequence.calls
        XCTAssertEqual(initialCalls, 0, "Creating the store must not probe the network")

        for _ in 0..<5 { await store.probeOnce(device: device) }
        XCTAssertEqual(store.snapshot(for: device).consecutiveFailures, 2)
        XCTAssertTrue(changes.isEmpty)
        XCTAssertEqual(store.snapshot(for: device).confirmedReachable, true)

        await store.probeOnce(device: device)
        XCTAssertEqual(changes, [false])
        await store.probeOnce(device: device)
        XCTAssertEqual(changes, [false])
        await store.probeOnce(device: device)
        await store.probeOnce(device: device)
        XCTAssertEqual(changes, [false, true])
        XCTAssertEqual(store.events.count, 2)
        XCTAssertFalse(store.isMonitoring(device), "One-off probes must not enable periodic monitoring")
    }

    @MainActor
    func testStopRejectsLateResultFromUncooperativeProbe() async {
        let gate = MeasurementGate()
        let store = DeviceMonitorStore(observeSystem: false, probe: { _, _, _ in await gate.measure() })
        let device = Device(ipAddress: "192.0.2.10")
        let check = Task { await store.probeOnce(device: device) }
        await gate.waitUntilStarted()
        XCTAssertTrue(store.snapshot(for: device).isProbing)

        store.stop(device: device)
        await gate.complete()
        await check.value

        XCTAssertFalse(store.snapshot(for: device).isProbing)
        XCTAssertTrue(store.samples(for: device).isEmpty)
        XCTAssertTrue(store.events.isEmpty)
    }

    @MainActor
    func testInterfaceIsForwardedAndSeparateProfilesHaveIndependentSamples() async {
        let recorder = ProbeRecorder()
        let store = DeviceMonitorStore(observeSystem: false, probe: { host, _, interface in
            await recorder.measure(host: host, interface: interface)
        })
        var first = Device(ipAddress: "192.0.2.10")
        first.profileID = UUID()
        var second = first
        second.profileID = UUID()

        await store.probeOnce(device: first, interfaceName: "en7")
        XCTAssertEqual(store.samples(for: first).count, 1)
        XCTAssertTrue(store.samples(for: second).isEmpty)
        let observedInterface = await recorder.lastInterface
        XCTAssertEqual(observedInterface, "en7")
    }
}

private actor MeasurementSequence {
    let values: [Bool]
    private(set) var calls = 0

    init(_ values: [Bool]) { self.values = values }

    func next() -> PingMeasurement {
        let reachable = values[min(calls, values.count - 1)]
        calls += 1
        return PingMeasurement(reachable: reachable, latencyMS: reachable ? 10 : nil)
    }
}

private actor MeasurementGate {
    private var result: CheckedContinuation<PingMeasurement, Never>?
    private var started: CheckedContinuation<Void, Never>?

    func measure() async -> PingMeasurement {
        await withCheckedContinuation { continuation in
            result = continuation
            started?.resume()
            started = nil
        }
    }

    func waitUntilStarted() async {
        if result != nil { return }
        await withCheckedContinuation { started = $0 }
    }

    func complete() {
        result?.resume(returning: PingMeasurement(reachable: true, latencyMS: 10))
        result = nil
    }
}

private actor ProbeRecorder {
    private(set) var lastInterface: String?

    func measure(host: String, interface: String?) -> PingMeasurement {
        lastInterface = interface
        return PingMeasurement(reachable: true, latencyMS: 2)
    }
}
