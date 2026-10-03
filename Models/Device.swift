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
    var profileID: UUID?
    var customName: String
    var notes: String
    var tags: [String]
    var kind: DeviceKind
    var observationSource: String
    var confirmedAt: Date?
    var latencyMS: Double?

    init(
        id: UUID = UUID(), ipAddress: String, hostname: String = "", macAddress: String? = nil,
        vendor: String = "Unknown", status: DeviceStatus = .online, openPorts: [Int] = [],
        services: [NetworkService] = [], lastSeen: Date = Date(), isFavorite: Bool = false,
        profileID: UUID? = nil, customName: String = "", notes: String = "", tags: [String] = [],
        kind: DeviceKind = .unknown, observationSource: String = "", confirmedAt: Date? = nil,
        latencyMS: Double? = nil
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
        self.profileID = profileID
        self.customName = customName
        self.notes = notes
        self.tags = tags
        self.kind = kind
        self.observationSource = observationSource
        self.confirmedAt = confirmedAt
        self.latencyMS = latencyMS
    }

    private enum CodingKeys: String, CodingKey {
        case id, ipAddress, hostname, macAddress, vendor, status, openPorts, services, lastSeen, isFavorite
        case profileID, customName, notes, tags, kind, observationSource, confirmedAt, latencyMS
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        ipAddress = try values.decode(String.self, forKey: .ipAddress)
        hostname = try values.decodeIfPresent(String.self, forKey: .hostname) ?? ""
        macAddress = try values.decodeIfPresent(String.self, forKey: .macAddress)
        vendor = try values.decodeIfPresent(String.self, forKey: .vendor) ?? "Unknown"
        status = try values.decodeIfPresent(DeviceStatus.self, forKey: .status) ?? .unknown
        openPorts = try values.decodeIfPresent([Int].self, forKey: .openPorts) ?? []
        services = try values.decodeIfPresent([NetworkService].self, forKey: .services) ?? []
        lastSeen = try values.decodeIfPresent(Date.self, forKey: .lastSeen) ?? .distantPast
        isFavorite = try values.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        profileID = try values.decodeIfPresent(UUID.self, forKey: .profileID)
        customName = try values.decodeIfPresent(String.self, forKey: .customName) ?? ""
        notes = try values.decodeIfPresent(String.self, forKey: .notes) ?? ""
        tags = try values.decodeIfPresent([String].self, forKey: .tags) ?? []
        kind = try values.decodeIfPresent(DeviceKind.self, forKey: .kind) ?? .unknown
        observationSource = try values.decodeIfPresent(String.self, forKey: .observationSource) ?? ""
        confirmedAt = try values.decodeIfPresent(Date.self, forKey: .confirmedAt)
        latencyMS = try values.decodeIfPresent(Double.self, forKey: .latencyMS)
    }

    var vendorDisplay: String {
        switch vendor {
        case "Unknown": return "Не определён"
        case "Locally Administered": return "Локальный MAC-адрес"
        default: return vendor
        }
    }

    var displayName: String {
        let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        let resolved = hostname.trimmingCharacters(in: .whitespacesAndNewlines)
        return resolved.isEmpty ? ipAddress : resolved
    }

    var hasResolvedHostname: Bool {
        let resolved = hostname.trimmingCharacters(in: .whitespacesAndNewlines)
        return !resolved.isEmpty && resolved != ipAddress
    }

    var tableNameSubtitle: String? {
        if !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasResolvedHostname { return ipAddress }
        if vendor != "Unknown" && vendor != "Locally Administered" { return vendor }
        return macAddress
    }

    var openPortsDisplay: String { openPorts.isEmpty ? "—" : openPorts.map(String.init).joined(separator: ", ") }
    var servicesDisplay: String { services.isEmpty ? "—" : services.map(\.name).joined(separator: ", ") }
    var statusSortValue: String { status.rawValue }
    var nameSortValue: String { displayName.localizedLowercase }
    var ipSortValue: UInt32 { IPv4Address(ipAddress)?.value ?? UInt32.max }
    var macSortValue: String { macAddress ?? "" }
    var vendorSortValue: String { vendor.localizedLowercase }
    var openPortsSortValue: String { openPorts.map { String(format: "%05d", $0) }.joined(separator: ",") }
    var servicesSortValue: String { servicesDisplay.localizedLowercase }
    var hasWebService: Bool { openPorts.contains(80) || openPorts.contains(443) || openPorts.contains(8080) || openPorts.contains(8443) }
    var hasSSH: Bool { openPorts.contains(22) }
    var hasSMB: Bool { openPorts.contains(445) }
    var hasVNC: Bool { openPorts.contains(5900) }

    /// A known MAC takes priority over an IP address, which may be reassigned by DHCP.
    func matches(_ other: Device) -> Bool {
        if let profileID, let otherProfile = other.profileID, profileID != otherProfile { return false }
        if let mac = normalizedMAC, let otherMAC = other.normalizedMAC { return mac == otherMAC }
        return ipAddress == other.ipAddress
    }

    var normalizedMAC: String? {
        guard let macAddress else { return nil }
        let value = macAddress.lowercased().filter { $0.isHexDigit }
        return value.count == 12 ? value : nil
    }
}

enum DeviceKind: String, Codable, CaseIterable, Identifiable {
    case unknown, router, switchDevice, computer, phone, nas, camera, printer, server, bridge, accessPoint

    var id: String { rawValue }
    var title: String {
        switch self {
        case .unknown: return "Устройство"
        case .router: return "Маршрутизатор"
        case .switchDevice: return "Коммутатор"
        case .computer: return "Компьютер"
        case .phone: return "Телефон"
        case .nas: return "Хранилище NAS"
        case .camera: return "Камера"
        case .printer: return "Принтер"
        case .server: return "Сервер"
        case .bridge: return "Радиомост"
        case .accessPoint: return "Точка доступа"
        }
    }
    var systemImage: String {
        switch self {
        case .unknown: return "network"
        case .router: return "wifi.router"
        case .switchDevice: return "point.3.connected.trianglepath.dotted"
        case .computer: return "desktopcomputer"
        case .phone: return "iphone"
        case .nas: return "externaldrive.connected.to.line.below"
        case .camera: return "web.camera"
        case .printer: return "printer"
        case .server: return "server.rack"
        case .bridge: return "antenna.radiowaves.left.and.right"
        case .accessPoint: return "wifi"
        }
    }
}
