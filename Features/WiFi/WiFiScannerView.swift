import SwiftUI
import Charts

struct WiFiScannerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var grouped = false
    @State private var showCharts = true
    @State private var band = "2.4 GHz"
    @State private var sortOrder = [KeyPathComparator<WiFiNetwork>(\.signalSortValue, order: .reverse)]

    private var networks: [WiFiNetwork] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = appState.wifiNetworks.filter {
            query.isEmpty || [$0.displaySSID, $0.bssid, $0.security, $0.band].joined(separator: " ").localizedCaseInsensitiveContains(query)
        }
        if grouped {
            result = Dictionary(grouping: result, by: { $0.ssid.isEmpty ? $0.id : $0.ssid }).compactMap { $0.value.max(by: { $0.rssi < $1.rssi }) }
        }
        return result.sorted(using: sortOrder)
    }
    private var selected: WiFiNetwork? { appState.wifiNetworks.first { appState.selectedWiFiNetworkIDs.contains($0.id) } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Label(appState.currentWiFiSSID.map { "Подключено: \($0)" } ?? "Ближайшие сети", systemImage: "wifi")
                    .lineLimit(1)
                Spacer()
                Toggle("По SSID", isOn: $grouped).toggleStyle(.checkbox)
                    .help("Показывать наиболее сильную точку каждого SSID")
                Button { showCharts.toggle() } label: { Label("Графики", systemImage: "chart.xyaxis.line") }
                Menu {
                    Button("Экспорт CSV") { export(false) }
                    Button("Экспорт JSON") { export(true) }
                } label: { Label("Экспорт", systemImage: "square.and.arrow.up") }
                .fixedSize(horizontal: true, vertical: false)
                .disabled(networks.isEmpty)
            }
            .font(.callout).padding(12).background { ChromeSurface() }
            Divider()
            if appState.wifiNetworks.isEmpty {
                RadarEmptyStateView(isScanning: appState.isWiFiScanning, idleTitle: "Сети Wi-Fi", scanningTitle: "Обновляем сети", idleSystemImage: "wifi", scanningSystemImage: "wifi", idleMessage: "Нажмите «Сканировать», чтобы увидеть точки доступа и их сигналы", scanningMessage: "Системное сканирование Wi-Fi может занять несколько секунд")
            } else if networks.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                table
                if showCharts {
                    Divider()
                    HStack(alignment: .top, spacing: 20) {
                        channelChart.frame(maxWidth: .infinity)
                        signalChart.frame(maxWidth: .infinity)
                    }.padding(16).frame(height: 235)
                }
            }
            Divider()
            ScanStatusBar(message: appState.wifiStatusMessage, isScanning: appState.isWiFiScanning, count: appState.wifiNetworks.count, noun: "сетей")
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Имя, BSSID или диапазон")
    }

    private var table: some View {
        Table(networks, selection: $appState.selectedWiFiNetworkIDs, sortOrder: $sortOrder) {
            TableColumn("Сеть", value: \.ssidSortValue) { network in
                HStack(spacing: 8) {
                    Image(systemName: isCurrent(network) ? "wifi.circle.fill" : "wifi")
                        .foregroundStyle(isCurrent(network) ? Color.accentColor : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(network.displaySSID).fontWeight(.medium).lineLimit(1)
                        Text(network.bssid == "-" ? "BSSID недоступен" : network.bssid).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }.contextMenu {
                    Button("Скопировать SSID") { appState.copyWiFiSSID(network) }
                    Button("Скопировать BSSID") { appState.copyWiFiBSSID(network) }.disabled(network.bssid == "-")
                }.help(network.displaySSID)
            }.width(min: 180, ideal: 235)
            TableColumn("Сигнал", value: \.signalSortValue) { network in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(network.rssi) dBm").monospacedDigit()
                    Text(network.signalQuality).font(.caption).foregroundStyle(.secondary)
                }
            }.width(86)
            TableColumn("Защита", value: \.securitySortValue) { Text($0.security).lineLimit(1) }.width(min: 100, ideal: 140)
            TableColumn("Канал", value: \.channelSortValue) { Text($0.channelDisplay) }.width(52)
            TableColumn("Диапазон", value: \.bandSortValue) { Text($0.band) }.width(76)
            TableColumn("Ширина", value: \.channelWidth) { Text($0.channelWidth) }.width(68)
            TableColumn("SNR") { network in Text(network.snr.map { "\($0) dB" } ?? "—").foregroundStyle(.secondary) }.width(58)
        }
    }
    private var channelChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Перекрытие каналов").font(.subheadline.weight(.semibold))
                Spacer()
                Picker("Диапазон", selection: $band) { ForEach(["2.4 GHz", "5 GHz", "6 GHz"], id: \.self) { Text($0).tag($0) } }.labelsHidden().frame(width: 110)
            }
            let plotted = appState.wifiNetworks.filter { $0.band == band && $0.centerFrequency != nil }
            if plotted.isEmpty { Text("Нет данных для выбранного диапазона").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity) }
            else {
                Chart(plotted) { network in
                    RectangleMark(xStart: .value("МГц", (network.centerFrequency ?? 0) - network.widthMHz / 2), xEnd: .value("МГц", (network.centerFrequency ?? 0) + network.widthMHz / 2), yStart: .value("dBm", -100), yEnd: .value("dBm", network.rssi))
                        .foregroundStyle(by: .value("Сеть", network.displaySSID)).opacity(0.28)
                }.chartYScale(domain: -100 ... -20).chartLegend(.hidden)
                    .chartXAxisLabel("МГц").chartYAxisLabel("dBm")
            }
            Text("Номинальные каналы; центр широких каналов приблизителен. Это не измерение загрузки эфира.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
    private var signalChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selected.map { "Сигнал: \($0.displaySSID)" } ?? "История сигнала").font(.subheadline.weight(.semibold)).lineLimit(1)
            if let selected, let samples = appState.wifiSignalHistory[selected.id], !samples.isEmpty {
                Chart(samples) { sample in
                    LineMark(x: .value("Время", sample.date), y: .value("RSSI", sample.rssi)).foregroundStyle(Color.accentColor)
                    PointMark(x: .value("Время", sample.date), y: .value("RSSI", sample.rssi)).symbolSize(20)
                }.chartYScale(domain: -100 ... -20).chartYAxisLabel("dBm")
                Text("Точки добавляются после каждого скана · до 120 измерений").font(.caption2).foregroundStyle(.secondary)
            } else {
                Text(selected?.bssid == "-" ? "Без BSSID нельзя надёжно сопоставить сеть между сканами" : "Выберите сеть. Повторите сканирование, чтобы сравнить сигнал во времени.")
                    .font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    private func isCurrent(_ network: WiFiNetwork) -> Bool { network.bssid != "-" && network.bssid.lowercased() == appState.currentWiFiBSSID?.lowercased() }
    private func export(_ json: Bool) {
        do { if try WiFiExportService.save(networks, asJSON: json) { appState.notify("Результаты Wi-Fi сохранены") } }
        catch { appState.notify("Ошибка экспорта: \(error.localizedDescription)") }
    }
}
