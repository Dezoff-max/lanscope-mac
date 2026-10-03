import Foundation

struct MonitorSample: Identifiable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let reachable: Bool
    let latencyMS: Double?

    init(id: UUID = UUID(), timestamp: Date = Date(), reachable: Bool, latencyMS: Double?) {
        self.id = id
        self.timestamp = timestamp
        self.reachable = reachable
        self.latencyMS = reachable ? latencyMS : nil
    }
}

struct DeviceMonitorSnapshot: Equatable {
    var samples: [MonitorSample] = []
    var isMonitoring = false
    var isProbing = false
    var confirmedReachable: Bool?
    var consecutiveFailures = 0

    var lastSample: MonitorSample? { samples.last }

    var lossPercent: Double? {
        guard !samples.isEmpty else { return nil }
        return Double(samples.filter { !$0.reachable }.count) / Double(samples.count) * 100
    }

    var averageLatencyMS: Double? {
        let values = samples.compactMap(\.latencyMS)
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    var maximumLatencyMS: Double? { samples.compactMap(\.latencyMS).max() }

    mutating func append(_ sample: MonitorSample, historyDuration: TimeInterval, maximumSamples: Int) {
        samples.append(sample)
        let cutoff = sample.timestamp.addingTimeInterval(-historyDuration)
        samples.removeAll { $0.timestamp < cutoff }
        if samples.count > maximumSamples {
            samples.removeFirst(samples.count - maximumSamples)
        }
    }
}

struct DeviceMonitorEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let device: Device
    let reachable: Bool
    let message: String
}
