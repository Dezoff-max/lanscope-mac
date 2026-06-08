import AppKit
import Foundation
import UniformTypeIdentifiers

enum ExportService {
    @MainActor
    static func saveCSV(devices: [Device]) throws {
        let data = csvData(for: devices)
        try save(data: data, suggestedName: "lanscope-devices.csv", contentType: .commaSeparatedText)
    }

    @MainActor
    static func saveJSON(devices: [Device]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(devices)
        try save(data: data, suggestedName: "lanscope-devices.json", contentType: .json)
    }

    @MainActor
    static func copyTSV(devices: [Device]) {
        let headers = ["Status", "Name", "IP Address", "MAC Address", "Vendor", "Open Ports", "Services", "Last Seen"]
        let rows = devices.map { device in
            [
                device.status.title,
                device.displayName,
                device.ipAddress,
                device.macAddress ?? "",
                device.vendor,
                device.openPortsDisplay,
                device.servicesDisplay,
                DateFormatter.lanScopeDateTime.string(from: device.lastSeen)
            ].joined(separator: "\t")
        }
        let value = ([headers.joined(separator: "\t")] + rows).joined(separator: "\n")
        DeviceActionService.copy(value)
    }

    static func csvString(for devices: [Device]) -> String {
        let headers = ["Status", "Name", "IP Address", "MAC Address", "Vendor", "Open Ports", "Services", "Last Seen"]
        let rows = devices.map { device in
            csvRow([
                device.status.title,
                device.displayName,
                device.ipAddress,
                device.macAddress ?? "",
                device.vendor,
                device.openPortsDisplay,
                device.servicesDisplay,
                DateFormatter.lanScopeDateTime.string(from: device.lastSeen)
            ])
        }
        return ([csvRow(headers)] + rows).joined(separator: "\n") + "\n"
    }

    static func csvData(for devices: [Device]) -> Data {
        Data(csvString(for: devices).utf8)
    }

    private static func csvRow(_ values: [String]) -> String {
        values.map { value in
            "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        .joined(separator: ",")
    }

    @MainActor
    private static func save(data: Data, suggestedName: String, contentType: UTType) throws {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [contentType]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        try data.write(to: url)
    }
}
