import SwiftUI

struct DeviceTableView: View {
    let devices: [Device]
    @Binding var selection: Set<Device.ID>
    @State private var sortOrder: [KeyPathComparator<Device>] = [
        KeyPathComparator(\.ipSortValue)
    ]

    private var sortedDevices: [Device] {
        guard !sortOrder.isEmpty else {
            return devices.sorted { IPAddressSorter.compare($0.ipAddress, $1.ipAddress) }
        }
        return devices.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedDevices, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Status", value: \.statusSortValue) { device in
                AppearingCell(id: device.id) {
                    StatusBadge(status: device.status)
                }
            }
            .width(74)

            TableColumn("Name", value: \.nameSortValue) { device in
                AppearingCell(id: device.id) {
                    DeviceNameCell(device: device)
                }
                .contextMenu {
                    DeviceContextMenu(device: device)
                }
            }
            .width(min: 164, ideal: 190, max: 320)

            TableColumn("IP Address", value: \.ipSortValue) { device in
                AppearingCell(id: device.id) {
                    Text(device.ipAddress)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                }
            }
            .width(128)

            TableColumn("MAC Address", value: \.macSortValue) { device in
                AppearingCell(id: device.id) {
                    Text(device.macAddress ?? "-")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(device.macAddress == nil ? .secondary : .primary)
                        .lineLimit(1)
                }
            }
            .width(150)

            TableColumn("Vendor", value: \.vendorSortValue) { device in
                AppearingCell(id: device.id) {
                    Text(device.vendor)
                        .lineLimit(1)
                }
                .help(device.vendor)
            }
            .width(min: 140, ideal: 198, max: 320)

            TableColumn("Ports", value: \.openPortsSortValue) { device in
                AppearingCell(id: device.id) {
                    Text(device.openPortsDisplay)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                }
            }
            .width(76)

            TableColumn("Services", value: \.servicesSortValue) { device in
                AppearingCell(id: device.id) {
                    Text(device.servicesDisplay)
                        .lineLimit(1)
                }
            }
            .width(110)

            TableColumn("Last Seen", value: \.lastSeen) { device in
                AppearingCell(id: device.id) {
                    Text(DateFormatter.lanScopeTime.string(from: device.lastSeen))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .width(88)
        }
    }
}

private struct DeviceNameCell: View {
    let device: Device

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: device.isFavorite ? "star.fill" : "desktopcomputer")
                .foregroundStyle(device.isFavorite ? Color.yellow : Color.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(device.displayName)
                    .fontWeight(.medium)
                    .lineLimit(1)
                if let subtitle = device.tableNameSubtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

private struct StatusBadge: View {
    let status: DeviceStatus

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(status.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .animation(.easeInOut(duration: 0.18), value: status)
    }

    private var color: Color {
        switch status {
        case .online:
            return .green
        case .offline:
            return .red
        case .unknown:
            return .orange
        }
    }
}

private struct DeviceContextMenu: View {
    @EnvironmentObject private var appState: AppState
    let device: Device

    var body: some View {
        Button("Open in Browser") {
            appState.openBrowser(for: device)
        }
        .disabled(!device.hasWebService)

        Button("Connect SSH") {
            appState.connectSSH(to: device)
        }
        .disabled(!device.hasSSH)

        Button("Open SMB Share") {
            appState.openSMB(for: device)
        }
        .disabled(!device.hasSMB)

        Button("Open VNC") {
            appState.openVNC(for: device)
        }
        .disabled(!device.hasVNC)

        Divider()

        Button("Copy IP") {
            appState.copyIP(device)
        }

        Button("Copy MAC") {
            appState.copyMAC(device)
        }
        .disabled(device.macAddress == nil)

        Button(device.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
            appState.toggleFavorite(device)
        }
    }
}
