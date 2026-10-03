import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var appState: AppState

    private var selectedCount: Int {
        appState.filteredDevices.filter { appState.selectedDeviceIDs.contains($0.id) }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            DeviceListControls()
            Divider()

            if appState.visibleDevices.isEmpty {
                ContentUnavailableView(
                    "Нет избранных устройств",
                    systemImage: "star",
                    description: Text("Добавьте важные устройства в избранное кнопкой со звездой в результатах сканирования.")
                )
            } else if appState.filteredDevices.isEmpty {
                FilterEmptyState()
            } else {
                DeviceTableView(devices: appState.filteredDevices, selection: $appState.selectedDeviceIDs)
            }
        }
        .searchable(text: $appState.searchText, placement: .toolbar, prompt: "Поиск устройств")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 12) {
                if appState.canUndoRemoveFavorites {
                    Label("Устройства удалены из избранного", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                    Button("Отменить") {
                        appState.undoRemoveFavorites()
                    }
                    .help("Вернуть последние удалённые устройства в избранное")
                } else {
                    Text(selectedCount > 0 ? "Выбрано: \(selectedCount)" : "Выберите устройства для удаления")
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Button(role: .destructive) {
                    appState.removeSelectedFavorites()
                } label: {
                    Label("Удалить из избранного", systemImage: "star.slash")
                }
                .disabled(selectedCount == 0)
                .help("Удалить все выбранные устройства из избранного")
            }
            .font(.callout)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background { ChromeSurface() }
        }
    }
}
