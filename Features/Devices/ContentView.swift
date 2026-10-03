import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsInspector = false
    @AppStorage("inspectorWidth") private var inspectorWidth = 310.0
    @State private var dragStartWidth: Double?

    private var hasDeviceTable: Bool {
        [.scan, .favorites, .history].contains(appState.currentSection)
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $appState.selectedSection)
                .navigationSplitViewColumnWidth(min: 164, ideal: 178, max: 225)
        } detail: {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    mainContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    if showsInspector && hasDeviceTable {
                        inspectorDivider
                        DeviceDetailView(device: appState.selectedDevice)
                            .frame(width: min(CGFloat(inspectorWidth), max(280, geometry.size.width * 0.46)))
                            .background(.regularMaterial)
                            .transition(.opacity)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            }
            .navigationTitle(appState.currentSection.title)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let message = appState.notificationMessage {
                    HStack(spacing: 9) {
                        Image(systemName: "info.circle.fill").foregroundStyle(Color.accentColor)
                        Text(message).textSelection(.enabled).lineLimit(3)
                        Spacer(minLength: 8)
                        Button { appState.notificationMessage = nil } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.borderless)
                        .help("Закрыть уведомление")
                    }
                    .font(.callout)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background { ChromeSurface() }
                }
            }
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
                        if appState.currentSection == .wifi { appState.startWiFiScan() }
                        else { appState.startScan() }
                    } label: { Label("Сканировать", systemImage: "play.fill") }
                        .help("Начать сканирование")
                        .disabled(appState.currentSection == .wifi ? appState.isWiFiScanning : appState.isScanning)
                    Button {
                        if appState.currentSection == .wifi { appState.stopWiFiScan() }
                        else { appState.stopScan() }
                    } label: { Label("Остановить", systemImage: "stop.fill") }
                        .help("Остановить сканирование")
                        .disabled(appState.currentSection == .wifi ? !appState.isWiFiScanning : !appState.isScanning)
                }
            }
            if hasDeviceTable {
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        exportMenu("Видимые строки", scope: .filtered)
                        exportMenu("Выбранные строки", scope: .selected)
                            .disabled(appState.selectedDeviceIDs.isEmpty)
                        exportMenu("Все устройства раздела", scope: .all)
                        Divider()
                        Button("Скопировать выбранные строки", action: appState.copySelectedRows)
                            .disabled(appState.selectedDeviceIDs.isEmpty)
                    } label: { Label("Экспорт", systemImage: "square.and.arrow.up") }
                        .help("Экспортировать устройства")
                        .disabled(appState.visibleDevices.isEmpty)
                    Button {
                        withAnimation(InterfaceMotion.transition(reduceMotion: reduceMotion)) {
                            showsInspector.toggle()
                        }
                    } label: { Label("Карточка устройства", systemImage: "sidebar.right") }
                        .help(showsInspector ? "Скрыть карточку" : "Показать карточку")
                        .disabled(appState.selectedDeviceIDs.count != 1 && !showsInspector)
                }
            }
        }
    }

    private var inspectorDivider: some View {
        Rectangle().fill(Color.secondary.opacity(0.22)).frame(width: 1)
            .overlay { Color.clear.frame(width: 8).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if dragStartWidth == nil { dragStartWidth = inspectorWidth }
                        inspectorWidth = min(480, max(280, (dragStartWidth ?? inspectorWidth) - Double(value.translation.width)))
                    }
                    .onEnded { _ in dragStartWidth = nil })
            }
            .help("Перетащите, чтобы изменить ширину карточки")
            .accessibilityLabel("Ширина карточки устройства")
            .accessibilityAdjustableAction { direction in
                inspectorWidth = min(480, max(280, inspectorWidth + (direction == .increment ? 20 : -20)))
            }
    }

    private func exportMenu(_ title: String, scope: ExportScope) -> some View {
        Menu(title) {
            Button("CSV") { appState.exportCSV(scope: scope) }
            Button("JSON") { appState.exportJSON(scope: scope) }
        }
    }

    @ViewBuilder private var mainContent: some View {
        switch appState.currentSection {
        case .scan: ScanView()
        case .wifi: WiFiScannerView()
        case .favorites: FavoritesView()
        case .history: HistoryView()
        case .settings: SettingsView(config: $appState.config)
        }
    }
}
