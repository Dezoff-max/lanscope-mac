import SwiftUI

struct ScanView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsProfiles = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Picker("Объект", selection: profileSelection) {
                        if appState.config.profileID == nil { Text("Текущая сеть").tag(Optional<UUID>.none) }
                        ForEach(appState.profiles) { profile in Text(profile.name).tag(Optional(profile.id)) }
                    }.frame(minWidth: 190, maxWidth: 320)
                    Button { showsProfiles = true } label: { Image(systemName: "slider.horizontal.3") }
                        .help("Сохранить настройки объекта и управлять профилями")
                    Spacer(minLength: 4)
                    NetworkInterfacePicker()
                }
                HStack(spacing: 10) {
                    Label("Диапазон", systemImage: "network").foregroundStyle(.secondary)
                    TextField("192.168.1.0/24 или 192.168.1.1–254", text: $appState.config.ipRange)
                        .textFieldStyle(.roundedBorder).monospaced()
                        .accessibilityLabel("Диапазон IP-адресов")
                        .onSubmit { appState.startScan() }
                    Button(action: appState.useDetectedRange) { Image(systemName: "location") }
                        .help("Подставить подсеть выбранного интерфейса")
                }
            }
            .disabled(appState.isScanning)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background { ChromeSurface() }
            Divider()
            if !appState.devices.isEmpty {
                DeviceListControls()
                Divider()
            }
            Group {
                if appState.devices.isEmpty {
                    scanEmptyState
                } else if appState.filteredDevices.isEmpty {
                    FilterEmptyState()
                } else {
                    DeviceTableView(devices: appState.filteredDevices, selection: $appState.selectedDeviceIDs)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            ScanStatusBar(message: appState.statusMessage, isScanning: appState.isScanning,
                          count: appState.devices.count, noun: "устр.", progress: appState.progress)
        }
        .searchable(text: $appState.searchText, placement: .toolbar, prompt: "Имя, IP, MAC, производитель, метка")
        .sheet(isPresented: $showsProfiles) { NetworkProfilesView() }
    }

    private var profileSelection: Binding<UUID?> {
        Binding(get: { appState.config.profileID }, set: { id in
            if let id { appState.selectProfile(id) }

        })
    }

    @ViewBuilder private var scanEmptyState: some View {
        if appState.isScanning {
            RadarEmptyStateView(isScanning: true,
                                scanningTitle: "Ищем устройства",
                                scanningMessage: "Проверяем доступность и открытые порты. Результаты появятся по мере обнаружения.")
        } else if let error = appState.scanError {
            ContentUnavailableView {
                Label("Не удалось завершить проверку", systemImage: "exclamationmark.triangle")
            } description: { Text(error) } actions: {
                Button("Повторить") { appState.startScan() }
                Button("Определить подсеть") { appState.useDetectedRange() }
            }
        } else if appState.hasScanned {
            ContentUnavailableView {
                Label("Устройства не найдены", systemImage: "network")
            } description: {
                Text("Проверьте диапазон и выбранный интерфейс. Устройство может блокировать ping и проверенные TCP-порты.")
            } actions: {
                Button("Повторить сканирование") { appState.startScan() }
                Button("Определить подсеть") { appState.useDetectedRange() }
            }
        } else {
            VStack(spacing: 0) {
                RadarEmptyStateView(isScanning: false,
                                    idleTitle: "Ваша сеть — на одном экране",
                                    idleMessage: "Выберите интерфейс и диапазон, чтобы найти устройства, имена и сервисы.")
                Button { appState.startScan() } label: {
                    Label("Сканировать сеть", systemImage: "play.fill")
                }.buttonStyle(.borderedProminent).controlSize(.large).padding(.bottom, 44)
            }
        }
    }
}

struct NetworkInterfacePicker: View {
    @EnvironmentObject private var appState: AppState
    var body: some View {
        Picker("Интерфейс", selection: Binding(
            get: { appState.config.interfaceName },
            set: { appState.selectInterface($0) }
        )) {
            Text("Автоматически").tag(Optional<String>.none)
            ForEach(appState.availableInterfaces) { interface in
                Text("\(interface.displayName) · \(interface.ipAddress)").tag(Optional(interface.name))
            }
        }
        .help("Сетевой интерфейс для сканирования")
        .frame(minWidth: 210, maxWidth: 340)
    }
}
