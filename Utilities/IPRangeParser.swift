import Foundation

enum IPRangeError: LocalizedError {
    case emptyRange
    case invalidFormat(String)
    case tooLarge(Int)

    var errorDescription: String? {
        switch self {
        case .emptyRange:
            return "IP range is empty"
        case .invalidFormat(let value):
            return "Invalid IP range: \(value)"
        case .tooLarge(let count):
            return "Range is too large for MVP scanning (\(count) hosts)"
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

        let ranges = try trimmed
            .split(separator: ",")
            .flatMap { try parseRange(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }

        let unique = Array(Set(ranges)).sorted(by: IPAddressSorter.compare)
        guard unique.count <= maximumHosts else {
            throw IPRangeError.tooLarge(unique.count)
        }
        return unique
    }

    private static func parseRange(_ value: String) throws -> [String] {
        if value.contains("/") {
            return try parseCIDR(value)
        }

        if value.contains("-") {
            return try parseHyphenRange(value)
        }

        guard IPv4Address(value) != nil else {
            throw IPRangeError.invalidFormat(value)
        }
        return [value]
    }

    private static func parseHyphenRange(_ value: String) throws -> [String] {
        let parts = value.split(separator: "-", maxSplits: 1).map(String.init)
        guard parts.count == 2, let start = IPv4Address(parts[0]) else {
            throw IPRangeError.invalidFormat(value)
        }

        let endAddress: IPv4Address
        if let fullEnd = IPv4Address(parts[1]) {
            endAddress = fullEnd
        } else if let endOctet = UInt8(parts[1]),
                  let prefix = start.prefix24,
                  let shortEndAddress = IPv4Address("\(prefix).\(endOctet)") {
            endAddress = shortEndAddress
        } else {
            throw IPRangeError.invalidFormat(value)
        }

        guard start.value <= endAddress.value else {
            throw IPRangeError.invalidFormat(value)
        }

        let count = Int(endAddress.value - start.value + 1)
        guard count <= maximumHosts else {
            throw IPRangeError.tooLarge(count)
        }

        return (start.value...endAddress.value).map { IPv4Address(value: $0).description }
    }

    private static func parseCIDR(_ value: String) throws -> [String] {
        let parts = value.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let address = IPv4Address(parts[0]),
              let prefixLength = Int(parts[1]),
              (0...32).contains(prefixLength) else {
            throw IPRangeError.invalidFormat(value)
        }

        let mask = prefixLength == 0 ? UInt32(0) : UInt32.max << UInt32(32 - prefixLength)
        let network = address.value & mask
        let broadcast = network | ~mask
        let first = prefixLength >= 31 ? network : network + 1
        let last = prefixLength >= 31 ? broadcast : broadcast - 1
        guard first <= last else {
            return []
        }

        let count = Int(last - first + 1)
        guard count <= maximumHosts else {
            throw IPRangeError.tooLarge(count)
        }

        return (first...last).map { IPv4Address(value: $0).description }
    }
}

struct IPv4Address: Hashable, CustomStringConvertible {
    let value: UInt32

    init?(_ string: String) {
        let octets = string.split(separator: ".")
        guard octets.count == 4 else {
            return nil
        }

        var value: UInt32 = 0
        for octet in octets {
            guard let byte = UInt8(octet) else {
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
