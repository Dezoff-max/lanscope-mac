import Foundation

enum PortListParser {
    static let maximumPortCount = 1024

    enum ValidationError: LocalizedError, Equatable {
        case empty
        case invalidToken(String)
        case invalidRange(String)
        case tooManyPorts

        var errorDescription: String? {
            switch self {
            case .empty: return "Укажите хотя бы один порт, например 22, 80, 443 или 8000-8010."
            case .invalidToken(let token): return "Некорректный порт «\(token)». Допустимы числа от 1 до 65535."
            case .invalidRange(let token): return "Некорректный диапазон «\(token)». Пример: 8000-8010."
            case .tooManyPorts: return "За один скан можно проверить не более \(PortListParser.maximumPortCount) портов."
            }
        }
    }

    static func validate(_ text: String) throws -> [Int] {
        let tokens = text.split { $0 == "," || $0 == ";" || $0.isWhitespace }
        guard !tokens.isEmpty else { throw ValidationError.empty }
        var ports = Set<Int>()
        for rawToken in tokens {
            let token = String(rawToken).replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: "—", with: "-")
            if token.contains("-") {
                let parts = token.split(separator: "-", omittingEmptySubsequences: false)
                guard parts.count == 2, let start = Int(parts[0]), let end = Int(parts[1]),
                      (1...65535).contains(start), (1...65535).contains(end), start <= end else {
                    throw ValidationError.invalidRange(token)
                }
                guard end - start + 1 <= maximumPortCount else { throw ValidationError.tooManyPorts }
                ports.formUnion(start...end)
            } else {
                guard token.allSatisfy({ $0.isASCII && $0.isNumber }), let port = Int(token), (1...65535).contains(port) else {
                    throw ValidationError.invalidToken(token)
                }
                ports.insert(port)
            }
            guard ports.count <= maximumPortCount else { throw ValidationError.tooManyPorts }
        }
        return ports.sorted()
    }

    static func parse(_ text: String) -> [Int] { (try? validate(text)) ?? [] }
}
