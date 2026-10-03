import Foundation

enum DeviceStatus: String, Codable, CaseIterable, Equatable {
    case online
    case cached
    case offline
    case unknown

    var title: String {
        switch self {
        case .online: return "В сети"
        case .cached: return "В ARP-кэше"
        case .offline: return "Не отвечает"
        case .unknown: return "Не проверено"
        }
    }
}
