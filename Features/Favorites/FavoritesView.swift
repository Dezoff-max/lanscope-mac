import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""

    private var filteredFavorites: [Device] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return appState.favorites
        }
        return appState.favorites.filter { device in
            [
                device.displayName,
                device.ipAddress,
                device.macAddress ?? "",
                device.vendor,
                device.servicesDisplay
            ]
            .joined(separator: " ")
            .localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if filteredFavorites.isEmpty {
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "star",
                    description: Text("Add devices from scan results or sample data.")
                )
            } else {
                DeviceTableView(devices: filteredFavorites, selection: $appState.selectedDeviceIDs)
                    .safeAreaInset(edge: .bottom) {
                        HStack {
                            Spacer()
                            Button(role: .destructive) {
                                if let device = appState.selectedDevice {
                                    appState.removeFavorite(device)
                                }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .disabled(appState.selectedDevice == nil)
                        }
                        .padding(10)
                        .background(.bar)
                    }
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search favorites")
    }
}
