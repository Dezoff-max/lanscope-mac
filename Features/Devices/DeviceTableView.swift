import SwiftUI

struct DeviceTableView: View {
    @EnvironmentObject private var appState: AppState
    let devices: [Device]
    @Binding var selection: Set<Device.ID>
    @State private var sortOrder = [KeyPathComparator(\Device.ipSortValue)]
    @State private var presentedIDs: Set<UUID> = []
    @State private var highlightedIDs: Set<UUID> = []
    @AppStorage("deviceColumnMAC") private var showMAC = false
    @AppStorage("deviceColumnVendor") private var showVendor = true
    @AppStorage("deviceColumnPorts") private var showPorts = false
    @AppStorage("deviceColumnServices") private var showServices = false
    @AppStorage("deviceColumnSeen") private var showSeen = false

    private var sortedDevices: [Device] { devices.sorted(using: sortOrder) }

    var body: some View {
        Group {
            if #available(macOS 14.4, *) {
                configurableTable
            } else {
                compactTable
            }
        }
        // Native table sorting and selection must stay immediate and keep rows still.
        .transaction { $0.animation = nil }
        .onChange(of: devices.map(\.id), initial: true) { _, ids in
            let newlyPresented = Set(ids).subtracting(presentedIDs)
            presentedIDs.formUnion(ids)
            guard appState.isScanning, !newlyPresented.isEmpty else { return }
            highlightedIDs.formUnion(newlyPresented)
            // Owned by the table, not a reused cell: scrolling cannot restart this highlight.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                highlightedIDs.subtract(newlyPresented)
            }
        }
    }

    @available(macOS 14.4, *)
    private var configurableTable: some View {
        Table(sortedDevices, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Статус", value: \.statusSortValue) { device in
                StatusBadge(status: device.status)
            }.width(min: 100, ideal: 110, max: 140)
            TableColumn("Устройство", value: \.nameSortValue) { device in
                DeviceNameCell(device: device, isNew: appState.newDeviceIDs.contains(device.id),
                               highlighted: highlightedIDs.contains(device.id))
                    .contextMenu { DeviceContextMenu(device: device) }
            }.width(min: 170, ideal: 210, max: 380)
            TableColumn("IP-адрес", value: \.ipSortValue) { device in
                Text(device.ipAddress).monospaced().lineLimit(1).textSelection(.enabled)
            }.width(min: 118, ideal: 126, max: 156)
            if showMAC {
                TableColumn("MAC-адрес", value: \.macSortValue) { device in
                    Text(device.macAddress ?? "Не определён").monospaced().lineLimit(1)
                        .foregroundStyle(device.macAddress == nil ? .secondary : .primary)
                }.width(min: 142, ideal: 152, max: 175)
            }
            if showVendor {
                TableColumn("Производитель", value: \.vendorSortValue) { device in
                    Text(device.vendorDisplay).lineLimit(1).help(device.vendorDisplay)
                }.width(min: 110, ideal: 155, max: 280)
            }
            if showPorts {
                TableColumn("Порты", value: \.openPortsSortValue) { device in
                    Text(device.openPortsDisplay).monospaced().lineLimit(1).help(device.openPortsDisplay)
                }.width(min: 70, ideal: 95, max: 200)
            }
            if showServices {
                TableColumn("Сервисы", value: \.servicesSortValue) { device in
                    Text(device.servicesDisplay).lineLimit(1).help(device.servicesDisplay)
                }.width(min: 90, ideal: 130, max: 220)
            }
            if showSeen {
                TableColumn("Обнаружено", value: \.lastSeen) { device in
                    Text(DateFormatter.lanScopeTime.string(from: device.lastSeen))
                        .foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
                }.width(95)
            }
        }
    }

    // macOS 14.0–14.3 do not support conditional TableColumn builders.
    private var compactTable: some View {
        Table(sortedDevices, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Статус", value: \.statusSortValue) { device in
                StatusBadge(status: device.status)
            }.width(min: 100, ideal: 110, max: 140)
            TableColumn("Устройство", value: \.nameSortValue) { device in
                DeviceNameCell(device: device, isNew: appState.newDeviceIDs.contains(device.id),
                               highlighted: highlightedIDs.contains(device.id))
                    .contextMenu { DeviceContextMenu(device: device) }
            }.width(min: 170, ideal: 210, max: 380)
            TableColumn("IP-адрес", value: \.ipSortValue) { device in
                Text(device.ipAddress).monospaced().lineLimit(1).textSelection(.enabled)
            }.width(min: 118, ideal: 126, max: 156)
            TableColumn("Производитель", value: \.vendorSortValue) { device in
                Text(device.vendorDisplay).lineLimit(1).help(device.vendorDisplay)
            }.width(min: 110, ideal: 155, max: 280)
        }
    }

}

private struct DeviceNameCell: View {
    let device: Device
    let isNew: Bool
    let highlighted: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: device.kind.systemImage)
                .foregroundStyle(.secondary).frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(device.displayName).fontWeight(.medium).lineLimit(1)
                    if device.isFavorite {
                        Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                            .accessibilityLabel("Избранное")
                    }
                    if isNew {
                        Text("НОВОЕ").font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 3))
                    }
                }
                if let subtitle = device.tableNameSubtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .frame(minHeight: 34)
        .padding(.horizontal, 3)
        .background(Color.accentColor.opacity(highlighted ? 0.12 : 0), in: RoundedRectangle(cornerRadius: 5))
        .animation(.easeOut(duration: reduceMotion ? 0 : 0.3), value: highlighted)
    }
}

struct StatusBadge: View {
    let status: DeviceStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(status.title).font(.caption.weight(.medium)).lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .help(explanation)
        .animation(.easeInOut(duration: reduceMotion ? 0 : 0.18), value: status)
        .accessibilityLabel("Состояние: \(status.title). \(explanation)")
    }

    private var color: Color {
        switch status {
        case .online: return .green
        case .offline: return .red
        case .cached: return .orange
        case .unknown: return .secondary
        }
    }
    private var explanation: String {
        switch status {
        case .online: return "Ответило при последней проверке"
        case .offline: return "Не ответило при последней проверке"
        case .cached: return "Есть в ARP-кэше, но ответ при сканировании не получен"
        case .unknown: return "Доступность ещё не проверена"
        }
    }
}

private struct DeviceContextMenu: View {
    @EnvironmentObject private var appState: AppState
    let device: Device

    var body: some View {
        Button("Проверить повторно") { appState.recheckDevice(device) }
        Divider()
        Button("Открыть в браузере") { appState.openBrowser(for: device) }.disabled(!device.hasWebService)
        Button("Подключиться по SSH") { appState.connectSSH(to: device) }.disabled(!device.hasSSH)
        Button("Открыть SMB") { appState.openSMB(for: device) }.disabled(!device.hasSMB)
        Button("Открыть VNC") { appState.openVNC(for: device) }.disabled(!device.hasVNC)
        Divider()
        Button("Скопировать IP") { appState.copyIP(device) }
        Button("Скопировать MAC") { appState.copyMAC(device) }.disabled(device.macAddress == nil)
        Button(device.isFavorite ? "Убрать из избранного" : "Добавить в избранное") { appState.toggleFavorite(device) }
    }
}
