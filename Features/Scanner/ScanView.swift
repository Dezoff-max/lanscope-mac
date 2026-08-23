import SwiftUI

struct ScanView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""

    private var filteredDevices: [Device] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return appState.devices
        }
        return appState.devices.filter { device in
            [
                device.displayName,
                device.ipAddress,
                device.macAddress ?? "",
                device.vendor,
                device.servicesDisplay
            ]
            .joined(separator: " ")
            .localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            scanControls

            Divider()

            if filteredDevices.isEmpty {
                RadarEmptyStateView(
                    isScanning: appState.isScanning
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                DeviceTableView(devices: filteredDevices, selection: $appState.selectedDeviceIDs)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.snappy(duration: 0.26), value: filteredDevices.count)
        .animation(.easeInOut(duration: 0.2), value: appState.isScanning)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search devices")
    }

    private var scanControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TextField("IP range", text: $appState.config.ipRange)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 180, idealWidth: 260, maxWidth: .infinity)

                Button {
                    appState.useDetectedRange()
                } label: {
                    Label("Detect Range", systemImage: "location.fill")
                }
                .help("Detect the local IPv4 subnet and fill the scan range.")
            }

            HStack(spacing: 12) {
                ProgressView(value: appState.progress)
                    .tint(appState.isScanning ? .cyan : .accentColor)
                    .frame(maxWidth: 240)
                    .shadow(
                        color: appState.isScanning ? Color.cyan.opacity(0.32) : .clear,
                        radius: appState.isScanning ? 8 : 0
                    )

                Text(appState.statusMessage)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ScanActivityDots(isActive: appState.isScanning)

                Spacer()

                Text("\(appState.devices.count) found")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(12)
        .background(.bar)
    }
}
