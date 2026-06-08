import Foundation

enum PortListParser {
    static func parse(_ text: String) -> [Int] {
        text
            .split { character in
                character == "," || character == " " || character == "\n" || character == "\t"
            }
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { (1...65535).contains($0) }
            .reduce(into: [Int]()) { result, port in
                if !result.contains(port) {
                    result.append(port)
                }
            }
            .sorted()
    }
}
