import AppKit
import Foundation

enum DeviceActionService {
    @MainActor
    static func openInBrowser(_ device: Device) {
        let target: URL?
        if device.openPorts.contains(443) {
            target = URL(string: "https://\(device.ipAddress)")
        } else if device.openPorts.contains(80) {
            target = URL(string: "http://\(device.ipAddress)")
        } else if device.openPorts.contains(8080) {
            target = URL(string: "http://\(device.ipAddress):8080")
        } else {
            target = URL(string: "http://\(device.ipAddress)")
        }

        if let target {
            NSWorkspace.shared.open(target)
        }
    }

    @MainActor
    static func openSSH(_ device: Device) {
        openWithSystemOpen(arguments: ["-a", "Terminal", "ssh://\(device.ipAddress)"])
    }

    @MainActor
    static func openSMB(_ device: Device) {
        if let url = URL(string: "smb://\(device.ipAddress)") {
            NSWorkspace.shared.open(url)
        }
    }

    @MainActor
    static func openVNC(_ device: Device) {
        if let url = URL(string: "vnc://\(device.ipAddress)") {
            NSWorkspace.shared.open(url)
        }
    }

    @MainActor
    static func copy(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }

    @MainActor
    private static func openWithSystemOpen(arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = arguments
        try? process.run()
    }
}
