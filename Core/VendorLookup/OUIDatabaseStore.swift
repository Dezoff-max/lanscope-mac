import Foundation

enum OUIDatabaseStore {
    static let ieeeCSVURL = URL(string: "https://standards-oui.ieee.org/oui/oui.csv")!
    private static let fileName = "oui.json"

    static var userDatabaseURL: URL? {
        guard let supportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        return supportDirectory
            .appendingPathComponent("LanScope Mac", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    static func loadBundledVendors(resourceName: String) -> [String: String] {
        if let appBundleURL = Bundle.main.url(forResource: resourceName, withExtension: "json") {
            return loadVendors(from: appBundleURL)
        }

        guard let swiftPMURL = Bundle.module.url(forResource: resourceName, withExtension: "json") else {
            return [:]
        }
        return loadVendors(from: swiftPMURL)
    }

    static func loadUserVendors() -> [String: String] {
        guard let url = userDatabaseURL else {
            return [:]
        }
        return loadVendors(from: url)
    }

    static func loadMergedVendors(resourceName: String) -> [String: String] {
        var vendors = loadBundledVendors(resourceName: resourceName)
        vendors.merge(loadUserVendors()) { _, userValue in userValue }
        return vendors
    }

    static func updateFromIEEE() async throws -> Int {
        let (data, _) = try await URLSession.shared.data(from: ieeeCSVURL)
        let vendors = try OUIDatabaseParser.parseIEEECSV(data: data)
        try saveUserVendors(vendors)
        return vendors.count
    }

    private static func saveUserVendors(_ vendors: [String: String]) throws {
        guard let url = userDatabaseURL else {
            return
        }

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let sorted = Dictionary(uniqueKeysWithValues: vendors.sorted { $0.key < $1.key })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sorted)
        try data.write(to: url, options: .atomic)
    }

    private static func loadVendors(from url: URL) -> [String: String] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }

        return decoded.reduce(into: [:]) { result, pair in
            let normalizedKey = pair.key
                .replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: "-", with: "")
                .uppercased()
            result[normalizedKey] = pair.value
        }
    }
}
