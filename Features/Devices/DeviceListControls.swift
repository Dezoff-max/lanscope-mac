import SwiftUI

/// One source of filtering for the table and for the export commands.
struct DeviceListControls: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 14) {
            metric("Найдено", value: appState.visibleDevices.count, color: .primary)
            metric("Ответили", value: appState.visibleDevices.filter { $0.status == .online }.count, color: .green)
            metric("Новые", value: appState.visibleDevices.filter { appState.newDeviceIDs.contains($0.id) }.count, color: .accentColor)
            Spacer(minLength: 8)
            Menu {
                filterButton("Все устройства", value: .all)
                filterButton("Новые", value: .new)
                filterButton("Избранные", value: .favorites)
                filterButton("С веб-интерфейсом", value: .web)
                filterButton("Ответили", value: .online)
                filterButton("Без подтверждения", value: .unconfirmed)
            } label: { Label(filterTitle, systemImage: "line.3.horizontal.decrease.circle") }
                .fixedSize(horizontal: true, vertical: false)
                .help("Фильтр списка")
            if #available(macOS 14.4, *) { DeviceColumnsMenu() }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background { ChromeSurface() }
        .accessibilityElement(children: .contain)
    }

    private var filterTitle: String {
        switch appState.filter {
        case .all: return "Все"
        case .new: return "Новые"
        case .favorites: return "Избранные"
        case .web: return "Веб"
        case .online: return "Ответили"
        case .unconfirmed: return "Без ответа"
        }
    }
    private func filterButton(_ title: String, value: DeviceFilter) -> some View {
        Button { appState.filter = value } label: {
            if appState.filter == value { Label(title, systemImage: "checkmark") }
            else { Text(title) }
        }
    }
    private func metric(_ title: String, value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(String(value)).fontWeight(.semibold).foregroundStyle(color).monospacedDigit()
            Text(title).foregroundStyle(.secondary)
        }.font(.caption)
    }
}

struct DeviceColumnsMenu: View {
    @AppStorage("deviceColumnMAC") private var showMAC = false
    @AppStorage("deviceColumnVendor") private var showVendor = true
    @AppStorage("deviceColumnPorts") private var showPorts = false
    @AppStorage("deviceColumnServices") private var showServices = false
    @AppStorage("deviceColumnSeen") private var showSeen = false

    var body: some View {
        Menu {
            Text("Столбцы таблицы")
            Toggle("MAC-адрес", isOn: $showMAC)
            Toggle("Производитель", isOn: $showVendor)
            Toggle("Порты", isOn: $showPorts)
            Toggle("Сервисы", isOn: $showServices)
            Toggle("Время обнаружения", isOn: $showSeen)
            Divider()
            Button("Компактный вид") {
                showMAC = false; showVendor = true; showPorts = false; showServices = false; showSeen = false
            }
            Button("Все столбцы") {
                showMAC = true; showVendor = true; showPorts = true; showServices = true; showSeen = true
            }
        } label: { Label("Столбцы", systemImage: "rectangle.split.3x1") }
            .labelStyle(.titleAndIcon)
            .fixedSize(horizontal: true, vertical: false)
            .help("Выбрать столбцы таблицы")
    }
}

struct FilterEmptyState: View {
    @EnvironmentObject private var appState: AppState
    var body: some View {
        ContentUnavailableView {
            Label("Нет совпадений", systemImage: "line.3.horizontal.decrease.circle")
        } description: {
            Text("Измените поисковый запрос или сбросьте фильтр.")
        } actions: {
            Button("Сбросить поиск и фильтр") { appState.searchText = ""; appState.filter = .all }
        }
    }
}
