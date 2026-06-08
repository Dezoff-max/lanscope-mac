import SwiftUI

struct DeviceDetailView: View {
    @EnvironmentObject private var appState: AppState
    let device: Device?

    var body: some View {
        Group {
            if let device {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header(for: device)
                        facts(for: device)
                        services(for: device)
                        actions(for: device)
                    }
                    .padding(16)
                }
                .background(.regularMaterial)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "sidebar.right",
                    description: Text("Select a device to see details.")
                )
                .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.24), value: device?.id)
    }

    private func header(for device: Device) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: device.isFavorite ? "star.fill" : "desktopcomputer")
                    .font(.system(size: 30))
                    .foregroundStyle(device.isFavorite ? Color.yellow : Color.accentColor)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.displayName)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                    Text(device.ipAddress)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Label(device.status.title, systemImage: "circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(statusColor(for: device.status))
        }
    }

    private func facts(for device: Device) -> some View {
        GroupBox("Details") {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
                detailRow("Hostname", value: device.hostname.isEmpty ? "-" : device.hostname)
                detailRow("MAC", value: device.macAddress ?? "-")
                detailRow("Vendor", value: device.vendor)
                detailRow("Last Seen", value: DateFormatter.lanScopeDateTime.string(from: device.lastSeen))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func services(for device: Device) -> some View {
        GroupBox("Services") {
            if device.services.isEmpty {
                Text("-")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(device.services) { service in
                        HStack {
                            Text(service.name)
                                .fontWeight(.medium)
                            Spacer()
                            Text(":\(service.port)")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func actions(for device: Device) -> some View {
        GroupBox("Actions") {
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    actionButton("Browser", symbol: "safari", disabled: !device.hasWebService) {
                        appState.openBrowser(for: device)
                    }
                    actionButton("SSH", symbol: "terminal", disabled: !device.hasSSH) {
                        appState.connectSSH(to: device)
                    }
                }

                GridRow {
                    actionButton("SMB", symbol: "folder", disabled: !device.hasSMB) {
                        appState.openSMB(for: device)
                    }
                    actionButton("VNC", symbol: "display", disabled: !device.hasVNC) {
                        appState.openVNC(for: device)
                    }
                }

                GridRow {
                    actionButton("Copy IP", symbol: "doc.on.doc") {
                        appState.copyIP(device)
                    }
                    actionButton("Copy MAC", symbol: "number", disabled: device.macAddress == nil) {
                        appState.copyMAC(device)
                    }
                }

                GridRow {
                    actionButton(device.isFavorite ? "Unfavorite" : "Favorite", symbol: device.isFavorite ? "star.slash" : "star") {
                        appState.toggleFavorite(device)
                    }
                    actionButton("Wake", symbol: "power", disabled: device.macAddress == nil) {
                        appState.wakeOnLAN(device)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func detailRow(_ title: String, value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }

    private func actionButton(
        _ title: String,
        symbol: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(disabled)
    }

    private func statusColor(for status: DeviceStatus) -> Color {
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
