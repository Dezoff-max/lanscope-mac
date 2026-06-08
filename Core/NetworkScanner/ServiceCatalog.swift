import Foundation

enum ServiceCatalog {
    static let defaultPorts = [22, 80, 443, 445, 548, 5900, 3389, 8080]

    static func service(for port: Int) -> NetworkService {
        switch port {
        case 22:
            return NetworkService(port: port, name: "SSH", scheme: "ssh")
        case 80:
            return NetworkService(port: port, name: "HTTP", scheme: "http")
        case 443:
            return NetworkService(port: port, name: "HTTPS", scheme: "https")
        case 445:
            return NetworkService(port: port, name: "SMB", scheme: "smb")
        case 548:
            return NetworkService(port: port, name: "AFP", scheme: "afp")
        case 5900:
            return NetworkService(port: port, name: "VNC", scheme: "vnc")
        case 3389:
            return NetworkService(port: port, name: "RDP", scheme: "rdp")
        case 8080:
            return NetworkService(port: port, name: "HTTP-alt", scheme: "http")
        default:
            return NetworkService(port: port, name: "TCP", scheme: nil)
        }
    }
}
