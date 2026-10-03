import Foundation
import Network

enum ScanProgressEvent {
    case started(total: Int)
    case hostFinished(completed: Int, total: Int)
    case deviceFound(Device, completed: Int, total: Int)
    case completed([Device], total: Int)
}

protocol ScannerProbing {
    func ping(host: String, timeout: TimeInterval, interfaceName: String?) async -> PingMeasurement
    func isPortOpen(host: String, port: Int, timeout: TimeInterval, interface: NWInterface?) async -> Bool
}

struct SystemScannerProbes: ScannerProbing {
    func ping(host: String, timeout: TimeInterval, interfaceName: String?) async -> PingMeasurement {
        await PingProbe.measure(host: host, timeout: timeout, interfaceName: interfaceName)
    }
    func isPortOpen(host: String, port: Int, timeout: TimeInterval, interface: NWInterface?) async -> Bool {
        await PortProbe.isOpen(host: host, port: port, timeout: timeout, interface: interface)
    }
}

enum NetworkScannerError: LocalizedError {
    case interfaceUnavailable(String)
    var errorDescription: String? {
        switch self {
        case .interfaceUnavailable(let name):
            return "Интерфейс \(name) недоступен. Проверьте подключение или выберите другой интерфейс."
        }
    }
}

final class NetworkScanner {
    private let arpResolver: ARPResolving
    private let vendorLookup: VendorLookup
    private let hostnameResolver: HostnameResolving
    private let probes: ScannerProbing
    private let bonjourDiscovery: BonjourDiscovering?

    init(arpResolver: ARPResolving = ARPResolver(), vendorLookup: VendorLookup = VendorLookup(),
         hostnameResolver: HostnameResolving = HostnameResolver(), probes: ScannerProbing = SystemScannerProbes(),
         bonjourDiscovery: BonjourDiscovering? = nil) {
        self.arpResolver = arpResolver
        self.vendorLookup = vendorLookup
        self.hostnameResolver = hostnameResolver
        self.probes = probes
        // Injecting probes keeps unit tests entirely offline unless a fake discovery is also supplied.
        self.bonjourDiscovery = bonjourDiscovery ?? (probes is SystemScannerProbes ? BonjourDiscovery() : nil)
    }

    var vendorDatabaseCount: Int { vendorLookup.vendorCount }
    @discardableResult func reloadVendorDatabase() -> Int { vendorLookup.reload() }

    func scan(config: ScannerConfig, onEvent: @MainActor @escaping (ScanProgressEvent) -> Void) async throws -> [Device] {
        try Task.checkCancellation()
        let config = config.normalized()
        let hosts = try IPRangeParser.hosts(in: config.ipRange)
        let total = hosts.count
        var interface: NWInterface?
        if let name = config.interfaceName, !name.isEmpty {
            interface = await PortProbe.interface(named: name)
            try Task.checkCancellation()
            guard interface != nil else { throw NetworkScannerError.interfaceUnavailable(name) }
        }
        let selectedInterface = interface
        await onEvent(.started(total: total))
        guard !hosts.isEmpty else {
            await onEvent(.completed([], total: 0))
            return []
        }

        async let bonjourRecords = discoverBonjour(config: config, allowedHosts: Set(hosts))

        // A connection budget is shared by all hosts, never multiplied by port count.
        let budget = ConnectionBudget(limit: config.maxConnections)
        let limit = min(max(config.concurrencyLimit, 1), 128, total)
        var iterator = hosts.makeIterator()
        var completed = 0
        var results: [Device] = []
        try await withThrowingTaskGroup(of: Device?.self) { group in
            for _ in 0..<limit {
                guard let ipAddress = iterator.next() else { break }
                group.addTask {
                    try Task.checkCancellation()
                    return await self.scanHost(ipAddress, config: config, budget: budget, interface: selectedInterface)
                }
            }
            while let result = try await group.next() {
                try Task.checkCancellation()
                completed += 1
                if let device = result {
                    results.append(device)
                    await onEvent(.deviceFound(device, completed: completed, total: total))
                } else {
                    await onEvent(.hostFinished(completed: completed, total: total))
                }
                if let ipAddress = iterator.next() {
                    group.addTask {
                        try Task.checkCancellation()
                        return await self.scanHost(ipAddress, config: config, budget: budget, interface: selectedInterface)
                    }
                }
            }
        }
        try Task.checkCancellation()
        let records = await bonjourRecords
        let enriched = BonjourDiscovery.enrich(results, records: records)
        let sortedResults = enrichWithARPSnapshot(enriched, scannedHosts: hosts, config: config)
            .sorted { IPAddressSorter.compare($0.ipAddress, $1.ipAddress) }
        try Task.checkCancellation()
        await onEvent(.completed(sortedResults, total: total))
        return sortedResults
    }

    private func discoverBonjour(config: ScannerConfig, allowedHosts: Set<String>) async -> [BonjourRecord] {
        guard config.bonjourEnabled, config.interfaceName == nil, let bonjourDiscovery, !Task.isCancelled else { return [] }
        return await bonjourDiscovery.discover(allowedHosts: allowedHosts, interfaceName: config.interfaceName)
    }

    private func scanHost(_ ipAddress: String, config: ScannerConfig, budget: ConnectionBudget, interface: NWInterface?) async -> Device? {
        async let portsResult = scanPorts(ipAddress: ipAddress, config: config, budget: budget, interface: interface)
        async let pingResult = probes.ping(host: ipAddress, timeout: config.timeout, interfaceName: config.interfaceName)
        let openPorts = await portsResult
        let ping = await pingResult
        guard !Task.isCancelled, ping.reachable || !openPorts.isEmpty else { return nil }
        let confirmedAt = Date()
        let hostname = await hostnameResolver.hostname(for: ipAddress) ?? ""
        guard !Task.isCancelled else { return nil }
        let source = ping.reachable ? (openPorts.isEmpty ? "ICMP" : "ICMP + TCP") : "TCP"
        return Device(ipAddress: ipAddress, hostname: hostname, status: .online,
                      openPorts: openPorts, services: openPorts.map { ServiceCatalog.service(for: $0) },
                      lastSeen: confirmedAt, profileID: config.profileID, observationSource: source,
                      confirmedAt: confirmedAt, latencyMS: ping.latencyMS)
    }

    private func enrichWithARPSnapshot(_ devices: [Device], scannedHosts: [String], config: ScannerConfig) -> [Device] {
        let scannedHostSet = Set(scannedHosts)
        let arpEntries = arpResolver.resolvedIPv4Entries(interfaceName: config.interfaceName)
        var devicesByIP = Dictionary(uniqueKeysWithValues: devices.map { ($0.ipAddress, $0) })
        for (ipAddress, macAddress) in arpEntries where scannedHostSet.contains(ipAddress) {
            // Preserve the UUID published in deviceFound, including after MAC enrichment.
            var device = devicesByIP[ipAddress] ?? Device(ipAddress: ipAddress, status: .cached,
                profileID: config.profileID, observationSource: "ARP-кэш")
            device.macAddress = macAddress
            device.vendor = config.vendorLookupEnabled ? vendorLookup.vendor(for: macAddress) : "Unknown"
            devicesByIP[ipAddress] = device
        }
        return Array(devicesByIP.values)
    }

    private func scanPorts(ipAddress: String, config: ScannerConfig, budget: ConnectionBudget, interface: NWInterface?) async -> [Int] {
        await withTaskGroup(of: Int?.self) { group in
            var iterator = config.ports.makeIterator()
            // Bound waiting work as well as open sockets, even for all 65535 ports.
            let workerCount = min(8, config.maxConnections, config.ports.count)
            for _ in 0..<workerCount {
                guard let port = iterator.next() else { break }
                group.addTask { await self.scanPort(port, host: ipAddress, config: config, budget: budget, interface: interface) }
            }
            var openPorts: [Int] = []
            for await result in group {
                if Task.isCancelled { group.cancelAll(); continue }
                if let port = result { openPorts.append(port) }
                if let port = iterator.next() {
                    group.addTask { await self.scanPort(port, host: ipAddress, config: config, budget: budget, interface: interface) }
                }
            }
            return openPorts.sorted()
        }
    }

    private func scanPort(_ port: Int, host: String, config: ScannerConfig, budget: ConnectionBudget, interface: NWInterface?) async -> Int? {
        do { try await budget.acquire() } catch { return nil }
        let isOpen: Bool
        if Task.isCancelled { isOpen = false }
        else { isOpen = await probes.isPortOpen(host: host, port: port, timeout: config.timeout, interface: interface) }
        await budget.release()
        return isOpen ? port : nil
    }
}

actor ConnectionBudget {
    private var available: Int
    private var waiting: [(UUID, CheckedContinuation<Void, Error>)] = []

    init(limit: Int) { available = max(1, limit) }

    func acquire() async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if available > 0 {
                    available -= 1
                    continuation.resume()
                } else { waiting.append((id, continuation)) }
            }
        } onCancel: { Task { await self.cancel(id) } }
    }

    func release() {
        if waiting.isEmpty { available += 1 }
        else { waiting.removeFirst().1.resume() }
    }

    private func cancel(_ id: UUID) {
        guard let index = waiting.firstIndex(where: { $0.0 == id }) else { return }
        waiting.remove(at: index).1.resume(throwing: CancellationError())
    }
}
