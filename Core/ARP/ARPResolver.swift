import Darwin
import Foundation
import OSLog

protocol ARPResolving {
    func resolvedIPv4Entries() -> [String: String]
    func resolvedIPv4Entries(interfaceName: String?) -> [String: String]
}

extension ARPResolving {
    func resolvedIPv4Entries(interfaceName: String?) -> [String: String] {
        resolvedIPv4Entries()
    }
}

struct ARPResolver: ARPResolving {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.lanscope.mac",
        category: "ARP"
    )

    func resolvedIPv4Entries() -> [String: String] {
        resolvedIPv4Entries(interfaceName: nil)
    }

    func resolvedIPv4Entries(interfaceName: String?) -> [String: String] {
        let interfaceIndex: UInt32?
        if let interfaceName {
            let index = if_nametoindex(interfaceName)
            guard index != 0 else { return [:] }
            interfaceIndex = index
        } else {
            interfaceIndex = nil
        }
        var managementInformationBase = [CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_LLINFO]
        var requiredSize = 0

        guard sysctl(
            &managementInformationBase,
            u_int(managementInformationBase.count),
            nil,
            &requiredSize,
            nil,
            0
        ) == 0 else {
            Self.logger.error("Could not measure the ARP routing table: errno \(errno)")
            return [:]
        }

        guard requiredSize > 0 else { return [:] }
        var routingTable = [UInt8](repeating: 0, count: requiredSize)
        guard sysctl(
            &managementInformationBase,
            u_int(managementInformationBase.count),
            &routingTable,
            &requiredSize,
            nil,
            0
        ) == 0 else {
            Self.logger.error("Could not read the ARP routing table: errno \(errno)")
            return [:]
        }

        return parseRoutingTable(routingTable, byteCount: requiredSize, interfaceIndex: interfaceIndex)
    }

    func parseRoutingTable(_ routingTable: [UInt8], byteCount: Int, interfaceIndex: UInt32? = nil) -> [String: String] {
        routingTable.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return [:]
            }

            var entries: [String: String] = [:]
            var messageOffset = 0
            let availableBytes = min(max(0, byteCount), rawBuffer.count)

            while messageOffset + MemoryLayout<rt_msghdr>.size <= availableBytes {
                let message = rawBuffer.loadUnaligned(fromByteOffset: messageOffset, as: rt_msghdr.self)
                let messageLength = Int(message.rtm_msglen)

                guard message.rtm_version == RTM_VERSION,
                      messageLength >= MemoryLayout<rt_msghdr>.size,
                      messageOffset + messageLength <= availableBytes else {
                    break
                }
                let messageEnd = messageOffset + messageLength
                if let interfaceIndex, UInt32(message.rtm_index) != interfaceIndex {
                    messageOffset = messageEnd
                    continue
                }

                var ipAddress: String?
                var macAddress: String?
                var isValid = true
                var addressOffset = messageOffset + MemoryLayout<rt_msghdr>.size

                for addressIndex in 0..<Int(RTAX_MAX)
                where (message.rtm_addrs & (1 << addressIndex)) != 0 {
                    // Only the length/family prefix is guaranteed to be present.
                    // sockaddr_dl is variable-length and can be shorter than its Swift struct.
                    guard addressOffset + 2 <= messageEnd else {
                        isValid = false
                        break
                    }

                    let addressPointer = baseAddress.advanced(by: addressOffset)
                    let addressLength = Int(rawBuffer[addressOffset])
                    let family = rawBuffer[addressOffset + 1]
                    let alignedLength = alignedSockaddrLength(addressLength)
                    guard (addressLength == 0 || addressLength >= 2),
                          addressOffset + alignedLength <= messageEnd else {
                        isValid = false
                        break
                    }

                    if addressIndex == Int(RTAX_DST), family == UInt8(AF_INET) {
                        ipAddress = ipv4String(from: addressPointer, byteCount: addressLength)
                    } else if addressIndex == Int(RTAX_GATEWAY), family == UInt8(AF_LINK) {
                        macAddress = macString(from: addressPointer, byteCount: addressLength)
                    }

                    addressOffset += alignedLength
                }

                if isValid, let ipAddress, let macAddress {
                    entries[ipAddress] = macAddress
                }
                messageOffset += messageLength
            }

            return entries
        }
    }

    private func ipv4String(from pointer: UnsafeRawPointer, byteCount: Int) -> String? {
        guard byteCount >= MemoryLayout<sockaddr_in>.size else { return nil }
        var address = pointer.loadUnaligned(as: sockaddr_in.self).sin_addr
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &address, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
            return nil
        }
        return String(cString: buffer)
    }

    private func macString(from pointer: UnsafeRawPointer, byteCount: Int) -> String? {
        guard let dataOffset = MemoryLayout<sockaddr_dl>.offset(of: \sockaddr_dl.sdl_data),
              let nameLengthOffset = MemoryLayout<sockaddr_dl>.offset(of: \sockaddr_dl.sdl_nlen),
              let addressLengthOffset = MemoryLayout<sockaddr_dl>.offset(of: \sockaddr_dl.sdl_alen),
              byteCount >= dataOffset else {
            return nil
        }
        let nameLength = Int(pointer.load(fromByteOffset: nameLengthOffset, as: UInt8.self))
        let addressLength = Int(pointer.load(fromByteOffset: addressLengthOffset, as: UInt8.self))
        guard addressLength == 6, dataOffset + nameLength + addressLength <= byteCount else { return nil }

        let bytes = UnsafeRawBufferPointer(
            start: pointer.advanced(by: dataOffset + nameLength),
            count: addressLength
        )
        return Self.normalizedMACAddress(Array(bytes))
    }

    private func alignedSockaddrLength(_ length: Int) -> Int {
        // Darwin routing messages use 32-bit sockaddr alignment even on arm64.
        // sizeof(Int) rounds a 20-byte sockaddr_dl to 24 and skips the next address.
        let alignment = MemoryLayout<UInt32>.size
        guard length > 0 else {
            return alignment
        }
        return (length + alignment - 1) & ~(alignment - 1)
    }

    static func normalizedMACAddress(_ bytes: [UInt8]) -> String? {
        guard bytes.count == 6 else {
            return nil
        }
        return bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
    }
}
