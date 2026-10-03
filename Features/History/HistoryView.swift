import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isConfirmingClearHistory = false
    @State private var isShowingComparison = false

    private var profileHistory: [ScanHistory] {
        appState.history.filter { $0.profileID == appState.config.profileID }
    }

    var body: some View {
        Group {
            if profileHistory.isEmpty {
                ContentUnavailableView(
                    "История пока пуста",
                    systemImage: "clock",
                    description: Text("Здесь сохраняются результаты сканирований, в том числе прерванных.")
                )
            } else {
                HSplitView {
                    historyList
                        .frame(minWidth: 210, idealWidth: 250, maxWidth: 320)

                    if let selectedHistory = appState.selectedHistory {
                        VStack(spacing: 0) {
                            historyHeader(selectedHistory)
                            Divider()
                            DeviceListControls()
                            Divider()

                            if selectedHistory.devices.isEmpty {
                                ContentUnavailableView(
                                    "Устройства не обнаружены",
                                    systemImage: "network",
                                    description: Text("В этом сканировании нет сохранённых устройств.")
                                )
                            } else if appState.filteredDevices.isEmpty {
                                FilterEmptyState()
                            } else {
                                DeviceTableView(devices: appState.filteredDevices, selection: $appState.selectedDeviceIDs)
                            }
                        }
                        .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
                        .sheet(isPresented: $isShowingComparison) {
                            HistoryComparisonView(current: selectedHistory, candidates: comparisonCandidates(for: selectedHistory))
                        }
                    }
                }
                .onAppear {
                    if !profileHistory.contains(where: { $0.id == appState.selectedHistoryID }) {
                        appState.selectedHistoryID = profileHistory.first?.id
                    }
                }
            }
        }
        .searchable(text: $appState.searchText, placement: .toolbar, prompt: "Поиск устройств")
        .confirmationDialog(
            "Очистить историю этого профиля?",
            isPresented: $isConfirmingClearHistory,
            titleVisibility: .visible
        ) {
            Button("Очистить историю", role: .destructive) {
                appState.clearHistory()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Сканы текущего профиля будут удалены. Избранное и текущие результаты сохранятся.")
        }
    }

    private var historyList: some View {
        VStack(spacing: 0) {
            HStack {
                Label("История", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()
                Button(role: .destructive) {
                    isConfirmingClearHistory = true
                } label: {
                    Label("Очистить историю", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .labelStyle(.iconOnly)
                .help("Очистить сохранённую историю сканирований")
            }
            .padding(12)
            .background { ChromeSurface() }

            Divider()

            List(selection: $appState.selectedHistoryID) {
                ForEach(profileHistory) { entry in
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(DateFormatter.lanScopeDateTime.string(from: entry.startedAt))
                                .lineLimit(1)
                            Text("\(entry.ipRange) · \(entry.foundDevices)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } icon: {
                        Image(systemName: historySymbol(entry))
                            .foregroundStyle(entry.isComplete ? Color.secondary : Color.orange)
                    }
                    .padding(.vertical, 3)
                    .help("\(historyTitle(entry)) · устройств: \(entry.foundDevices)")
                    .tag(entry.id)
                }
            }
            .listStyle(.sidebar)
        }
    }

    private func historyHeader(_ entry: ScanHistory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Label(entry.ipRange, systemImage: "network")
                    .font(.headline)
                Spacer(minLength: 8)
                Button {
                    isShowingComparison = true
                } label: {
                    Label("Сравнить", systemImage: "arrow.left.arrow.right")
                }
                .disabled(comparisonCandidates(for: entry).isEmpty)
                .help(comparisonCandidates(for: entry).isEmpty
                    ? "Нужен более ранний скан этого профиля и диапазона"
                    : "Сравнить с предыдущим сканированием этой сети")
            }

            HStack(spacing: 12) {
                Label(historyTitle(entry), systemImage: historySymbol(entry))
                    .foregroundStyle(entry.isComplete ? Color.secondary : Color.orange)
                Text(String(format: "%.1f с", entry.duration))
                Text("Проверено: \(entry.completedHosts) из \(entry.totalHosts)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !entry.isComplete {
                Text("Результаты неполные: отсутствие устройства в этом списке не означает, что оно недоступно.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let error = entry.errorMessage, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background { ChromeSurface() }
    }

    private func comparisonCandidates(for entry: ScanHistory) -> [ScanHistory] {
        appState.history.filter {
            $0.id != entry.id && $0.startedAt < entry.startedAt &&
                $0.profileID == entry.profileID && $0.ipRange == entry.ipRange
        }
        .sorted { $0.startedAt > $1.startedAt }
    }

    private func historySymbol(_ entry: ScanHistory) -> String {
        switch entry.outcome {
        case .completed: entry.isComplete ? "checkmark.circle" : "questionmark.circle"
        case .cancelled: "stop.circle"
        case .failed: "exclamationmark.circle"
        }
    }

    private func historyTitle(_ entry: ScanHistory) -> String {
        entry.outcome == .completed && !entry.isComplete ? "Полнота не подтверждена" : entry.outcome.title
    }
}

private struct HistoryComparisonView: View {
    let current: ScanHistory
    let candidates: [ScanHistory]
    @Environment(\.dismiss) private var dismiss
    @State private var previousID: ScanHistory.ID?

    init(current: ScanHistory, candidates: [ScanHistory]) {
        self.current = current
        self.candidates = candidates
        _previousID = State(initialValue: candidates.first?.id)
    }

    private var previous: ScanHistory? {
        candidates.first { $0.id == previousID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Сравнение сканирований").font(.title2.weight(.semibold))
                    Text("\(current.ipRange) · \(DateFormatter.lanScopeDateTime.string(from: current.startedAt))")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Готово") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            Picker("Предыдущий скан", selection: $previousID) {
                ForEach(candidates) { entry in
                    Text("\(DateFormatter.lanScopeDateTime.string(from: entry.startedAt)) · \(entry.outcome.title)")
                        .tag(Optional(entry.id))
                }
            }
            .pickerStyle(.menu)

            if let previous {
                comparisonContent(ScanComparison(previous: previous, current: current))
            } else {
                ContentUnavailableView("Нет предыдущего скана", systemImage: "clock")
            }
        }
        .padding(20)
        .frame(minWidth: 580, idealWidth: 680, minHeight: 400, idealHeight: 520)
    }

    @ViewBuilder
    private func comparisonContent(_ comparison: ScanComparison) -> some View {
        if let explanation = comparison.explanation {
            Label {
                Text(explanation)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "info.circle")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }

        if comparison.isComparable {
            HStack(spacing: 20) {
                comparisonCount("Новые", value: comparison.addedCount, symbol: "plus.circle")
                comparisonCount("Не найдены", value: comparison.missingCount, symbol: "minus.circle")
                comparisonCount("Другой IP", value: comparison.addressChangedCount, symbol: "arrow.left.arrow.right")
                comparisonCount("Сервисы", value: comparison.servicesChangedCount, symbol: "network")
            }
            .padding(.vertical, 4)

            Text("Сравниваются устройства с подтверждённым ответом. Отсутствие ответа не доказывает отключение устройства.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if comparison.changes.isEmpty {
                ContentUnavailableView(
                    "Изменений не обнаружено",
                    systemImage: "checkmark.circle",
                    description: Text("Состав ответивших устройств, их адреса и проверенные сервисы совпадают.")
                )
            } else {
                List(comparison.changes) { change in
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(change.title) · \(change.device.displayName)").fontWeight(.medium)
                            Text(change.detail)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    } icon: {
                        Image(systemName: changeSymbol(change))
                            .foregroundStyle(change.kind == .added ? Color.green : Color.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        } else {
            ContentUnavailableView(
                "Сканы нельзя достоверно сравнить",
                systemImage: "exclamationmark.magnifyingglass",
                description: Text("Выберите другой скан или выполните два полных сканирования с одинаковыми настройками.")
            )
        }
    }

    private func comparisonCount(_ title: String, value: Int, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)").font(.title2.weight(.semibold)).monospacedDigit()
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func changeSymbol(_ change: ScanChange) -> String {
        switch change.kind {
        case .added: "plus.circle"
        case .missing: "minus.circle"
        case .addressChanged: "arrow.left.arrow.right.circle"
        case .servicesChanged: "network"
        }
    }
}
