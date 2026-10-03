import Darwin
import Foundation
import SystemConfiguration

struct NetworkInterfaceInfo: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let displayName: String
    let ipAddress: String
    let netmask: String
    let suggestedRange: String
}

enum LocalNetworkInfo {
    static func suggestedRange() -> String? {
        interfaces().first?.suggestedRange
    }

    static func interfaces() -> [NetworkInterfaceInfo] {
        var interfaceList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceList) == 0, let firstInterface = interfaceList else {
            return []
        }
        defer {
            freeifaddrs(interfaceList)
        }

        let displayNames = interfaceDisplayNames()
        var result: [NetworkInterfaceInfo] = []
        var seen = Set<String>()
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
                  let netmask = addressString(from: current.pointee.ifa_netmask),
                  let suggestedRange = suggestedRange(address: address, netmask: netmask) else {
                continue
            }

            let name = String(cString: current.pointee.ifa_name)
            let id = "\(name):\(address)"
            guard seen.insert(id).inserted else { continue }
            let label = displayNames[name] ?? (isTunnel(name) ? "VPN" : name)
            result.append(NetworkInterfaceInfo(
                id: id,
                name: name,
                displayName: label == name ? name : "\(label) (\(name))",
                ipAddress: address,
                netmask: netmask,
                suggestedRange: suggestedRange
            ))
        }

        // getifaddrs order is not a route preference. Favor physical LAN interfaces
        // so enabling a VPN does not silently switch the suggested scan range.
        return result.sorted { lhs, rhs in
            let leftPriority = priority(lhs)
            let rightPriority = priority(rhs)
            if leftPriority != rightPriority { return leftPriority < rightPriority }
            if lhs.name != rhs.name {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return IPAddressSorter.compare(lhs.ipAddress, rhs.ipAddress)
        }
    }

    private static func suggestedRange(address: String, netmask: String) -> String? {
        guard let address = IPv4Address(address), let mask = IPv4Address(netmask) else {
            return nil
        }
        let network = UInt64(address.value & mask.value)
        let broadcast = UInt64(address.value & mask.value | ~mask.value)
        let total = broadcast - network + 1
        // /31 links use both addresses; /32 interfaces represent one host.
        let first = total <= 2 ? network : network + 1
        let last = total <= 2 ? broadcast : broadcast - 1
        let count = last - first + 1
        if count <= 512 {
            let startAddress = IPv4Address(value: UInt32(first)).description
            if first == last { return startAddress }
            return "\(startAddress)-\(IPv4Address(value: UInt32(last)).description)"
        }
        return address.prefix24.map { "\($0).1-254" }
    }

    private static func interfaceDisplayNames() -> [String: String] {
        guard let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else {
            return [:]
        }
        var names: [String: String] = [:]
        for interface in interfaces {
            guard let name = SCNetworkInterfaceGetBSDName(interface) as String?,
                  let label = SCNetworkInterfaceGetLocalizedDisplayName(interface) as String? else {
                continue
            }
            names[name] = label
        }
        return names
    }

    private static func isTunnel(_ name: String) -> Bool {
        ["utun", "tun", "tap", "ppp", "ipsec"].contains { name.hasPrefix($0) }
    }

    private static func priority(_ interface: NetworkInterfaceInfo) -> Int {
        let linkLocalPenalty = interface.ipAddress.hasPrefix("169.254.") ? 10 : 0
        if interface.name.hasPrefix("en") { return linkLocalPenalty }
        if interface.name.hasPrefix("bridge") { return 1 + linkLocalPenalty }
        return (isTunnel(interface.name) ? 3 : 2) + linkLocalPenalty
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
