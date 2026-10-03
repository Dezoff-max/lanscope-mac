import Foundation

struct ScanChange: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case added, missing, addressChanged, servicesChanged
    }
    var id: String { "\(kind.rawValue)-\(device.id.uuidString)" }
    let kind: Kind
    let title: String
    let detail: String
    let device: Device
}

struct ScanComparison {
    let changes: [ScanChange]
    let isComparable: Bool
    let explanation: String?

    var added: [ScanChange] { changes.filter { $0.kind == .added } }
    var missing: [ScanChange] { changes.filter { $0.kind == .missing } }
    var addressChanges: [ScanChange] { changes.filter { $0.kind == .addressChanged } }
    var serviceChanges: [ScanChange] { changes.filter { $0.kind == .servicesChanged } }
    var addedCount: Int { added.count }
    var missingCount: Int { missing.count }
    var addressChangedCount: Int { addressChanges.count }
    var servicesChangedCount: Int { serviceChanges.count }

    init(previous: ScanHistory, current: ScanHistory) {
        if let issue = Self.incompatibility(previous, current) {
            changes = []
            isComparable = false
            explanation = issue
            return
        }
        isComparable = true
        explanation = nil
        // A stale ARP entry cannot establish availability or prove a new discovery.
        let previousDevices = previous.devices.filter { $0.status == .online }
        let currentDevices = current.devices.filter { $0.status == .online }
        var usedIndices = Set<Int>()
        var result: [ScanChange] = []
        for device in currentDevices {
            let match = previousDevices.indices.first { index in
                !usedIndices.contains(index) && device.normalizedMAC != nil &&
                device.normalizedMAC == previousDevices[index].normalizedMAC && device.matches(previousDevices[index])
            } ?? previousDevices.indices.first { index in
                !usedIndices.contains(index) && device.matches(previousDevices[index])
            }
            guard let match else {
                result.append(ScanChange(kind: .added, title: "Новое устройство",
                                         detail: "\(device.displayName) · \(device.ipAddress)", device: device))
                continue
            }
            usedIndices.insert(match)
            let previousDevice = previousDevices[match]
            if previousDevice.ipAddress != device.ipAddress {
                result.append(ScanChange(kind: .addressChanged, title: "Изменился IP-адрес",
                                         detail: "\(previousDevice.ipAddress) → \(device.ipAddress)", device: device))
            }
            let before = Set(previousDevice.openPorts)
            let after = Set(device.openPorts)
            if before != after {
                let opened = after.subtracting(before).sorted().map(String.init).joined(separator: ", ")
                let closed = before.subtracting(after).sorted().map(String.init).joined(separator: ", ")
                let parts = [opened.isEmpty ? nil : "Открылись: \(opened)", closed.isEmpty ? nil : "Больше не отвечают: \(closed)"].compactMap { $0 }
                result.append(ScanChange(kind: .servicesChanged, title: "Изменились порты",
                                         detail: parts.joined(separator: "; "), device: device))
            }
        }
        for index in previousDevices.indices where !usedIndices.contains(index) {
            let device = previousDevices[index]
            result.append(ScanChange(kind: .missing, title: "Нет ответа",
                                     detail: "\(device.displayName) · \(device.ipAddress) — не ответило при текущей проверке", device: device))
        }
        changes = result
    }

    private static func incompatibility(_ previous: ScanHistory, _ current: ScanHistory) -> String? {
        guard previous.isComplete && current.isComplete else {
            return "Сравнение доступно после двух полных сканирований. Остановленный, ошибочный или старый скан без данных о проверенных адресах не подтверждает исчезновение устройств."
        }
        guard let before = previous.config, let after = current.config else {
            return "В старой записи не сохранены параметры проверки. Выполните два полных сканирования с одинаковыми параметрами."
        }
        guard previous.profileID == current.profileID,
              before.profileID == after.profileID,
              previous.ipRange.trimmingCharacters(in: .whitespacesAndNewlines) == current.ipRange.trimmingCharacters(in: .whitespacesAndNewlines),
              previous.totalHosts == current.totalHosts,
              before.interfaceName == after.interfaceName else {
            return "Для сравнения нужны одинаковые профиль сети, интерфейс и диапазон адресов."
        }
        guard Set(before.ports) == Set(after.ports), before.timeout == after.timeout else {
            return "Изменились порты или время ожидания. Повторите полное сканирование с теми же параметрами, чтобы сравнение было достоверным."
        }
        return nil
    }
}
