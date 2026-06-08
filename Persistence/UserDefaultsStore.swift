import Foundation

final class UserDefaultsStore {
    static let shared = UserDefaultsStore()

    private enum Key {
        static let config = "LanScopeMac.config"
        static let favorites = "LanScopeMac.favorites"
        static let history = "LanScopeMac.history"
    }

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadConfig() -> ScannerConfig {
        load(ScannerConfig.self, forKey: Key.config) ?? .default
    }

    func saveConfig(_ config: ScannerConfig) {
        save(config, forKey: Key.config)
    }

    func loadFavorites() -> [Device] {
        load([Device].self, forKey: Key.favorites) ?? []
    }

    func saveFavorites(_ devices: [Device]) {
        save(devices, forKey: Key.favorites)
    }

    func loadHistory() -> [ScanHistory] {
        load([ScanHistory].self, forKey: Key.history) ?? []
    }

    func saveHistory(_ history: [ScanHistory]) {
        save(history, forKey: Key.history)
    }

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? decoder.decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}
