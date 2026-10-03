import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var config: ScannerConfig
    @State private var portsDraft = ""
    @State private var portsError: String?
    @State private var portsSaved = false
    @FocusState private var portsFocused: Bool

    var body: some View {
        Form {
            Section("Сканирование") {
                TextField("Диапазон", text: $config.ipRange).monospaced()
                NetworkInterfacePicker()
                Toggle("Имена Bonjour/mDNS", isOn: $config.bonjourEnabled)
                    .disabled(config.interfaceName != nil)
                    .help("Дополнять имена и сервисы, объявленные устройствами локальной сети")
                if config.interfaceName != nil {
                    Text("Bonjour доступен при автоматическом выборе интерфейса.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Порты", text: $portsDraft, prompt: Text("22, 80, 443, 8000-8010"))
                            .monospaced().focused($portsFocused).onSubmit(applyPorts)
                        Button("Применить", action: applyPorts)
                            .disabled(portsDraft == portsText)
                    }
                    if let error = portsError {
                        Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.orange).font(.caption)
                    } else {
                        Text(portsSaved ? "Список портов сохранён" : "Числа или диапазоны через запятую. Изменения применяются кнопкой или Enter.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text("Скорость")
                    Spacer()
                    Button("Бережно") { applyPreset(hosts: 16, connections: 32, timeout: 1.5) }
                    Button("Обычно") { applyPreset(hosts: 64, connections: 128, timeout: 0.8) }
                    Button("Быстро") { applyPreset(hosts: 128, connections: 256, timeout: 0.5) }
                }
                Stepper(value: $config.timeout, in: 0.2...10.0, step: 0.1) {
                    Text("Ожидание ответа: \(config.timeout, specifier: "%.1f") с")
                }
                Stepper(value: $config.concurrencyLimit, in: 1...128) {
                    Text("Одновременных хостов: \(config.concurrencyLimit)")
                }
                Stepper(value: $config.maxConnections, in: 1...512) {
                    Text("Всего TCP-соединений: \(config.maxConnections)")
                }
                Text("Для радиомоста или нестабильной сети выберите бережный режим: больше времени на ответ и меньше одновременных проверок.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .disabled(appState.isScanning)

            Section("Производители устройств") {
                Toggle("Определять производителя по MAC", isOn: $config.vendorLookupEnabled)
                LabeledContent("Записей в базе", value: "\(appState.vendorDatabaseCount)")
                HStack {
                    Button { appState.updateOUIDatabase() } label: {
                        Label(appState.isUpdatingOUIDatabase ? "Обновление базы…" : "Обновить базу IEEE", systemImage: "arrow.down.circle")
                    }.disabled(appState.isUpdatingOUIDatabase)
                    if appState.isUpdatingOUIDatabase { ProgressView().controlSize(.small) }
                }
                if !appState.ouiStatusMessage.isEmpty {
                    Text(appState.ouiStatusMessage).font(.caption).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Section("Внешний вид") {
                Picker("Тема", selection: $config.theme) {
                    ForEach(AppTheme.allCases) { theme in Text(theme.title).tag(theme) }
                }.pickerStyle(.segmented)
                Text("Анимация учитывает системные настройки уменьшения движения. Столбцы настраиваются кнопкой над таблицей.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Локальная сеть") {
                HStack {
                    Text(config.ipRange).monospaced().foregroundStyle(.secondary)
                    Spacer()
                    Button(action: appState.useDetectedRange) {
                        Label("Определить подсеть", systemImage: "location")
                    }.disabled(appState.isScanning)
                }
                Text("Диапазон определяется по выбранному интерфейсу и его маске сети.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 470, idealWidth: 620, maxWidth: 720, maxHeight: .infinity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { portsDraft = portsText }
        .onChange(of: config.ports) { _, _ in
            if !portsFocused { portsDraft = portsText }
        }
        .onChange(of: portsDraft) { _, _ in portsError = nil; portsSaved = false }
    }

    private var portsText: String { config.ports.map(String.init).joined(separator: ", ") }

    private func applyPorts() {
        do {
            config.ports = try PortListParser.validate(portsDraft)
            portsDraft = portsText
            portsError = nil
            portsSaved = true
        } catch {
            portsError = error.localizedDescription
        }
    }

    private func applyPreset(hosts: Int, connections: Int, timeout: Double) {
        config.concurrencyLimit = hosts
        config.maxConnections = connections
        config.timeout = timeout
    }
}
