import Foundation

final class VendorLookup {
    private var vendors: [String: String]
    private let resourceName: String
    private let lock = NSLock()

    init(resourceName: String = "oui") {
        self.resourceName = resourceName
        self.vendors = OUIDatabaseStore.loadMergedVendors(resourceName: resourceName)
    }

    var vendorCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return vendors.count
    }

    @discardableResult
    func reload() -> Int {
        // Load outside the lock so active scans can keep using the previous database.
        let snapshot = OUIDatabaseStore.loadMergedVendors(resourceName: resourceName)
        lock.lock()
        vendors = snapshot
        lock.unlock()
        return snapshot.count
    }

    func vendor(for macAddress: String?) -> String {
        guard let macAddress,
              let oui = ouiKey(for: macAddress) else {
            return "Unknown"
        }

        lock.lock()
        let vendor = vendors[oui]
        lock.unlock()
        if let vendor {
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
