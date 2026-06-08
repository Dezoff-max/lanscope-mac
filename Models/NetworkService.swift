import Foundation

struct NetworkService: Codable, Hashable, Identifiable {
    var id: Int { port }

    let port: Int
    let name: String
    let scheme: String?

    var displayName: String {
        "\(name) :\(port)"
    }
}
