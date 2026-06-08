import Foundation

enum OUIDatabaseParser {
    enum ParseError: LocalizedError {
        case invalidEncoding
        case emptyDatabase

        var errorDescription: String? {
            switch self {
            case .invalidEncoding:
                return "Could not read OUI CSV as UTF-8"
            case .emptyDatabase:
                return "OUI CSV did not contain vendor assignments"
            }
        }
    }

    static func parseIEEECSV(data: Data) throws -> [String: String] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ParseError.invalidEncoding
        }

        var vendors: [String: String] = [:]
        for row in parseCSVRows(text) {
            guard row.count >= 3, row[0] != "Registry" else {
                continue
            }

            let assignment = row[1]
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: ":", with: "")
                .uppercased()
            guard assignment.count == 6,
                  assignment.allSatisfy(\.isHexDigit) else {
                continue
            }

            let organization = row[2].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !organization.isEmpty else {
                continue
            }

            vendors[assignment] = organization
        }

        guard !vendors.isEmpty else {
            throw ParseError.emptyDatabase
        }
        return vendors
    }

    private static func parseCSVRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isInsideQuotes = false
        var iterator = text.makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                if isInsideQuotes {
                    if let next = iterator.next() {
                        if next == "\"" {
                            field.append(next)
                        } else {
                            isInsideQuotes = false
                            consumeCSVSeparator(next, field: &field, row: &row, rows: &rows)
                        }
                    } else {
                        isInsideQuotes = false
                    }
                } else {
                    isInsideQuotes = true
                }
            } else if isInsideQuotes {
                field.append(character)
            } else {
                consumeCSVSeparator(character, field: &field, row: &row, rows: &rows)
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    private static func consumeCSVSeparator(
        _ character: Character,
        field: inout String,
        row: inout [String],
        rows: inout [[String]]
    ) {
        switch character {
        case ",":
            row.append(field)
            field = ""
        case "\n":
            row.append(field.trimmingCharacters(in: CharacterSet(charactersIn: "\r")))
            rows.append(row)
            row = []
            field = ""
        case "\r":
            break
        default:
            field.append(character)
        }
    }
}
