import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsInspector = false

    private var hasDeviceTable: Bool {
        [.scan, .favorites, .history].contains(appState.currentSection)
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $appState.selectedSection)
                .navigationSplitViewColumnWidth(min: 140, ideal: 156, max: 200)
        } detail: {
            // Bound flexible empty states to the split view's available content area.
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    mainContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .background(Color(nsColor: .textBackgroundColor))
                    if showsInspector {
                        Divider()
                        DeviceDetailView(device: appState.selectedDevice)
                            .frame(width: 290)
                            .transition(.opacity)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            }
            .navigationTitle(appState.currentSection.title)
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: appState.selectedDeviceIDs) { _, selection in
            if hasDeviceTable {
                withAnimation(InterfaceMotion.transition(reduceMotion: reduceMotion)) {
                    showsInspector = selection.count == 1
                }
            }
        }
        .onChange(of: appState.currentSection) { _, _ in showsInspector = false }
        .toolbar {
            if appState.currentSection == .scan || appState.currentSection == .wifi {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        if appState.currentSection == .wifi {
                            appState.startWiFiScan()
                        } else {
                            appState.startScan()
                        }
                    } label: {
                        Label("Scan", systemImage: "play.fill")
                    }
                    .help(appState.currentSection == .wifi ? "Scan nearby Wi-Fi networks" : "Scan IP range")
                    .disabled(appState.currentSection == .wifi ? appState.isWiFiScanning : appState.isScanning)

                    if appState.currentSection == .scan {
                        Button(action: appState.stopScan) {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .help("Stop scan")
                        .disabled(!appState.isScanning)
                    }
                }
            }

            if hasDeviceTable {
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        Button("Export CSV", action: appState.exportCSV)
                        Button("Export JSON", action: appState.exportJSON)
                        Divider()
                        Button("Copy Selected Rows", action: appState.copySelectedRows)
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .help("Export devices")
                    .disabled(appState.exportableSelection.isEmpty)

                    Button {
                        withAnimation(InterfaceMotion.transition(reduceMotion: reduceMotion)) {
                            showsInspector.toggle()
                        }
                    } label: {
                        Label("Inspector", systemImage: "sidebar.right")
                    }
                    .help(showsInspector ? "Hide inspector" : "Show inspector")
                    .disabled(appState.selectedDeviceIDs.count != 1 && !showsInspector)
                }
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch appState.currentSection {
        case .scan: ScanView()
        case .wifi: WiFiScannerView()
        case .favorites: FavoritesView()
        case .history: HistoryView()
        case .settings: SettingsView(config: $appState.config)
        }
    }
}
