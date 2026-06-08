import Foundation

enum PingProbe {
    static func isReachable(host: String, timeout: TimeInterval) async -> Bool {
        await Task.detached(priority: .utility) {
            guard !Task.isCancelled else {
                return false
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            process.arguments = [
                "-c", "1",
                "-W", "\(max(1, Int(ceil(timeout))))",
                host
            ]
            process.standardOutput = Pipe()
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                return false
            }
        }.value
    }
}
