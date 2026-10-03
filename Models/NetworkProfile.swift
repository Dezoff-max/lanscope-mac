import Foundation

struct NetworkProfile: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var config: ScannerConfig

    init(id: UUID = UUID(), name: String, config: ScannerConfig) {
        self.id = id
        self.name = name
        self.config = config
        self.config.profileID = id
    }
}
