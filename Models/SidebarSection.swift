import Foundation

enum SidebarSection: String, CaseIterable, Identifiable {
    case scan
    case wifi
    case favorites
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scan:
            return "Scan"
        case .wifi:
            return "Wi-Fi"
        case .favorites:
            return "Favorites"
        case .history:
            return "History"
        case .settings:
            return "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .scan:
            return "wave.3.right.circle"
        case .wifi:
            return "wifi"
        case .favorites:
            return "star"
        case .history:
            return "clock.arrow.circlepath"
        case .settings:
            return "gearshape"
        }
    }

    var emojiIcon: String {
        switch self {
        case .scan:
            return "🌐"
        case .wifi:
            return "📶"
        case .favorites:
            return "⭐️"
        case .history:
            return "📅"
        case .settings:
            return "🧰"
        }
    }
}
