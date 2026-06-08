import Darwin
import Foundation

enum LocalNetworkInfo {
    static func suggestedRange() -> String? {
        guard let interface = primaryIPv4Interface(),
              let address = IPv4Address(interface.address),
              let mask = IPv4Address(interface.netmask) else {
            return nil
        }

        let network = address.value & mask.value
        let broadcast = network | ~mask.value
        let hostCount = broadcast > network ? Int(broadcast - network - 1) : 0

        if hostCount > 0, hostCount <= 512 {
            let first = IPv4Address(value: network + 1).description
            let last = IPv4Address(value: broadcast - 1).description
            return "\(first)-\(last)"
        }

        return address.prefix24.map { "\($0).1-254" }
    }

    private static func primaryIPv4Interface() -> (address: String, netmask: String)? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let firstInterface = interfaces else {
            return nil
        }
        defer {
            freeifaddrs(interfaces)
        }

        var pointer: UnsafeMutablePointer<ifaddrs>? = firstInterface
        while let current = pointer {
            defer {
                pointer = current.pointee.ifa_next
            }

            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
            guard isUp, !isLoopback,
                  let interfaceAddress = current.pointee.ifa_addr,
                  interfaceAddress.pointee.sa_family == UInt8(AF_INET),
                  let address = addressString(from: interfaceAddress),
                  let netmask = addressString(from: current.pointee.ifa_netmask) else {
                continue
            }

            return (address, netmask)
        }

        return nil
    }

    private static func addressString(from socketAddress: UnsafePointer<sockaddr>?) -> String? {
        guard let socketAddress else {
            return nil
        }

        var address = socketAddress.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &address, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
            return nil
        }
        return String(cString: buffer)
    }
}
