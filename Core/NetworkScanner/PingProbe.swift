import Foundation

struct PingMeasurement: Sendable {
    let reachable: Bool
    let latencyMS: Double?
    static let unavailable = PingMeasurement(reachable: false, latencyMS: nil)
}

enum PingProbe {
    static func isReachable(host: String, timeout: TimeInterval) async -> Bool {
        await measure(host: host, timeout: timeout).reachable
    }

    static func measure(host: String, timeout: TimeInterval, interfaceName: String? = nil) async -> PingMeasurement {
        guard !Task.isCancelled, IPv4Address(host) != nil else { return .unavailable }
        let duration = boundedTimeout(timeout)
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = commandArguments(host: host, timeout: duration, interfaceName: interfaceName)
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.environment = ProcessInfo.processInfo.environment.merging(["LC_ALL": "C"]) { _, new in new }
        let completion = ProbeResult<PingMeasurement> {
            process.terminationHandler = nil
            if process.isRunning { process.terminate() }
        }
        process.terminationHandler = { process in
            let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            completion.finish(PingMeasurement(
                reachable: process.terminationStatus == 0,
                latencyMS: process.terminationStatus == 0 ? latency(in: text) : nil
            ))
        }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                completion.install(continuation)
                do {
                    try completion.start { try process.run() }
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + duration + 0.1) {
                        completion.finish(.unavailable)
                    }
                } catch { completion.finish(.unavailable) }
            }
        } onCancel: { completion.finish(.unavailable) }
    }

    static func commandArguments(host: String, timeout: TimeInterval, interfaceName: String? = nil) -> [String] {
        let waitMilliseconds = max(1, Int((boundedTimeout(timeout) * 1_000).rounded(.up)))
        var arguments = ["-c", "1", "-W", String(waitMilliseconds)]
        if let interfaceName, !interfaceName.isEmpty { arguments += ["-b", interfaceName] }
        return arguments + [host]
    }

    static func latency(in output: String) -> Double? {
        guard let expression = try? NSRegularExpression(pattern: #"time[=<]([0-9]+(?:\.[0-9]+)?)\s*ms"#),
              let match = expression.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
              let range = Range(match.range(at: 1), in: output) else { return nil }
        return Double(output[range])
    }

    private static func boundedTimeout(_ timeout: TimeInterval) -> TimeInterval {
        timeout.isFinite ? min(max(timeout, 0.001), 60) : 1
    }
}
