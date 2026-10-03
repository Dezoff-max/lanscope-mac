import Foundation

enum DeviceFilter: String, CaseIterable, Identifiable {
    case all, new, favorites, web, online, unconfirmed
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "Все"
        case .new: return "Новые"
        case .favorites: return "Избранные"
        case .web: return "Веб-интерфейс"
        case .online: return "Ответили"
        case .unconfirmed: return "Не подтверждены"
        }
    }
    func includes(_ device: Device, newIDs: Set<UUID>) -> Bool {
        switch self {
        case .all: return true
        case .new: return newIDs.contains(device.id)
        case .favorites: return device.isFavorite
        case .web: return device.hasWebService
        case .online: return device.status == .online
        case .unconfirmed: return device.status != .online
        }
    }
}
enum ExportScope: String, CaseIterable, Identifiable {
    case selected, filtered, all
    var id: String { rawValue }
    var title: String {
        switch self { case .selected: return "Выбранные"; case .filtered: return "Результаты поиска"; case .all: return "Все устройства" }
    }
}
