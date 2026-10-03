import Foundation

enum IPRangeError: LocalizedError {
    case emptyRange
    case invalidFormat(String)
    case tooLarge(Int)

    var errorDescription: String? {
        switch self {
        case .emptyRange:
            return "Укажите диапазон IP-адресов"
        case .invalidFormat(let value):
            return "Некорректный диапазон IP: \(value)"
        case .tooLarge(let count):
            return "Диапазон слишком большой (\(count) адресов). Максимум — 4096."
        }
    }
}

enum IPRangeParser {
    private static let maximumHosts = 4096

    static func hosts(in input: String) throws -> [String] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw IPRangeError.emptyRange
        }

        var unique = Set<String>()
        for component in trimmed.split(separator: ",", omittingEmptySubsequences: false) {
            let value = String(component).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else {
                throw IPRangeError.invalidFormat(trimmed)
            }
            unique.formUnion(try parseRange(value))
            guard unique.count <= maximumHosts else {
                throw IPRangeError.tooLarge(unique.count)
            }
        }
        return unique.sorted(by: IPAddressSorter.compare)
    }

    private static func parseRange(_ value: String) throws -> [String] {
        if value.contains("/") {
            return try parseCIDR(value)
        }

        if value.contains("-") {
            return try parseHyphenRange(value)
        }

        guard let address = IPv4Address(value) else {
            throw IPRangeError.invalidFormat(value)
        }
        return [address.description]
    }

    private static func parseHyphenRange(_ value: String) throws -> [String] {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2, let start = IPv4Address(parts[0]) else {
            throw IPRangeError.invalidFormat(value)
        }

        let endAddress: IPv4Address
        if let fullEnd = IPv4Address(parts[1]) {
            endAddress = fullEnd
        } else if isDecimal(parts[1]), let endOctet = UInt8(parts[1]),
                  let prefix = start.prefix24,
                  let shortEndAddress = IPv4Address("\(prefix).\(endOctet)") {
            endAddress = shortEndAddress
        } else {
            throw IPRangeError.invalidFormat(value)
        }

        guard start.value <= endAddress.value else {
            throw IPRangeError.invalidFormat(value)
        }

        return try expand(first: UInt64(start.value), last: UInt64(endAddress.value))
    }

    private static func parseCIDR(_ value: String) throws -> [String] {
        let parts = value.split(separator: "/", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2,
              let address = IPv4Address(parts[0]),
              isDecimal(parts[1]),
              let prefixLength = Int(parts[1]),
              (0...32).contains(prefixLength) else {
            throw IPRangeError.invalidFormat(value)
        }

        let mask = prefixLength == 0 ? UInt32(0) : UInt32.max << UInt32(32 - prefixLength)
        let network = address.value & mask
        let broadcast = network | ~mask
        let first = UInt64(network) + (prefixLength >= 31 ? 0 : 1)
        let last = UInt64(broadcast) - (prefixLength >= 31 ? 0 : 1)
        return try expand(first: first, last: last)
    }

    private static func expand(first: UInt64, last: UInt64) throws -> [String] {
        // A complete IPv4 range contains 2^32 addresses, one more than UInt32.max.
        let count = last - first + 1
        guard count <= UInt64(maximumHosts) else {
            throw IPRangeError.tooLarge(Int(count))
        }
        return (first...last).map { IPv4Address(value: UInt32($0)).description }
    }

    private static func isDecimal(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { (48...57).contains($0) }
    }
}

struct IPv4Address: Hashable, CustomStringConvertible {
    let value: UInt32

    init?(_ string: String) {
        let octets = string.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else {
            return nil
        }

        var value: UInt32 = 0
        for octet in octets {
            guard !octet.isEmpty,
                  octet.utf8.allSatisfy({ (48...57).contains($0) }),
                  let byte = UInt8(octet) else {
                return nil
            }
            value = (value << 8) | UInt32(byte)
        }
        self.value = value
    }

    init(value: UInt32) {
        self.value = value
    }

    var description: String {
        [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
        .map(String.init)
        .joined(separator: ".")
    }

    var prefix24: String? {
        let parts = description.split(separator: ".")
        guard parts.count == 4 else {
            return nil
        }
        return parts.prefix(3).joined(separator: ".")
    }
}
