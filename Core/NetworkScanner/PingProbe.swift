import Foundation

enum PingProbe {
    static func isReachable(host: String, timeout: TimeInterval) async -> Bool {
        await Task.detached(priority: .utility) {
            guard !Task.isCancelled else {
                return false
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            process.arguments = commandArguments(host: host, timeout: timeout)
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

    static func commandArguments(host: String, timeout: TimeInterval) -> [String] {
        let waitMilliseconds = max(1, Int((timeout * 1_000).rounded(.up)))
        return ["-c", "1", "-W", String(waitMilliseconds), host]
    }
}
