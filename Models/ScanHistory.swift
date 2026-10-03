import Foundation

enum ScanOutcome: String, Codable, Hashable {
    case completed, cancelled, failed
    var title: String {
        switch self {
        case .completed: return "Завершено"
        case .cancelled: return "Остановлено"
        case .failed: return "Ошибка"
        }
    }
}

struct ScanHistory: Codable, Hashable, Identifiable {
    var id: UUID
    var startedAt: Date
    var finishedAt: Date
    var ipRange: String
    var totalHosts: Int
    var foundDevices: Int
    var devices: [Device]
    var outcome: ScanOutcome
    var completedHosts: Int
    var errorMessage: String?
    var profileID: UUID?
    var config: ScannerConfig?

    init(id: UUID = UUID(), startedAt: Date, finishedAt: Date, ipRange: String, totalHosts: Int,
         foundDevices: Int, devices: [Device], outcome: ScanOutcome = .completed,
         completedHosts: Int? = nil, errorMessage: String? = nil, profileID: UUID? = nil,
         config: ScannerConfig? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.ipRange = ipRange
        self.totalHosts = totalHosts
        self.foundDevices = foundDevices
        self.devices = devices
        self.outcome = outcome
        self.completedHosts = completedHosts ?? (outcome == .completed ? totalHosts : 0)
        self.errorMessage = errorMessage
        self.profileID = profileID ?? config?.profileID
        self.config = config
    }

    private enum CodingKeys: String, CodingKey {
        case id, startedAt, finishedAt, ipRange, totalHosts, foundDevices, devices
        case outcome, completedHosts, errorMessage, profileID, config
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        startedAt = try values.decode(Date.self, forKey: .startedAt)
        finishedAt = try values.decode(Date.self, forKey: .finishedAt)
        ipRange = try values.decode(String.self, forKey: .ipRange)
        totalHosts = try values.decode(Int.self, forKey: .totalHosts)
        devices = try values.decode([Device].self, forKey: .devices)
        foundDevices = try values.decodeIfPresent(Int.self, forKey: .foundDevices) ?? devices.count
        outcome = try values.decodeIfPresent(ScanOutcome.self, forKey: .outcome) ?? .completed
        // Older versions did not record cancellation or coverage; retain that uncertainty.
        completedHosts = try values.decodeIfPresent(Int.self, forKey: .completedHosts) ?? 0
        errorMessage = try values.decodeIfPresent(String.self, forKey: .errorMessage)
        profileID = try values.decodeIfPresent(UUID.self, forKey: .profileID)
        config = try values.decodeIfPresent(ScannerConfig.self, forKey: .config)
    }

    var duration: TimeInterval { max(0, finishedAt.timeIntervalSince(startedAt)) }
    var isComplete: Bool { outcome == .completed && totalHosts > 0 && completedHosts == totalHosts && errorMessage == nil }
}
