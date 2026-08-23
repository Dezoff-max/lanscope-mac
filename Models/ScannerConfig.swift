import Foundation
import SwiftUI

struct ScannerConfig: Codable, Equatable {
    static let defaultRange = "192.168.1.1-254"

    var ipRange: String
    var ports: [Int]
    var timeout: TimeInterval
    var concurrencyLimit: Int
    var vendorLookupEnabled: Bool
    var theme: AppTheme

    static var `default`: ScannerConfig {
        ScannerConfig(
            ipRange: LocalNetworkInfo.suggestedRange() ?? defaultRange,
            ports: ServiceCatalog.defaultPorts,
            timeout: 0.8,
            concurrencyLimit: 64,
            vendorLookupEnabled: true,
            theme: .system
        )
    }

    func normalized() -> ScannerConfig {
        var copy = self
        copy.ipRange = copy.ipRange.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.ports = Array(Set(copy.ports.filter { (1...65535).contains($0) })).sorted()
        if copy.ports.isEmpty {
            copy.ports = ServiceCatalog.defaultPorts
        }
        copy.timeout = min(max(copy.timeout, 0.2), 10.0)
        copy.concurrencyLimit = min(max(copy.concurrencyLimit, 1), 512)
        return copy
    }
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
