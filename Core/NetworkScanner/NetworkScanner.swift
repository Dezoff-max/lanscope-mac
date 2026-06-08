import Foundation
import Network

enum ScanProgressEvent {
    case started(total: Int)
    case hostFinished(completed: Int, total: Int)
    case deviceFound(Device, completed: Int, total: Int)
    case completed([Device], total: Int)
}

final class NetworkScanner {
    private let arpResolver: ARPResolving
    private let vendorLookup: VendorLookup
    private let hostnameResolver: HostnameResolving

    init(
        arpResolver: ARPResolving = ARPResolver(),
        vendorLookup: VendorLookup = VendorLookup(),
        hostnameResolver: HostnameResolving = HostnameResolver()
    ) {
        self.arpResolver = arpResolver
        self.vendorLookup = vendorLookup
        self.hostnameResolver = hostnameResolver
    }

    var vendorDatabaseCount: Int {
        vendorLookup.vendorCount
    }

    @discardableResult
    func reloadVendorDatabase() -> Int {
        vendorLookup.reload()
    }

    func scan(
        config: ScannerConfig,
        onEvent: @MainActor @escaping (ScanProgressEvent) -> Void
    ) async throws -> [Device] {
        if config.mockMode {
            return try await mockScan(onEvent: onEvent)
        }

        let hosts = try IPRangeParser.hosts(in: config.ipRange)
        let total = hosts.count
        await onEvent(.started(total: total))

        guard !hosts.isEmpty else {
            await onEvent(.completed([], total: 0))
            return []
        }

        let limit = min(max(config.concurrencyLimit, 1), total)
        var iterator = hosts.makeIterator()
        var completed = 0
        var results: [Device] = []

        try await withThrowingTaskGroup(of: Device?.self) { group in
            for _ in 0..<limit {
                guard let ipAddress = iterator.next() else {
                    break
                }
                group.addTask {
                    try Task.checkCancellation()
                    return await self.scanHost(ipAddress, config: config)
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
                        return await self.scanHost(ipAddress, config: config)
                    }
                }
            }
        }

        let sortedResults = results.sorted { IPAddressSorter.compare($0.ipAddress, $1.ipAddress) }
        await onEvent(.completed(sortedResults, total: total))
        return sortedResults
    }

    private func scanHost(_ ipAddress: String, config: ScannerConfig) async -> Device? {
        async let openPortsResult = scanPorts(ipAddress: ipAddress, ports: config.ports, timeout: config.timeout)
        async let pingResult = PingProbe.isReachable(host: ipAddress, timeout: config.timeout)

        let openPorts = await openPortsResult
        let isReachableByPing = await pingResult
        // macOS exposes peer MAC addresses through the normal ARP cache without root.
        // If the cache has no entry, MVP safely falls back to Unknown instead of using privileged raw sockets.
        let macAddress = arpResolver.macAddress(for: ipAddress)

        guard isReachableByPing || !openPorts.isEmpty || macAddress != nil else {
            return nil
        }

        let services = openPorts.map { ServiceCatalog.service(for: $0) }
        let hostname = await hostnameResolver.hostname(for: ipAddress) ?? ""
        let vendor = config.vendorLookupEnabled ? vendorLookup.vendor(for: macAddress) : "Unknown"

        return Device(
            ipAddress: ipAddress,
            hostname: hostname,
            macAddress: macAddress,
            vendor: vendor,
            status: .online,
            openPorts: openPorts,
            services: services,
            lastSeen: Date()
        )
    }

    private func scanPorts(ipAddress: String, ports: [Int], timeout: TimeInterval) async -> [Int] {
        await withTaskGroup(of: Int?.self) { group in
            for port in ports {
                group.addTask {
                    if Task.isCancelled {
                        return nil
                    }
                    return await PortProbe.isOpen(host: ipAddress, port: port, timeout: timeout) ? port : nil
                }
            }

            var openPorts: [Int] = []
            for await result in group {
                if let port = result {
                    openPorts.append(port)
                }
            }
            return openPorts.sorted()
        }
    }

    private func mockScan(onEvent: @MainActor @escaping (ScanProgressEvent) -> Void) async throws -> [Device] {
        let sampleDevices = MockDevices.sample
        let total = 24
        await onEvent(.started(total: total))

        for index in 1...total {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 80_000_000)
            if index <= sampleDevices.count {
                await onEvent(.deviceFound(sampleDevices[index - 1], completed: index, total: total))
            } else {
                await onEvent(.hostFinished(completed: index, total: total))
            }
        }

        await onEvent(.completed(sampleDevices, total: total))
        return sampleDevices
    }
}
