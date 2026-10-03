import AppKit
import Foundation
import UniformTypeIdentifiers

enum ExportService {
    @MainActor
    @discardableResult
    static func saveCSV(devices: [Device]) throws -> Bool {
        try save(data: csvData(for: devices), suggestedName: "lanscope-devices.csv", contentType: .commaSeparatedText)
    }

    @MainActor
    @discardableResult
    static func saveJSON(devices: [Device]) throws -> Bool {
        try save(data: jsonData(for: devices), suggestedName: "lanscope-devices.json", contentType: .json)
    }

    @MainActor
    @discardableResult
    static func saveJSON(devices: [Device], scan: ScanHistory?) throws -> Bool {
        try save(data: jsonData(for: devices, scan: scan), suggestedName: "lanscope-devices.json", contentType: .json)
    }

    @MainActor
    static func copyTSV(devices: [Device]) {
        DeviceActionService.copy(tsvString(for: devices))
    }

    static func csvString(for devices: [Device]) -> String {
        ([csvRow(headers)] + devices.map { csvRow(values(for: $0)) }).joined(separator: "\n") + "\n"
    }

    static func csvData(for devices: [Device]) -> Data { Data(csvString(for: devices).utf8) }

    static func tsvString(for devices: [Device]) -> String {
        ([headers] + devices.map { values(for: $0) })
            .map { $0.map(spreadsheetSafeValue).joined(separator: "\t") }
            .joined(separator: "\n")
    }

    static func jsonData(for devices: [Device]) throws -> Data {
        try jsonEncoder().encode(devices)
    }

    static func jsonData(for devices: [Device], scan: ScanHistory?) throws -> Data {
        try jsonEncoder().encode(ExportDocument(devices: devices, scan: scan.map(ScanContext.init)))
    }

    private static let headers = ["Status", "Name", "IP Address", "MAC Address", "Vendor", "Open Ports", "Services", "Last Seen", "Kind", "Notes", "Tags", "Profile ID", "Observation Source", "Confirmed At", "Latency ms"]

    private static func values(for device: Device) -> [String] {
        [
            device.status.title, device.displayName, device.ipAddress, device.macAddress ?? "", device.vendor,
            device.openPortsDisplay, device.servicesDisplay,
            DateFormatter.lanScopeDateTime.string(from: device.lastSeen), device.kind.title, device.notes,
            device.tags.joined(separator: ", "), device.profileID?.uuidString ?? "", device.observationSource,
            device.confirmedAt.map { DateFormatter.lanScopeDateTime.string(from: $0) } ?? "",
            device.latencyMS.map { String(format: "%.1f", $0) } ?? ""
        ]
    }

    /// Network names and user notes must remain data when opened in a spreadsheet.
    static func spreadsheetSafeValue(_ value: String) -> String {
        let cleaned = String(value.unicodeScalars.map { scalar -> Character in
            if CharacterSet.controlCharacters.contains(scalar) || scalar == "\u{2028}" || scalar == "\u{2029}" {
                return " "
            }
            return Character(scalar)
        })
        let first = cleaned.trimmingCharacters(in: .whitespacesAndNewlines).first
        if let first, "=+-@".contains(first) { return "'" + cleaned }
        return cleaned
    }

    private static func csvRow(_ values: [String]) -> String {
        values.map { "\"\(spreadsheetSafeValue($0).replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",")
    }

    private static func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private struct ExportDocument: Encodable {
        let schemaVersion = 1
        let exportedAt = Date()
        let devices: [Device]
        let scan: ScanContext?
    }

    /// Deliberately excludes the full snapshot's devices: the export scope is the provided device array.
    private struct ScanContext: Encodable {
        let id: UUID
        let startedAt: Date
        let finishedAt: Date
        let ipRange: String
        let totalHosts: Int
        let completedHosts: Int
        let outcome: ScanOutcome
        let errorMessage: String?
        let profileID: UUID?
        let config: ScannerConfig?

        init(_ scan: ScanHistory) {
            id = scan.id
            startedAt = scan.startedAt
            finishedAt = scan.finishedAt
            ipRange = scan.ipRange
            totalHosts = scan.totalHosts
            completedHosts = scan.completedHosts
            outcome = scan.outcome
            errorMessage = scan.errorMessage
            profileID = scan.profileID
            config = scan.config
        }
    }

    @MainActor
    private static func save(data: Data, suggestedName: String, contentType: UTType) throws -> Bool {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [contentType]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        try data.write(to: url, options: .atomic)
        return true
    }
}
