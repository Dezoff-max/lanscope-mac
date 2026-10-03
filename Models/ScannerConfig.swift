import Foundation
import SwiftUI

struct ScannerConfig: Codable, Hashable {
    static let defaultRange = "192.168.1.1-254"

    var ipRange: String
    var ports: [Int]
    var timeout: TimeInterval
    var concurrencyLimit: Int
    var vendorLookupEnabled: Bool
    var theme: AppTheme
    var maxConnections: Int
    var interfaceName: String?
    var profileID: UUID?
    var bonjourEnabled: Bool

    init(ipRange: String, ports: [Int], timeout: TimeInterval, concurrencyLimit: Int,
         vendorLookupEnabled: Bool, theme: AppTheme, maxConnections: Int = 128,
         interfaceName: String? = nil, profileID: UUID? = nil, bonjourEnabled: Bool = true) {
        self.ipRange = ipRange
        self.ports = ports
        self.timeout = timeout
        self.concurrencyLimit = concurrencyLimit
        self.vendorLookupEnabled = vendorLookupEnabled
        self.theme = theme
        self.maxConnections = maxConnections
        self.interfaceName = interfaceName
        self.profileID = profileID
        self.bonjourEnabled = bonjourEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case ipRange, ports, timeout, concurrencyLimit, vendorLookupEnabled, theme, maxConnections, interfaceName, profileID, bonjourEnabled
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        ipRange = try values.decodeIfPresent(String.self, forKey: .ipRange) ?? Self.defaultRange
        ports = try values.decodeIfPresent([Int].self, forKey: .ports) ?? ServiceCatalog.defaultPorts
        timeout = try values.decodeIfPresent(TimeInterval.self, forKey: .timeout) ?? 0.8
        concurrencyLimit = try values.decodeIfPresent(Int.self, forKey: .concurrencyLimit) ?? 64
        vendorLookupEnabled = try values.decodeIfPresent(Bool.self, forKey: .vendorLookupEnabled) ?? true
        theme = try values.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
        maxConnections = try values.decodeIfPresent(Int.self, forKey: .maxConnections) ?? 128
        interfaceName = try values.decodeIfPresent(String.self, forKey: .interfaceName)
        profileID = try values.decodeIfPresent(UUID.self, forKey: .profileID)
        bonjourEnabled = try values.decodeIfPresent(Bool.self, forKey: .bonjourEnabled) ?? true
    }

    static var `default`: ScannerConfig {
        ScannerConfig(ipRange: LocalNetworkInfo.suggestedRange() ?? defaultRange,
                      ports: ServiceCatalog.defaultPorts, timeout: 0.8, concurrencyLimit: 64,
                      vendorLookupEnabled: true, theme: .system)
    }

    func normalized() -> ScannerConfig {
        var copy = self
        copy.ipRange = copy.ipRange.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.ports = Array(Set(copy.ports.filter { (1...65535).contains($0) })).sorted()
        if copy.ports.isEmpty { copy.ports = ServiceCatalog.defaultPorts }
        copy.ports = Array(copy.ports.prefix(PortListParser.maximumPortCount))
        copy.timeout = copy.timeout.isFinite ? min(max(copy.timeout, 0.2), 10.0) : 0.8
        copy.concurrencyLimit = min(max(copy.concurrencyLimit, 1), 128)
        copy.maxConnections = min(max(copy.maxConnections, 1), 512)
        if copy.interfaceName?.isEmpty == true { copy.interfaceName = nil }
        return copy
    }
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "Системная"
        case .light: return "Светлая"
        case .dark: return "Тёмная"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
