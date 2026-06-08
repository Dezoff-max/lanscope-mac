import Foundation

final class VendorLookup {
    private var vendors: [String: String]
    private let resourceName: String

    init(resourceName: String = "oui") {
        self.resourceName = resourceName
        self.vendors = OUIDatabaseStore.loadMergedVendors(resourceName: resourceName)
    }

    var vendorCount: Int {
        vendors.count
    }

    @discardableResult
    func reload() -> Int {
        vendors = OUIDatabaseStore.loadMergedVendors(resourceName: resourceName)
        return vendors.count
    }

    func vendor(for macAddress: String?) -> String {
        guard let macAddress,
              let oui = ouiKey(for: macAddress) else {
            return "Unknown"
        }

        if let vendor = vendors[oui] {
            return vendor
        }

        if isLocallyAdministered(macAddress) {
            return "Locally Administered"
        }

        return "Unknown"
    }

    private func ouiKey(for macAddress: String) -> String? {
        let normalized = macAddress
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()

        guard normalized.count >= 6 else {
            return nil
        }

        return String(normalized.prefix(6))
    }

    private func isLocallyAdministered(_ macAddress: String) -> Bool {
        let firstOctet = macAddress
            .replacingOccurrences(of: "-", with: ":")
            .split(separator: ":")
            .first

        guard let firstOctet,
              let byte = UInt8(firstOctet, radix: 16) else {
            return false
        }

        return (byte & 0x02) == 0x02
    }

}
