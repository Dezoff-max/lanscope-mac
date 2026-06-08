import Foundation

enum DeviceStatus: String, Codable, CaseIterable, Equatable {
    case online
    case offline
    case unknown

    var title: String {
        switch self {
        case .online:
            return "Online"
        case .offline:
            return "Offline"
        case .unknown:
            return "Unknown"
        }
    }
}
