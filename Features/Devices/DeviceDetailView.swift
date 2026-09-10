import SwiftUI

struct DeviceDetailView: View {
    @EnvironmentObject private var appState: AppState
    let device: Device?

    var body: some View {
        if let device {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(device)
                    Divider()
                    InspectorSection(title: "Device") {
                        fact("Hostname", device.hostname.isEmpty ? "Unavailable" : device.hostname)
                        fact("IP Address", device.ipAddress)
                        fact("MAC Address", device.macAddress ?? "Unavailable")
                        fact("Manufacturer", device.vendor)
                        fact("Last Seen", DateFormatter.lanScopeDateTime.string(from: device.lastSeen))
                    }
                    Divider()
                    InspectorSection(title: "Services") {
                        if device.services.isEmpty {
                            Text("No open services").foregroundStyle(.secondary)
                        } else {
                            ForEach(device.services) { service in
                                HStack {
                                    Text(service.name)
                                    Spacer()
                                    Text(String(service.port)).monospacedDigit().foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Divider()
                    InspectorSection(title: "Connect") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            action("Browser", "safari", enabled: device.hasWebService) { appState.openBrowser(for: device) }
                            action("SSH", "terminal", enabled: device.hasSSH) { appState.connectSSH(to: device) }
                            action("SMB", "folder", enabled: device.hasSMB) { appState.openSMB(for: device) }
                            action("VNC", "display", enabled: device.hasVNC) { appState.openVNC(for: device) }
                        }
                    }
                    Divider()
                    HStack(spacing: 12) {
                        iconAction("Copy IP", "doc.on.doc") { appState.copyIP(device) }
                        iconAction("Copy MAC", "number", enabled: device.macAddress != nil) { appState.copyMAC(device) }
                        Spacer()
                        iconAction(device.isFavorite ? "Remove Favorite" : "Add Favorite",
                                   device.isFavorite ? "star.fill" : "star") { appState.toggleFavorite(device) }
                        iconAction("Wake-on-LAN", "power", enabled: device.macAddress != nil) { appState.wakeOnLAN(device) }
                    }
                }
                .padding(20)
            }
        } else {
            ContentUnavailableView("No Selection", systemImage: "sidebar.right")
        }
    }

    private func header(_ device: Device) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(Color.accentColor)
            Text(device.displayName).font(.title3.weight(.semibold)).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Label(device.status.title, systemImage: device.status == .online ? "checkmark.circle.fill" : "circle")
                .font(.callout)
                .foregroundStyle(device.status == .online ? Color.green : Color.secondary)
        }
    }

    private func fact(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func action(_ title: String, _ symbol: String, enabled: Bool, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity, minHeight: 22)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
        .help(title)
    }

    private func iconAction(_ title: String, _ symbol: String, enabled: Bool = true, run: @escaping () -> Void) -> some View {
        Button(action: run) { Label(title, systemImage: symbol) }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .frame(width: 24, height: 28)
            .disabled(!enabled)
            .help(title)
    }
}
