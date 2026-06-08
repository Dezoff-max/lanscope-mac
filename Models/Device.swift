import Foundation

struct Device: Codable, Hashable, Identifiable {
    var id: UUID
    var ipAddress: String
    var hostname: String
    var macAddress: String?
    var vendor: String
    var status: DeviceStatus
    var openPorts: [Int]
    var services: [NetworkService]
    var lastSeen: Date
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        ipAddress: String,
        hostname: String = "",
        macAddress: String? = nil,
        vendor: String = "Unknown",
        status: DeviceStatus = .online,
        openPorts: [Int] = [],
        services: [NetworkService] = [],
        lastSeen: Date = Date(),
        isFavorite: Bool = false
    ) {
        self.id = id
        self.ipAddress = ipAddress
        self.hostname = hostname
        self.macAddress = macAddress
        self.vendor = vendor
        self.status = status
        self.openPorts = openPorts
        self.services = services
        self.lastSeen = lastSeen
        self.isFavorite = isFavorite
    }

    var displayName: String {
        let trimmedHostname = hostname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedHostname.isEmpty ? ipAddress : trimmedHostname
    }

    var hasResolvedHostname: Bool {
        let trimmedHostname = hostname.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedHostname.isEmpty && trimmedHostname != ipAddress
    }

    var tableNameSubtitle: String? {
        if hasResolvedHostname {
            return ipAddress
        }

        if vendor != "Unknown" && vendor != "Locally Administered" {
            return vendor
        }

        return macAddress
    }

    var openPortsDisplay: String {
        openPorts.isEmpty ? "-" : openPorts.map(String.init).joined(separator: ", ")
    }

    var servicesDisplay: String {
        services.isEmpty ? "-" : services.map(\.name).joined(separator: ", ")
    }

    var statusSortValue: String {
        status.rawValue
    }

    var nameSortValue: String {
        displayName.localizedLowercase
    }

    var ipSortValue: UInt32 {
        IPv4Address(ipAddress)?.value ?? UInt32.max
    }

    var macSortValue: String {
        macAddress ?? ""
    }

    var vendorSortValue: String {
        vendor.localizedLowercase
    }

    var openPortsSortValue: String {
        openPorts.map { String(format: "%05d", $0) }.joined(separator: ",")
    }

    var servicesSortValue: String {
        servicesDisplay.localizedLowercase
    }

    var hasWebService: Bool {
        openPorts.contains(80) || openPorts.contains(443) || openPorts.contains(8080)
    }

    var hasSSH: Bool {
        openPorts.contains(22)
    }

    var hasSMB: Bool {
        openPorts.contains(445)
    }

    var hasVNC: Bool {
        openPorts.contains(5900)
    }

    func matches(_ other: Device) -> Bool {
        if let macAddress, let otherMAC = other.macAddress, macAddress.caseInsensitiveCompare(otherMAC) == .orderedSame {
            return true
        }
        return ipAddress == other.ipAddress
    }
}
