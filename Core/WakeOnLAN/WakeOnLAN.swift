import Darwin
import Foundation

enum WakeOnLANError: LocalizedError {
    case invalidMACAddress
    case socketFailed
    case sendFailed

    var errorDescription: String? {
        switch self {
        case .invalidMACAddress:
            return "Invalid MAC address"
        case .socketFailed:
            return "Could not create UDP socket"
        case .sendFailed:
            return "Could not send UDP packet"
        }
    }
}

enum WakeOnLAN {
    static func sendMagicPacket(
        to macAddress: String,
        broadcastAddress: String = "255.255.255.255",
        port: UInt16 = 9
    ) throws {
        let macBytes = try parseMACAddress(macAddress)
        var packet = [UInt8](repeating: 0xFF, count: 6)
        for _ in 0..<16 {
            packet.append(contentsOf: macBytes)
        }

        let socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFD >= 0 else {
            throw WakeOnLANError.socketFailed
        }
        defer {
            close(socketFD)
        }

        var broadcastEnabled: Int32 = 1
        setsockopt(
            socketFD,
            SOL_SOCKET,
            SO_BROADCAST,
            &broadcastEnabled,
            socklen_t(MemoryLayout<Int32>.size)
        )

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        inet_pton(AF_INET, broadcastAddress, &address.sin_addr)

        let sent = packet.withUnsafeBytes { packetPointer in
            withUnsafePointer(to: &address) { addressPointer in
                addressPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                    sendto(
                        socketFD,
                        packetPointer.baseAddress,
                        packet.count,
                        0,
                        socketAddress,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    )
                }
            }
        }

        guard sent == packet.count else {
            throw WakeOnLANError.sendFailed
        }
    }

    private static func parseMACAddress(_ macAddress: String) throws -> [UInt8] {
        let parts = macAddress
            .replacingOccurrences(of: "-", with: ":")
            .split(separator: ":")

        guard parts.count == 6 else {
            throw WakeOnLANError.invalidMACAddress
        }

        return try parts.map { part in
            guard let byte = UInt8(part, radix: 16) else {
                throw WakeOnLANError.invalidMACAddress
            }
            return byte
        }
    }
}
