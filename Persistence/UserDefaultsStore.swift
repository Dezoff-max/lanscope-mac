import Foundation

final class UserDefaultsStore {
    static let shared = UserDefaultsStore()

    private enum Key {
        static let config = "LanScopeMac.config"
        static let favorites = "LanScopeMac.favorites"
        static let history = "LanScopeMac.history"
        static let profiles = "LanScopeMac.profiles"
        static let metadata = "LanScopeMac.deviceMetadata"
        static let schemaVersion = "LanScopeMac.schemaVersion"
    }

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private(set) var warning: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadConfig() -> ScannerConfig { (load(ScannerConfig.self, forKey: Key.config) ?? .default).normalized() }
    func saveConfig(_ config: ScannerConfig) { save(config, forKey: Key.config) }
    func loadFavorites() -> [Device] { load([Device].self, forKey: Key.favorites) ?? [] }
    func saveFavorites(_ devices: [Device]) { save(devices, forKey: Key.favorites) }
    func loadHistory() -> [ScanHistory] { load([ScanHistory].self, forKey: Key.history) ?? [] }
    func saveHistory(_ history: [ScanHistory]) { save(history, forKey: Key.history) }
    func loadProfiles() -> [NetworkProfile] { load([NetworkProfile].self, forKey: Key.profiles) ?? [] }
    func saveProfiles(_ profiles: [NetworkProfile]) { save(profiles, forKey: Key.profiles) }
    func loadDeviceMetadata() -> [Device] { load([Device].self, forKey: Key.metadata) ?? [] }
    func saveDeviceMetadata(_ devices: [Device]) { save(devices, forKey: Key.metadata) }

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do { return try decoder.decode(type, from: data) }
        catch {
            let backupKey = "\(key).unreadableBackup"
            if let oldBackup = defaults.data(forKey: backupKey), oldBackup != data {
                defaults.set(oldBackup, forKey: "\(backupKey).\(UUID().uuidString)")
            }
            defaults.set(data, forKey: backupKey)
            warning = "Не удалось прочитать часть сохранённых данных. Исходные данные сохранены в резервной копии настроек и не потеряны."
            return nil
        }
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        do {
            let data = try encoder.encode(value)
            preservePreviousSchemaIfNeeded()
            defaults.set(data, forKey: key)
        }
        catch { warning = "Не удалось сохранить изменения: \(error.localizedDescription)" }
    }

    /// Preserve the exact pre-upgrade payloads before any v0.3 save. Earlier builds
    /// cannot decode new statuses such as `cached`, even when the JSON is valid.
    private func preservePreviousSchemaIfNeeded() {
        guard defaults.integer(forKey: Key.schemaVersion) < 3 else { return }
        for key in [Key.config, Key.favorites, Key.history] {
            let backupKey = "\(key).schemaBackup.v0_2"
            if defaults.object(forKey: backupKey) == nil, let original = defaults.object(forKey: key) {
                defaults.set(original, forKey: backupKey)
            }
        }
        defaults.set(3, forKey: Key.schemaVersion)
    }
}
