import SwiftUI

struct ScanView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var searchText = ""

    private var filteredDevices: [Device] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.devices }
        return appState.devices.filter {
            [$0.displayName, $0.ipAddress, $0.macAddress ?? "", $0.vendor, $0.servicesDisplay]
                .joined(separator: " ").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Label("IP Range", systemImage: "network")
                    .foregroundStyle(.secondary)
                TextField("IP range", text: $appState.config.ipRange)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .accessibilityLabel("IP range")
                    .onSubmit { appState.startScan() }
                    .disabled(appState.isScanning)
                Button(action: appState.useDetectedRange) {
                    Label("Detect Range", systemImage: "location")
                }
                .labelStyle(.iconOnly)
                .help("Detect the local IPv4 range")
                .disabled(appState.isScanning)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background { ChromeSurface() }

            Divider()

            Group {
                if !searchText.isEmpty && filteredDevices.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else if appState.devices.isEmpty {
                    RadarEmptyStateView(isScanning: appState.isScanning)
                } else {
                    DeviceTableView(devices: filteredDevices, selection: $appState.selectedDeviceIDs)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            .animation(InterfaceMotion.transition(reduceMotion: reduceMotion), value: appState.devices.isEmpty)

            Divider()
            ScanStatusBar(message: appState.statusMessage, isScanning: appState.isScanning,
                          count: appState.devices.count, noun: appState.devices.count == 1 ? "device" : "devices",
                          progress: appState.progress)
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search devices")
    }
}
