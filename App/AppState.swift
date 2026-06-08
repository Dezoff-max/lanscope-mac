import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var selectedSection: SidebarSection? = .scan {
        didSet {
            if oldValue != selectedSection {
                selectedDeviceIDs = []
                selectedWiFiNetworkIDs = []
            }
        }
    }
    @Published var selectedDeviceIDs: Set<Device.ID> = []
    @Published var selectedWiFiNetworkIDs: Set<WiFiNetwork.ID> = []
    @Published var selectedHistoryID: ScanHistory.ID? {
        didSet {
            if oldValue != selectedHistoryID {
                selectedDeviceIDs = []
            }
        }
    }
    @Published var devices: [Device] = []
    @Published var wifiNetworks: [WiFiNetwork] = []
    @Published var favorites: [Device] = []
    @Published var history: [ScanHistory] = []
    @Published var config: ScannerConfig {
        didSet {
            persistence.saveConfig(config.normalized())
        }
    }
    @Published var progress: Double = 0
    @Published var isScanning = false
    @Published var isWiFiScanning = false
    @Published var isUpdatingOUIDatabase = false
    @Published var vendorDatabaseCount: Int
    @Published var statusMessage = "Ready"
    @Published var wifiStatusMessage = "Ready"
    @Published var wifiInterfaceName: String?

    private let persistence: UserDefaultsStore
    private let scanner: NetworkScanner
    private let wifiScanner: WiFiScanner
    private var wifiLocationPermission: WiFiLocationPermission?
    private var scanTask: Task<Void, Never>?
    private var wifiScanTask: Task<Void, Never>?
    private var animatedInsertionTask: Task<Void, Never>?
    private var pendingAnimatedDevices: [Device] = []
    private var currentScanDevices: [Device] = []
    private var currentScanStartedAt: Date?
    private var currentScanTotalHosts = 0

    init(
        persistence: UserDefaultsStore = .shared,
        scanner: NetworkScanner = NetworkScanner(),
        wifiScanner: WiFiScanner = WiFiScanner()
    ) {
        self.persistence = persistence
        self.scanner = scanner
        self.wifiScanner = wifiScanner
        var loadedConfig = persistence.loadConfig()
        if loadedConfig.ipRange.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            loadedConfig.ipRange = LocalNetworkInfo.suggestedRange() ?? ScannerConfig.defaultRange
        }
        self.config = loadedConfig.normalized()
        self.favorites = persistence.loadFavorites()
        self.history = persistence.loadHistory()
        self.vendorDatabaseCount = scanner.vendorDatabaseCount
    }

    var currentSection: SidebarSection {
        selectedSection ?? .scan
    }

    var selectedDevice: Device? {
        guard let selectedID = selectedDeviceIDs.first else {
            return nil
        }
        return visibleDevices.first { $0.id == selectedID } ?? allKnownDevices.first { $0.id == selectedID }
    }

    var exportableSelection: [Device] {
        let selected = visibleDevices.filter { selectedDeviceIDs.contains($0.id) }
        return selected.isEmpty ? visibleDevices : selected
    }

    var visibleDevices: [Device] {
        switch currentSection {
        case .scan:
            return devices
        case .wifi:
            return []
        case .favorites:
            return favorites
        case .history:
            return selectedHistory?.devices ?? history.first?.devices ?? []
        case .settings:
            return []
        }
    }

    private var allKnownDevices: [Device] {
        devices + favorites + history.flatMap(\.devices)
    }

    var selectedHistory: ScanHistory? {
        if let selectedHistoryID,
           let selected = history.first(where: { $0.id == selectedHistoryID }) {
            return selected
        }
        return history.first
    }

    func startScan() {
        guard !isScanning else {
            return
        }

        let scanConfig = config.normalized()
        config = scanConfig
        animatedInsertionTask?.cancel()
        animatedInsertionTask = nil
        pendingAnimatedDevices = []
        currentScanDevices = []
        currentScanStartedAt = Date()
        currentScanTotalHosts = 0
        withAnimation(.snappy(duration: 0.22)) {
            devices = []
        }
        selectedDeviceIDs = []
        progress = 0
        isScanning = true
        statusMessage = scanConfig.mockMode ? "Running sample scan..." : "Scanning \(scanConfig.ipRange)..."

        scanTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                _ = try await scanner.scan(config: scanConfig) { [weak self] event in
                    self?.handleScanEvent(event)
                }

                finishScan(status: "Scan complete")
            } catch is CancellationError {
                finishScan(status: "Scan stopped")
            } catch {
                finishScan(status: "Scan failed: \(error.localizedDescription)")
            }
        }
    }

    func stopScan() {
        guard isScanning else {
            return
        }
        statusMessage = "Stopping scan..."
        scanTask?.cancel()
    }

    func startWiFiScan() {
        guard !isWiFiScanning else {
            return
        }

        selectedSection = .wifi
        selectedDeviceIDs = []
        selectedWiFiNetworkIDs = []
        isWiFiScanning = true
        wifiStatusMessage = "Requesting Wi-Fi access..."

        wifiScanTask = Task { [weak self] in
            guard let self else {
                return
            }

            let permissionManager = wifiLocationPermission ?? WiFiLocationPermission()
            wifiLocationPermission = permissionManager
            let authorizationStatus = await permissionManager.requestAuthorizationIfNeeded()
            if authorizationStatus == .denied || authorizationStatus == .restricted {
                wifiStatusMessage = "Location permission is needed to show SSID and BSSID"
            } else {
                wifiStatusMessage = "Scanning nearby Wi-Fi networks..."
            }

            do {
                let result = try await wifiScanner.scan(includeHidden: true)
                withAnimation(.snappy(duration: 0.24)) {
                    self.wifiNetworks = result.networks
                }
                wifiInterfaceName = result.interfaceName
                isWiFiScanning = false
                wifiScanTask = nil
                wifiStatusMessage = result.networks.isEmpty
                    ? "No Wi-Fi networks found"
                    : "Scan complete"
            } catch is CancellationError {
                isWiFiScanning = false
                wifiScanTask = nil
                wifiStatusMessage = "Wi-Fi scan stopped"
            } catch {
                isWiFiScanning = false
                wifiScanTask = nil
                wifiStatusMessage = "Wi-Fi scan failed: \(error.localizedDescription)"
            }
        }
    }

    func useDetectedRange() {
        if let range = LocalNetworkInfo.suggestedRange() {
            config.ipRange = range
            statusMessage = "Detected local range: \(range)"
        } else {
            statusMessage = "Could not detect a local IPv4 range"
        }
    }

    func updateOUIDatabase() {
        guard !isUpdatingOUIDatabase else {
            return
        }

        isUpdatingOUIDatabase = true
        statusMessage = "Updating OUI database..."

        Task {
            do {
                let downloadedCount = try await OUIDatabaseStore.updateFromIEEE()
                let mergedCount = scanner.reloadVendorDatabase()
                vendorDatabaseCount = mergedCount
                statusMessage = "OUI database updated: \(downloadedCount) IEEE records"
            } catch {
                statusMessage = "OUI update failed: \(error.localizedDescription)"
            }
            isUpdatingOUIDatabase = false
        }
    }

    func toggleFavorite(_ device: Device) {
        if let index = favorites.firstIndex(where: { $0.matches(device) }) {
            favorites.remove(at: index)
            updateFavoriteState(for: device, isFavorite: false)
            statusMessage = "Removed \(device.displayName) from favorites"
        } else {
            var favorite = device
            favorite.isFavorite = true
            favorites.insert(favorite, at: 0)
            updateFavoriteState(for: device, isFavorite: true)
            statusMessage = "Added \(device.displayName) to favorites"
        }
        persistence.saveFavorites(favorites)
        persistence.saveHistory(history)
    }

    func removeFavorite(_ device: Device) {
        favorites.removeAll { $0.matches(device) }
        updateFavoriteState(for: device, isFavorite: false)
        persistence.saveFavorites(favorites)
        persistence.saveHistory(history)
        statusMessage = "Removed \(device.displayName) from favorites"
    }

    func clearHistory() {
        history = []
        selectedHistoryID = nil
        selectedDeviceIDs = []
        persistence.saveHistory(history)
        statusMessage = "History cleared"
    }

    func openBrowser(for device: Device) {
        DeviceActionService.openInBrowser(device)
    }

    func connectSSH(to device: Device) {
        DeviceActionService.openSSH(device)
    }

    func openSMB(for device: Device) {
        DeviceActionService.openSMB(device)
    }

    func openVNC(for device: Device) {
        DeviceActionService.openVNC(device)
    }

    func copyIP(_ device: Device) {
        DeviceActionService.copy(device.ipAddress)
        statusMessage = "Copied IP address"
    }

    func copyMAC(_ device: Device) {
        guard let macAddress = device.macAddress else {
            return
        }
        DeviceActionService.copy(macAddress)
        statusMessage = "Copied MAC address"
    }

    func wakeOnLAN(_ device: Device) {
        guard let macAddress = device.macAddress else {
            statusMessage = "Wake-on-LAN needs a MAC address"
            return
        }

        Task {
            do {
                try WakeOnLAN.sendMagicPacket(to: macAddress)
                statusMessage = "Wake-on-LAN packet sent"
            } catch {
                statusMessage = "Wake-on-LAN failed: \(error.localizedDescription)"
            }
        }
    }

    func exportCSV() {
        do {
            try ExportService.saveCSV(devices: exportableSelection)
            statusMessage = "CSV exported"
        } catch {
            statusMessage = "CSV export failed: \(error.localizedDescription)"
        }
    }

    func exportJSON() {
        do {
            try ExportService.saveJSON(devices: exportableSelection)
            statusMessage = "JSON exported"
        } catch {
            statusMessage = "JSON export failed: \(error.localizedDescription)"
        }
    }

    func copySelectedRows() {
        guard !exportableSelection.isEmpty else {
            return
        }
        ExportService.copyTSV(devices: exportableSelection)
        statusMessage = "Copied \(exportableSelection.count) row(s)"
    }

    func copyWiFiSSID(_ network: WiFiNetwork) {
        DeviceActionService.copy(network.displaySSID)
        wifiStatusMessage = "Copied SSID"
    }

    func copyWiFiBSSID(_ network: WiFiNetwork) {
        guard network.bssid != "-" else {
            return
        }
        DeviceActionService.copy(network.bssid)
        wifiStatusMessage = "Copied BSSID"
    }

    private func handleScanEvent(_ event: ScanProgressEvent) {
        switch event {
        case .started(let total):
            currentScanTotalHosts = total
            progress = 0
            statusMessage = "Scanning \(total) host(s)..."

        case .hostFinished(let completed, let total):
            progress = total == 0 ? 0 : Double(completed) / Double(total)
            statusMessage = "Scanned \(completed) of \(total) host(s)"

        case .deviceFound(let device, let completed, let total):
            var resolvedDevice = device
            resolvedDevice.isFavorite = favorites.contains { $0.matches(device) }
            recordCurrentScanDevice(resolvedDevice)
            queueAnimatedDevice(resolvedDevice)
            progress = total == 0 ? 0 : Double(completed) / Double(total)
            statusMessage = "Found \(currentScanDevices.count) device(s)"

        case .completed(let foundDevices, let total):
            currentScanTotalHosts = total
            let favoriteAwareDevices = foundDevices.map { device in
                var updated = device
                updated.isFavorite = favorites.contains { $0.matches(device) }
                return updated
            }
            currentScanDevices = favoriteAwareDevices.sorted { IPAddressSorter.compare($0.ipAddress, $1.ipAddress) }
            for device in currentScanDevices where !hasVisibleOrPendingDevice(ipAddress: device.ipAddress) {
                queueAnimatedDevice(device)
            }
            progress = 1
            statusMessage = "Found \(currentScanDevices.count) device(s)"
        }
    }

    private func finishScan(status: String) {
        let finishedAt = Date()
        let historyDevices = currentScanDevices.isEmpty ? devices : currentScanDevices
        if let startedAt = currentScanStartedAt, !historyDevices.isEmpty || currentScanTotalHosts > 0 {
            let entry = ScanHistory(
                startedAt: startedAt,
                finishedAt: finishedAt,
                ipRange: config.ipRange,
                totalHosts: currentScanTotalHosts,
                foundDevices: historyDevices.count,
                devices: historyDevices
            )
            history.insert(entry, at: 0)
            history = Array(history.prefix(25))
            selectedHistoryID = entry.id
            persistence.saveHistory(history)
        }

        isScanning = false
        scanTask = nil
        statusMessage = status
    }

    private func recordCurrentScanDevice(_ device: Device) {
        if let index = currentScanDevices.firstIndex(where: { $0.ipAddress == device.ipAddress }) {
            currentScanDevices[index] = device
        } else {
            currentScanDevices.append(device)
        }
        currentScanDevices.sort { IPAddressSorter.compare($0.ipAddress, $1.ipAddress) }
    }

    private func queueAnimatedDevice(_ device: Device) {
        guard !hasVisibleOrPendingDevice(ipAddress: device.ipAddress) else {
            return
        }

        pendingAnimatedDevices.append(device)
        startAnimatedInsertionIfNeeded()
    }

    private func hasVisibleOrPendingDevice(ipAddress: String) -> Bool {
        devices.contains { $0.ipAddress == ipAddress }
            || pendingAnimatedDevices.contains { $0.ipAddress == ipAddress }
    }

    private func startAnimatedInsertionIfNeeded() {
        guard animatedInsertionTask == nil else {
            return
        }

        animatedInsertionTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 45_000_000)
                } catch {
                    return
                }

                guard let self else {
                    return
                }

                if !insertNextAnimatedDevice() {
                    animatedInsertionTask = nil
                    return
                }
            }
        }
    }

    private func insertNextAnimatedDevice() -> Bool {
        guard !pendingAnimatedDevices.isEmpty else {
            return false
        }

        let device = pendingAnimatedDevices.removeFirst()
        withAnimation(.snappy(duration: 0.24)) {
            if let index = devices.firstIndex(where: { $0.ipAddress == device.ipAddress }) {
                devices[index] = device
            } else {
                devices.append(device)
            }
            devices.sort { IPAddressSorter.compare($0.ipAddress, $1.ipAddress) }
        }

        if selectedDeviceIDs.isEmpty {
            selectedDeviceIDs = [device.id]
        }

        return !pendingAnimatedDevices.isEmpty
    }

    private func updateFavoriteState(for device: Device, isFavorite: Bool) {
        if let index = devices.firstIndex(where: { $0.matches(device) }) {
            devices[index].isFavorite = isFavorite
        }
        for index in history.indices {
            for deviceIndex in history[index].devices.indices where history[index].devices[deviceIndex].matches(device) {
                history[index].devices[deviceIndex].isFavorite = isFavorite
            }
        }
    }
}
