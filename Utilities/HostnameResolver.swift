import Darwin
import Foundation

protocol HostnameResolving {
    func hostname(for ipAddress: String) async -> String?
}

struct HostnameResolver: HostnameResolving {
    func hostname(for ipAddress: String) async -> String? {
        await Task.detached(priority: .utility) {
            reverseDNS(ipAddress: ipAddress)
        }.value
    }

    private func reverseDNS(ipAddress: String) -> String? {
        var socketAddress = sockaddr_in()
        socketAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        socketAddress.sin_family = sa_family_t(AF_INET)
        guard inet_pton(AF_INET, ipAddress, &socketAddress.sin_addr) == 1 else {
            return nil
        }

        var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = withUnsafePointer(to: &socketAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketPointer in
                getnameinfo(
                    socketPointer,
                    socklen_t(MemoryLayout<sockaddr_in>.size),
                    &hostBuffer,
                    socklen_t(hostBuffer.count),
                    nil,
                    0,
                    NI_NAMEREQD
                )
            }
        }

        guard result == 0 else {
            return nil
        }

        return String(cString: hostBuffer)
    }
}
