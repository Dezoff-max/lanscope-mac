import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $appState.selectedSection)
                .navigationSplitViewColumnWidth(min: 122, ideal: 126, max: 136)
        } detail: {
            contentWithOptionalDetail
                .navigationTitle(appState.currentSection.title)
                .navigationSplitViewColumnWidth(min: 940, ideal: 1036)
        }
        .animation(.snappy(duration: 0.22), value: appState.currentSection)
        .animation(.snappy(duration: 0.2), value: appState.selectedDevice?.id)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    if appState.currentSection == .wifi {
                        appState.startWiFiScan()
                    } else {
                        appState.startScan()
                    }
                } label: {
                    Label(appState.currentSection == .wifi ? "Scan Wi-Fi" : "Scan", systemImage: "play.fill")
                }
                .disabled(appState.currentSection == .wifi ? appState.isWiFiScanning : appState.isScanning)

                Button {
                    appState.stopScan()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(appState.currentSection == .wifi || !appState.isScanning)

                Menu {
                    Button("Export CSV") {
                        appState.exportCSV()
                    }
                    Button("Export JSON") {
                        appState.exportJSON()
                    }
                    Divider()
                    Button("Copy Selected Rows") {
                        appState.copySelectedRows()
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(appState.exportableSelection.isEmpty)
            }
        }
    }

    @ViewBuilder
    private var contentWithOptionalDetail: some View {
        HStack(spacing: 0) {
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if shouldShowDeviceDetail {
                Divider()
                DeviceDetailView(device: appState.selectedDevice)
                    .frame(width: 272)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var shouldShowDeviceDetail: Bool {
        appState.selectedDevice != nil && appState.currentSection != .settings && appState.currentSection != .wifi
    }

    @ViewBuilder
    private var mainContent: some View {
        switch appState.currentSection {
        case .scan:
            ScanView()
        case .wifi:
            WiFiScannerView()
        case .favorites:
            FavoritesView()
        case .history:
            HistoryView()
        case .settings:
            SettingsView(config: $appState.config)
        }
    }
}
