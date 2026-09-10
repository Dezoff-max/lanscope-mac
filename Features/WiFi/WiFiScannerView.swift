import SwiftUI

struct WiFiScannerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var searchText = ""
    @State private var sortOrder = [KeyPathComparator<WiFiNetwork>(\.signalSortValue, order: .reverse)]

    private var networks: [WiFiNetwork] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return appState.wifiNetworks.filter {
            query.isEmpty || [$0.displaySSID, $0.bssid, $0.security, $0.band, $0.phyDisplay]
                .joined(separator: " ").localizedCaseInsensitiveContains(query)
        }.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Label("Nearby Networks", systemImage: "wifi")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if let interfaceName = appState.wifiInterfaceName {
                    Text(interfaceName).font(.callout.monospaced()).foregroundStyle(.secondary)
                }
                Text("2.4 / 5 / 6 GHz").font(.callout).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background { ChromeSurface() }

            Divider()

            Group {
                if !searchText.isEmpty && networks.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else if appState.wifiNetworks.isEmpty {
                    RadarEmptyStateView(
                        isScanning: appState.isWiFiScanning,
                        idleTitle: "Nearby Wi-Fi",
                        scanningTitle: "Scanning Wi-Fi",
                        idleSystemImage: "wifi",
                        scanningSystemImage: "dot.radiowaves.left.and.right",
                        idleMessage: "Wireless networks and radio channels",
                        scanningMessage: "Listening for nearby access points"
                    )
                } else {
                    networkTable
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            .animation(InterfaceMotion.transition(reduceMotion: reduceMotion), value: appState.wifiNetworks.isEmpty)

            Divider()
            ScanStatusBar(message: appState.wifiStatusMessage, isScanning: appState.isWiFiScanning,
                          count: appState.wifiNetworks.count, noun: appState.wifiNetworks.count == 1 ? "network" : "networks")
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search Wi-Fi networks")
    }

    private func arrivalDelay(_ network: WiFiNetwork) -> Double {
        Double(appState.wifiNetworks.firstIndex(where: { $0.id == network.id }) ?? 0) * 0.025
    }

    private var networkTable: some View {
        Table(networks, selection: $appState.selectedWiFiNetworkIDs, sortOrder: $sortOrder) {
            TableColumn("Network", value: \.ssidSortValue) { network in
                AppearingCell(id: network.id, delay: arrivalDelay(network)) {
                    HStack(spacing: 10) {
                        Image(systemName: "wifi").foregroundStyle(.secondary).frame(width: 18)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(network.displaySSID).fontWeight(.medium).lineLimit(1)
                            Text(network.bssid).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                .help("\(network.displaySSID)\n\(network.bssid)")
                .contextMenu {
                    Button("Copy SSID") { appState.copyWiFiSSID(network) }
                    Button("Copy BSSID") { appState.copyWiFiBSSID(network) }
                        .disabled(network.bssid == "-")
                }
            }
            .width(min: 220, ideal: 240, max: 360)

            TableColumn("Signal", value: \.signalSortValue) { network in
                AppearingCell(id: network.id, delay: arrivalDelay(network)) {
                    HStack(spacing: 8) {
                        Image(systemName: "cellularbars")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(network.signalPercent >= 60 ? Color.green : Color.orange)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(network.rssi) dBm").monospacedDigit()
                            Text(network.signalQuality).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .width(min: 104, ideal: 112)

            TableColumn("Security", value: \.securitySortValue) { network in
                AppearingCell(id: network.id, delay: arrivalDelay(network)) {
                    Label(network.security, systemImage: network.security == "Open" ? "lock.open" : "lock")
                        .lineLimit(1)
                }
                .help(network.security)
            }
            .width(min: 130, ideal: 154)

            TableColumn("Channel", value: \.channelSortValue) { network in
                AppearingCell(id: network.id, delay: arrivalDelay(network)) {
                    Text(network.channelDisplay).monospacedDigit()
                }
            }
            .width(62)

            TableColumn("Band", value: \.bandSortValue) { network in
                AppearingCell(id: network.id, delay: arrivalDelay(network)) { Text(network.band) }
            }
            .width(68)

            TableColumn("Width", value: \.channelWidth) { network in
                AppearingCell(id: network.id, delay: arrivalDelay(network)) { Text(network.channelWidth) }
            }
            .width(68)

            TableColumn("PHY", value: \.phyDisplay) { network in
                AppearingCell(id: network.id, delay: arrivalDelay(network)) {
                    Text(network.phyDisplay).lineLimit(1)
                }
                .help(network.phyDisplay)
            }
            .width(min: 90, ideal: 120)

            TableColumn("Noise", value: \.noiseDisplay) { network in
                AppearingCell(id: network.id, delay: arrivalDelay(network)) {
                    Text(network.noiseDisplay).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            .width(76)
        }
    }
}
