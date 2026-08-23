import SwiftUI

struct WiFiScannerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var sortOrder: [KeyPathComparator<WiFiNetwork>] = [
        KeyPathComparator(\.signalSortValue, order: .reverse)
    ]

    private var filteredNetworks: [WiFiNetwork] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return appState.wifiNetworks
        }

        return appState.wifiNetworks.filter { network in
            [
                network.displaySSID,
                network.bssid,
                network.security,
                network.band,
                network.phyDisplay
            ]
            .joined(separator: " ")
            .localizedCaseInsensitiveContains(query)
        }
    }

    private var sortedNetworks: [WiFiNetwork] {
        guard !sortOrder.isEmpty else {
            return filteredNetworks.sorted { $0.signalSortValue > $1.signalSortValue }
        }
        return filteredNetworks.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            controls

            Divider()

            if sortedNetworks.isEmpty {
                RadarEmptyStateView(
                    isScanning: appState.isWiFiScanning,
                    idleTitle: "No Wi-Fi Networks",
                    scanningTitle: "Scanning Wi-Fi",
                    idleSystemImage: "wifi",
                    scanningSystemImage: "dot.radiowaves.left.and.right",
                    idleMessage: "Run a Wi-Fi scan. macOS may require Location Services to show SSID and BSSID.",
                    scanningMessage: "Listening for nearby access points and radio channels."
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                Table(sortedNetworks, selection: $appState.selectedWiFiNetworkIDs, sortOrder: $sortOrder) {
                    TableColumn("Signal", value: \.signalSortValue) { network in
                        WiFiAppearingCell(id: network.id) {
                            SignalCell(network: network)
                        }
                    }
                    .width(84)

                    TableColumn("SSID", value: \.ssidSortValue) { network in
                        WiFiAppearingCell(id: network.id) {
                            SSIDCell(network: network)
                        }
                        .contextMenu {
                            WiFiNetworkContextMenu(network: network)
                        }
                    }
                    .width(150)

                    TableColumn("BSSID", value: \.bssidSortValue) { network in
                        WiFiAppearingCell(id: network.id) {
                            Text(network.bssid)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(network.bssid == "-" ? .secondary : .primary)
                                .lineLimit(1)
                        }
                    }
                    .width(126)

                    TableColumn("Security", value: \.securitySortValue) { network in
                        WiFiAppearingCell(id: network.id) {
                            Text(network.security)
                                .lineLimit(1)
                        }
                    }
                    .width(108)

                    TableColumn("Channel", value: \.channelSortValue) { network in
                        WiFiAppearingCell(id: network.id) {
                            Text(network.channelDisplay)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                        }
                    }
                    .width(56)

                    TableColumn("Band", value: \.bandSortValue) { network in
                        WiFiAppearingCell(id: network.id) {
                            Text(network.band)
                                .lineLimit(1)
                        }
                    }
                    .width(58)

                    TableColumn("Width", value: \.channelWidth) { network in
                        WiFiAppearingCell(id: network.id) {
                            Text(network.channelWidth)
                                .lineLimit(1)
                        }
                    }
                    .width(58)

                    TableColumn("PHY", value: \.phyDisplay) { network in
                        WiFiAppearingCell(id: network.id) {
                            Text(network.phyDisplay)
                                .lineLimit(1)
                        }
                    }
                    .width(88)

                    TableColumn("Noise", value: \.noiseDisplay) { network in
                        WiFiAppearingCell(id: network.id) {
                            Text(network.noiseDisplay)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(network.noise == nil ? .secondary : .primary)
                                .lineLimit(1)
                        }
                    }
                    .width(66)

                }
                .animation(.snappy(duration: 0.22), value: sortedNetworks.count)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.snappy(duration: 0.26), value: sortedNetworks.count)
        .animation(.easeInOut(duration: 0.2), value: appState.isWiFiScanning)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search Wi-Fi networks")
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Label("Wi-Fi Scanner", systemImage: "wifi")
                    .font(.headline)

                if let interfaceName = appState.wifiInterfaceName {
                    Text(interfaceName)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    appState.startWiFiScan()
                } label: {
                    Label(appState.wifiNetworks.isEmpty ? "Scan" : "Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(appState.isWiFiScanning)
                .keyboardShortcut("w", modifiers: [.command, .shift])
            }

            HStack(spacing: 12) {
                if appState.isWiFiScanning {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.cyan)
                }

                Text(appState.wifiStatusMessage)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ScanActivityDots(isActive: appState.isWiFiScanning)

                Spacer()

                Text("\(appState.wifiNetworks.count) networks")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(12)
        .background(.bar)
    }
}

private struct SignalCell: View {
    let network: WiFiNetwork

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: signalSymbol)
                .foregroundStyle(signalColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(network.rssi) dBm")
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)

                Text(network.signalQuality)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var signalSymbol: String {
        switch network.signalPercent {
        case 75...:
            return "wifi"
        case 45..<75:
            return "wifi.exclamationmark"
        default:
            return "wifi.slash"
        }
    }

    private var signalColor: Color {
        switch network.signalPercent {
        case 75...:
            return .green
        case 45..<75:
            return .orange
        default:
            return .red
        }
    }
}

private struct SSIDCell: View {
    let network: WiFiNetwork

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(network.displaySSID)
                .lineLimit(1)
            Text(network.security)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct WiFiAppearingCell<Content: View>: View {
    let id: WiFiNetwork.ID
    let content: Content
    @State private var isVisible = false

    init(id: WiFiNetwork.ID, @ViewBuilder content: () -> Content) {
        self.id = id
        self.content = content()
    }

    var body: some View {
        content
            .opacity(isVisible ? 1 : 0.58)
            .offset(y: isVisible ? 0 : 4)
            .onAppear(perform: animateIn)
            .onChange(of: id) { _, _ in
                isVisible = false
                animateIn()
            }
    }

    private func animateIn() {
        withAnimation(.snappy(duration: 0.24)) {
            isVisible = true
        }
    }
}

private struct WiFiNetworkContextMenu: View {
    @EnvironmentObject private var appState: AppState
    let network: WiFiNetwork

    var body: some View {
        Button("Copy SSID") {
            appState.copyWiFiSSID(network)
        }

        Button("Copy BSSID") {
            appState.copyWiFiBSSID(network)
        }
        .disabled(network.bssid == "-")
    }
}
