import Darwin
import Foundation

struct BonjourRecord: Hashable, Sendable {
    let ipAddress: String
    let hostname: String
    let serviceType: String
    let port: Int
}

protocol BonjourDiscovering {
    func discover(allowedHosts: Set<String>, interfaceName: String?) async -> [BonjourRecord]
}

struct BonjourDiscovery: BonjourDiscovering {
    static let serviceTypes = ["_http._tcp.", "_https._tcp.", "_ssh._tcp.", "_smb._tcp.",
                               "_workstation._tcp.", "_ipp._tcp.", "_ipps._tcp."]

    func discover(allowedHosts: Set<String>, interfaceName: String?) async -> [BonjourRecord] {
        // NetServiceBrowser cannot bind an interface. A scoped scan must never
        // acquire hostnames from another attached network with overlapping IPs.
        guard interfaceName == nil, !allowedHosts.isEmpty, !Task.isCancelled else { return [] }
        return await BonjourSession(allowedHosts: allowedHosts).run()
    }

    static func enrich(_ devices: [Device], records: [BonjourRecord]) -> [Device] {
        let byAddress = Dictionary(grouping: records, by: \.ipAddress)
        return devices.map { original in
            guard original.status == .online, original.confirmedAt != nil,
                  let matching = byAddress[original.ipAddress], !matching.isEmpty else { return original }
            var device = original
            let records = matching.sorted {
                if $0.hostname != $1.hostname { return $0.hostname < $1.hostname }
                if $0.port != $1.port { return $0.port < $1.port }
                return $0.serviceType < $1.serviceType
            }
            if !device.hasResolvedHostname,
               let name = records.first(where: { !$0.hostname.isEmpty })?.hostname {
                device.hostname = name
            }
            // An advertisement alone never adds an open port. It only labels a
            // port already confirmed by this scan's TCP connection.
            for record in records where device.openPorts.contains(record.port) {
                guard let hint = service(for: record),
                      let index = device.services.firstIndex(where: { $0.port == record.port }) else { continue }
                if device.services[index].name == "TCP" { device.services[index] = hint }
            }
            if device.kind == .unknown {
                if records.contains(where: { ["_ipp._tcp.", "_ipps._tcp."].contains($0.serviceType) }) {
                    device.kind = .printer
                } else if records.contains(where: { $0.serviceType == "_workstation._tcp." }) {
                    device.kind = .computer
                }
            }
            if !device.observationSource.contains("Bonjour") {
                device.observationSource += device.observationSource.isEmpty ? "Bonjour" : " + Bonjour"
            }
            return device
        }
    }

    private static func service(for record: BonjourRecord) -> NetworkService? {
        let name: String
        let scheme: String?
        switch record.serviceType {
        case "_http._tcp.": name = "HTTP"; scheme = "http"
        case "_https._tcp.": name = "HTTPS"; scheme = "https"
        case "_ssh._tcp.": name = "SSH"; scheme = "ssh"
        case "_smb._tcp.": name = "SMB"; scheme = "smb"
        case "_ipp._tcp.": name = "IPP"; scheme = nil
        case "_ipps._tcp.": name = "IPPS"; scheme = nil
        default: return nil
        }
        return NetworkService(port: record.port, name: name, scheme: scheme)
    }

    static func ipv4Address(from data: Data) -> String? {
        guard data.count >= MemoryLayout<sockaddr_in>.size else { return nil }
        return data.withUnsafeBytes { bytes in
            var address = bytes.loadUnaligned(as: sockaddr_in.self)
            guard address.sin_family == sa_family_t(AF_INET),
                  Int(address.sin_len) >= MemoryLayout<sockaddr_in>.size else { return nil }
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &address.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else { return nil }
            return String(cString: buffer)
        }
    }
}

@MainActor
private final class BonjourSession: NSObject, @preconcurrency NetServiceBrowserDelegate, @preconcurrency NetServiceDelegate {
    private let allowedHosts: Set<String>
    private var browsers: [NetServiceBrowser] = []
    private var services: [String: NetService] = [:]
    private var records = Set<BonjourRecord>()
    private var continuation: CheckedContinuation<[BonjourRecord], Never>?
    private var deadline: Task<Void, Never>?
    private var finished = false

    init(allowedHosts: Set<String>) { self.allowedHosts = allowedHosts }

    func run() async -> [BonjourRecord] {
        guard !Task.isCancelled else { return [] }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                for type in BonjourDiscovery.serviceTypes {
                    let browser = NetServiceBrowser()
                    browser.includesPeerToPeer = false
                    browser.delegate = self
                    browser.schedule(in: .main, forMode: .common)
                    browsers.append(browser)
                    browser.searchForServices(ofType: type, inDomain: "local.")
                }
                deadline = Task { [weak self] in
                    do { try await Task.sleep(nanoseconds: 2_000_000_000) }
                    catch { return }
                    self?.finish()
                }
            }
        } onCancel: {
            Task { @MainActor in self.finish() }
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        guard !finished, services.count < 128 else { return }
        let key = "\(service.domain)|\(service.type)|\(service.name)"
        guard services[key] == nil else { return }
        services[key] = service
        service.delegate = self
        service.schedule(in: .main, forMode: .common)
        service.resolve(withTimeout: 1.5)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard !finished else { return }
        let hostname = (sender.hostName ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "."))
        for data in sender.addresses ?? [] {
            guard let address = BonjourDiscovery.ipv4Address(from: data), allowedHosts.contains(address) else { continue }
            records.insert(BonjourRecord(ipAddress: address, hostname: hostname, serviceType: sender.type, port: sender.port))
        }
        sender.stop()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        deadline?.cancel()
        deadline = nil
        for browser in browsers {
            browser.delegate = nil
            browser.stop()
            browser.remove(from: .main, forMode: .common)
        }
        for service in services.values {
            service.delegate = nil
            service.stop()
            service.remove(from: .main, forMode: .common)
        }
        browsers.removeAll()
        services.removeAll()
        let continuation = self.continuation
        self.continuation = nil
        continuation?.resume(returning: Array(records))
    }
}
