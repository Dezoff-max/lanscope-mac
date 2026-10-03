import SwiftUI

struct DeviceDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let device: Device?
    @State private var editingDevice: Device?
    @State private var copiedValue: String?
    @State private var favoritePulse = false

    var body: some View {
        if let device {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(device)
                    Divider()
                    InspectorSection(title: "Устройство") {
                        fact("Имя в сети", device.hostname.isEmpty ? "Не определено" : device.hostname)
                        copyFact("IP-адрес", device.ipAddress, key: "ip") { appState.copyIP(device) }
                        copyFact("MAC-адрес", device.macAddress ?? "Не определён", key: "mac", enabled: device.macAddress != nil) {
                            appState.copyMAC(device)
                        }
                        fact("Производитель", device.vendorDisplay)
                        fact("Обнаружено", DateFormatter.lanScopeDateTime.string(from: device.lastSeen))
                        if !device.tags.isEmpty {
                            fact("Метки", device.tags.joined(separator: " · "))
                        }
                        if !device.notes.isEmpty { fact("Заметка", device.notes) }
                    }
                    Divider()
                    DeviceMonitorView(device: device, interfaceName: appState.config.interfaceName)
                    Divider()
                    InspectorSection(title: "Сервисы") {
                        if device.services.isEmpty {
                            Text("На проверенных портах сервисы не обнаружены.")
                                .font(.callout).foregroundStyle(.secondary)
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
                    InspectorSection(title: "Подключение") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            action("Браузер", "safari", enabled: device.hasWebService,
                                   reason: "Веб-сервис на проверенных портах не обнаружен") { appState.openBrowser(for: device) }
                            action("SSH", "terminal", enabled: device.hasSSH,
                                   reason: "SSH на порту 22 не обнаружен") { appState.connectSSH(to: device) }
                            action("SMB", "folder", enabled: device.hasSMB,
                                   reason: "SMB на порту 445 не обнаружен") { appState.openSMB(for: device) }
                            action("VNC", "display", enabled: device.hasVNC,
                                   reason: "VNC на порту 5900 не обнаружен") { appState.openVNC(for: device) }
                        }
                        Button { appState.wakeOnLAN(device) } label: {
                            Label("Wake-on-LAN", systemImage: "power")
                        }
                        .disabled(device.macAddress == nil)
                        .help(device.macAddress == nil ? "Для Wake-on-LAN нужен MAC-адрес" : "Отправить пакет пробуждения")
                    }
                }
                .padding(18)
            }
            .sheet(item: $editingDevice) { DeviceMetadataEditor(device: $0) }
            .onChange(of: device.id) { _, _ in copiedValue = nil }
        } else {
            ContentUnavailableView("Выберите устройство", systemImage: "sidebar.right",
                                   description: Text("В карточке появятся сведения и действия."))
        }
    }

    private func header(_ device: Device) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: device.kind.systemImage)
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 46, height: 46)
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
                Spacer()
                Button {
                    appState.toggleFavorite(device)
                    guard !reduceMotion else { return }
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.55)) { favoritePulse = true }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(180))
                        withAnimation(.easeOut(duration: 0.16)) { favoritePulse = false }
                    }
                } label: {
                    Image(systemName: device.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(device.isFavorite ? Color.yellow : Color.secondary)
                        .scaleEffect(favoritePulse ? 1.18 : 1)
                }
                .buttonStyle(.borderless)
                .help(device.isFavorite ? "Убрать из избранного" : "Добавить в избранное")
                Button { editingDevice = device } label: { Image(systemName: "pencil") }
                    .buttonStyle(.borderless).help("Изменить имя, тип и заметки")
            }
            Text(device.displayName).font(.title3.weight(.semibold)).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                StatusBadge(status: device.status)
                Spacer()
                Button { appState.recheckDevice(device) } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless).help("Проверить доступность повторно")
            }
            if device.status == .cached {
                Text("Запись найдена в ARP-кэше. Текущая доступность не подтверждена.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func fact(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func copyFact(_ title: String, _ value: String, key: String, enabled: Bool = true, run: @escaping () -> Void) -> some View {
        HStack(alignment: .center) {
            fact(title, value)
            Spacer()
            Button {
                run()
                withAnimation(.easeOut(duration: reduceMotion ? 0 : 0.16)) { copiedValue = key }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.6))
                    if copiedValue == key { copiedValue = nil }
                }
            } label: {
                Image(systemName: copiedValue == key ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(copiedValue == key ? Color.green : Color.secondary)
                    .frame(width: 20, height: 22)
            }
            .buttonStyle(.borderless).disabled(!enabled)
            .help(copiedValue == key ? "Скопировано" : "Скопировать \(title)")
        }
    }

    private func action(_ title: String, _ symbol: String, enabled: Bool, reason: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity, minHeight: 22)
        }
        .buttonStyle(.bordered).disabled(!enabled).help(enabled ? title : reason)
    }
}
