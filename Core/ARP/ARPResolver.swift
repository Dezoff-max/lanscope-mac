import Darwin
import Foundation
import OSLog

protocol ARPResolving {
    func resolvedIPv4Entries() -> [String: String]
}

struct ARPResolver: ARPResolving {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.lanscope.mac",
        category: "ARP"
    )

    func resolvedIPv4Entries() -> [String: String] {
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

        return parseRoutingTable(routingTable, byteCount: requiredSize)
    }

    private func parseRoutingTable(_ routingTable: [UInt8], byteCount: Int) -> [String: String] {
        routingTable.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return [:]
            }

            var entries: [String: String] = [:]
            var messageOffset = 0

            while messageOffset + MemoryLayout<rt_msghdr>.size <= byteCount {
                let message = baseAddress
                    .advanced(by: messageOffset)
                    .assumingMemoryBound(to: rt_msghdr.self)
                    .pointee
                let messageLength = Int(message.rtm_msglen)

                guard message.rtm_version == RTM_VERSION,
                      messageLength >= MemoryLayout<rt_msghdr>.size,
                      messageOffset + messageLength <= byteCount else {
                    break
                }

                var ipAddress: String?
                var macAddress: String?
                var addressOffset = messageOffset + MemoryLayout<rt_msghdr>.size

                for addressIndex in 0..<Int(RTAX_MAX)
                where (message.rtm_addrs & (1 << addressIndex)) != 0 {
                    guard addressOffset + MemoryLayout<sockaddr>.size <= messageOffset + messageLength else {
                        break
                    }

                    let addressPointer = baseAddress.advanced(by: addressOffset)
                    let socketAddress = addressPointer.assumingMemoryBound(to: sockaddr.self).pointee

                    if addressIndex == Int(RTAX_DST), socketAddress.sa_family == UInt8(AF_INET) {
                        ipAddress = ipv4String(from: addressPointer)
                    } else if addressIndex == Int(RTAX_GATEWAY), socketAddress.sa_family == UInt8(AF_LINK) {
                        macAddress = macString(from: addressPointer)
                    }

                    addressOffset += alignedSockaddrLength(Int(socketAddress.sa_len))
                }

                if let ipAddress, let macAddress {
                    entries[ipAddress] = macAddress
                }
                messageOffset += messageLength
            }

            return entries
        }
    }

    private func ipv4String(from pointer: UnsafeRawPointer) -> String? {
        var address = pointer.assumingMemoryBound(to: sockaddr_in.self).pointee.sin_addr
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &address, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
            return nil
        }
        return String(cString: buffer)
    }

    private func macString(from pointer: UnsafeRawPointer) -> String? {
        let linkAddress = pointer.assumingMemoryBound(to: sockaddr_dl.self).pointee
        guard linkAddress.sdl_alen == 6,
              let dataOffset = MemoryLayout<sockaddr_dl>.offset(of: \sockaddr_dl.sdl_data) else {
            return nil
        }

        let bytes = UnsafeRawBufferPointer(
            start: pointer.advanced(by: dataOffset + Int(linkAddress.sdl_nlen)),
            count: Int(linkAddress.sdl_alen)
        )
        return Self.normalizedMACAddress(Array(bytes))
    }

    private func alignedSockaddrLength(_ length: Int) -> Int {
        let alignment = MemoryLayout<Int>.size
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
