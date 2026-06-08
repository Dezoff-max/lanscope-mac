import Foundation

enum MockDevices {
    static let sample: [Device] = [
        Device(
            ipAddress: "192.168.1.1",
            hostname: "gateway.local",
            macAddress: "00:1A:2B:10:20:30",
            vendor: "Apple, Inc.",
            openPorts: [80, 443],
            services: [ServiceCatalog.service(for: 80), ServiceCatalog.service(for: 443)],
            lastSeen: Date()
        ),
        Device(
            ipAddress: "192.168.1.12",
            hostname: "nas.local",
            macAddress: "00:11:32:AA:BB:CC",
            vendor: "Synology Incorporated",
            openPorts: [22, 80, 445],
            services: [ServiceCatalog.service(for: 22), ServiceCatalog.service(for: 80), ServiceCatalog.service(for: 445)],
            lastSeen: Date()
        ),
        Device(
            ipAddress: "192.168.1.24",
            hostname: "studio-mac.local",
            macAddress: "3C:22:FB:44:55:66",
            vendor: "Apple, Inc.",
            openPorts: [22, 5900],
            services: [ServiceCatalog.service(for: 22), ServiceCatalog.service(for: 5900)],
            lastSeen: Date()
        ),
        Device(
            ipAddress: "192.168.1.42",
            hostname: "printer.local",
            macAddress: "B8:27:EB:01:02:03",
            vendor: "Raspberry Pi Foundation",
            openPorts: [80, 8080],
            services: [ServiceCatalog.service(for: 80), ServiceCatalog.service(for: 8080)],
            lastSeen: Date()
        )
    ]
}
