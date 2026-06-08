import Foundation

protocol ARPResolving {
    func macAddress(for ipAddress: String) -> String?
}

struct ARPResolver: ARPResolving {
    func macAddress(for ipAddress: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/arp")
        process.arguments = ["-n", ipAddress]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return nil
        }

        return parseMACAddress(from: output)
    }

    private func parseMACAddress(from output: String) -> String? {
        let pattern = #"([0-9A-Fa-f]{1,2}:){5}[0-9A-Fa-f]{1,2}"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
              let range = Range(match.range, in: output) else {
            return nil
        }

        return output[range]
            .split(separator: ":")
            .map { part in
                part.count == 1 ? "0\(part)" : String(part)
            }
            .joined(separator: ":")
            .uppercased()
    }
}
