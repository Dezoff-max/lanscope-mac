import Foundation

struct ScanHistory: Codable, Hashable, Identifiable {
    var id: UUID
    var startedAt: Date
    var finishedAt: Date
    var ipRange: String
    var totalHosts: Int
    var foundDevices: Int
    var devices: [Device]

    init(
        id: UUID = UUID(),
        startedAt: Date,
        finishedAt: Date,
        ipRange: String,
        totalHosts: Int,
        foundDevices: Int,
        devices: [Device]
    ) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.ipRange = ipRange
        self.totalHosts = totalHosts
        self.foundDevices = foundDevices
        self.devices = devices
    }

    var duration: TimeInterval {
        finishedAt.timeIntervalSince(startedAt)
    }
}
