import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isConfirmingClearHistory = false

    var body: some View {
        if appState.history.isEmpty {
            ContentUnavailableView(
                "No History",
                systemImage: "clock",
                description: Text("Completed scans appear here.")
            )
        } else {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Label("History", systemImage: "clock.arrow.circlepath")
                            .font(.headline)
                        Spacer()
                        Button(role: .destructive) {
                            isConfirmingClearHistory = true
                        } label: {
                            Label("Clear", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .help("Clear saved scan history.")
                    }
                    .padding(12)
                    .background(.bar)

                    Divider()

                    List(selection: $appState.selectedHistoryID) {
                        ForEach(appState.history) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(DateFormatter.lanScopeDateTime.string(from: entry.startedAt))
                                    .lineLimit(1)
                                HStack {
                                    Text(entry.ipRange)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(entry.foundDevices)")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 3)
                            .tag(entry.id)
                        }
                    }
                }
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 320)

                Divider()

                if let selectedHistory = appState.selectedHistory {
                    VStack(alignment: .leading, spacing: 0) {
                        historyHeader(selectedHistory)
                        Divider()
                        DeviceTableView(devices: selectedHistory.devices, selection: $appState.selectedDeviceIDs)
                    }
                }
            }
            .onAppear {
                appState.selectedHistoryID = appState.selectedHistoryID ?? appState.history.first?.id
            }
            .confirmationDialog(
                "Clear scan history?",
                isPresented: $isConfirmingClearHistory,
                titleVisibility: .visible
            ) {
                Button("Clear History", role: .destructive) {
                    appState.clearHistory()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Favorites and current scan results will stay unchanged.")
            }
        }
    }

    private func historyHeader(_ entry: ScanHistory) -> some View {
        HStack(spacing: 12) {
            Label(entry.ipRange, systemImage: "network")
                .font(.headline)

            Text("\(entry.foundDevices) found")
                .foregroundStyle(.secondary)

            Text(String(format: "%.1fs", entry.duration))
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(entry.totalHosts) host(s)")
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.bar)
    }
}
