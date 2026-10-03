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
            return "Сканирование"
        case .wifi:
            return "Wi-Fi"
        case .favorites:
            return "Избранное"
        case .history:
            return "История"
        case .settings:
            return "Настройки"
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

}
