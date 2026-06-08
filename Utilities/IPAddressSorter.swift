import Foundation

enum IPAddressSorter {
    static func compare(_ lhs: String, _ rhs: String) -> Bool {
        guard let left = IPv4Address(lhs), let right = IPv4Address(rhs) else {
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        return left.value < right.value
    }
}
