import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var selectedSection: SidebarSection? = .scan {
        didSet { if oldValue != selectedSection { selectedDeviceIDs = []; selectedWiFiNetworkIDs = []; searchText = ""; filter = .all } }
    }
    @Published var selectedDeviceIDs: Set<Device.ID> = []
    @Published var selectedWiFiNetworkIDs: Set<WiFiNetwork.ID> = []
    @Published var selectedHistoryID: ScanHistory.ID? {
        didSet { if currentSection == .history && oldValue != selectedHistoryID { selectedDeviceIDs = [] } }
    }
    @Published var devices: [Device] = []
    @Published var wifiNetworks: [WiFiNetwork] = []
    @Published var favorites: [Device] = []
    @Published var history: [ScanHistory] = []
    @Published var profiles: [NetworkProfile] = []
    @Published var availableInterfaces: [NetworkInterfaceInfo] = []
    @Published var searchText = ""
    @Published var filter: DeviceFilter = .all
    @Published var newDeviceIDs: Set<UUID> = []
    @Published var notificationMessage: String?
    @Published var config: ScannerConfig {
        didSet {
            persistence.saveConfig(config.normalized())
            if let index = profiles.firstIndex(where: { $0.id == config.profileID }) {
                profiles[index].config = config.normalized()
                persistence.saveProfiles(profiles)
            }
        }
    }
    @Published var progress: Double = 0
    @Published var completedHosts = 0
    @Published var isScanning = false
    @Published var hasScanned = false
    @Published var scanError: String?
    @Published var isWiFiScanning = false
    @Published var isUpdatingOUIDatabase = false
    @Published var vendorDatabaseCount: Int
    @Published var statusMessage = "Готово к сканированию"
    @Published var ouiStatusMessage = "Локальная база производителей"
    @Published var wifiStatusMessage = "Готово к сканированию"
    @Published var wifiInterfaceName: String?
    @Published var currentWiFiBSSID: String?
    @Published var currentWiFiSSID: String?
    @Published var wifiScannedAt: Date?
    @Published var wifiSignalHistory: [String: [WiFiSignalSample]] = [:]
    @Published var canUndoRemoveFavorites = false
    let monitor = DeviceMonitorStore()

    let persistence: UserDefaultsStore
    let scanner: NetworkScanner
    let wifiScanner: WiFiScanner
    var deviceMetadata: [Device] = []
    var removedFavorites: [Device] = []
    var wifiLocationPermission: WiFiLocationPermission?
    var scanTask: Task<Void, Never>?
    var wifiScanTask: Task<Void, Never>?
    var wifiScanID: UUID?
    var noticeTask: Task<Void, Never>?
    var currentScanDevices: [Device] = []
    var currentScanStartedAt: Date?
    var currentScanTotalHosts = 0
    var currentScanConfig: ScannerConfig?
    var currentScanRecord: ScanHistory?
    var baselineDevices: [Device] = []
    var recheckingIDs: Set<UUID> = []

    init(persistence: UserDefaultsStore = .shared, scanner: NetworkScanner = NetworkScanner(), wifiScanner: WiFiScanner = WiFiScanner()) {
        self.persistence = persistence
        self.scanner = scanner
        self.wifiScanner = wifiScanner
        var loadedConfig = persistence.loadConfig().normalized()
        if loadedConfig.ipRange.isEmpty { loadedConfig.ipRange = LocalNetworkInfo.suggestedRange() ?? ScannerConfig.defaultRange }
        var savedProfiles = persistence.loadProfiles()
        if savedProfiles.isEmpty {
            var profile = NetworkProfile(name: "Основная сеть", config: loadedConfig)
            loadedConfig.profileID = profile.id
            profile.config = loadedConfig
            savedProfiles = [profile]
        } else if !savedProfiles.contains(where: { $0.id == loadedConfig.profileID }) {
            loadedConfig = savedProfiles[0].config
            loadedConfig.profileID = savedProfiles[0].id
        }
        self.config = loadedConfig
        self.profiles = savedProfiles
        let legacyProfileID = savedProfiles[0].id
        self.favorites = persistence.loadFavorites().map { var d = $0; if d.profileID == nil { d.profileID = legacyProfileID }; return d }
        self.history = persistence.loadHistory().map { entry in
            var entry = entry
            if entry.profileID == nil { entry.profileID = legacyProfileID }
            entry.devices = entry.devices.map { var d = $0; if d.profileID == nil { d.profileID = entry.profileID }; return d }
            return entry
        }
        self.deviceMetadata = persistence.loadDeviceMetadata().map { var d = $0; if d.profileID == nil { d.profileID = legacyProfileID }; return d }
        self.vendorDatabaseCount = scanner.vendorDatabaseCount
        self.availableInterfaces = LocalNetworkInfo.interfaces()
        persistence.saveConfig(loadedConfig)
        persistence.saveProfiles(savedProfiles)
        if let warning = persistence.warning { notificationMessage = warning }
        monitor.onStatusChange = { [weak self] device, online in
            self?.notify("\(device.displayName): \(online ? "связь восстановлена" : "не отвечает после нескольких проверок")")
        }
    }

    var currentSection: SidebarSection { selectedSection ?? .scan }
    var activeProfileID: UUID? { config.profileID }
    var selectedDevice: Device? {
        guard selectedDeviceIDs.count == 1, let id = selectedDeviceIDs.first else { return nil }
        return visibleDevices.first { $0.id == id }
    }
    var visibleDevices: [Device] {
        switch currentSection {
        case .scan: return devices
        case .wifi, .settings: return []
        case .favorites: return favorites.filter { $0.profileID == config.profileID }
        case .history:
            return (selectedHistory?.devices ?? []).map { device in
                var displayed = device
                displayed.isFavorite = favorites.contains { recordsMatch($0, device) }
                return displayed
            }
        }
    }
    var filteredDevices: [Device] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return visibleDevices.filter { device in
            let matchesQuery = query.isEmpty || [device.displayName, device.hostname, device.ipAddress, device.macAddress ?? "", device.vendor, device.servicesDisplay, device.notes, device.tags.joined(separator: " ")].joined(separator: " ").localizedCaseInsensitiveContains(query)
            return matchesQuery && filter.includes(device, newIDs: newDeviceIDs)
        }
    }
    var exportableSelection: [Device] {
        let selected = filteredDevices.filter { selectedDeviceIDs.contains($0.id) }
        return selected.isEmpty ? filteredDevices : selected
    }
    var selectedHistory: ScanHistory? {
        let scoped = history.filter { $0.profileID == config.profileID }
        return scoped.first { $0.id == selectedHistoryID } ?? scoped.first
    }

    func startScan() {
        guard !isScanning else { return }
        let snapshot = config.normalized()
        do { _ = try IPRangeParser.hosts(in: snapshot.ipRange) }
        catch { scanError = error.localizedDescription; statusMessage = error.localizedDescription; notify(statusMessage); return }
        config = snapshot
        currentScanConfig = snapshot
        currentScanRecord = nil
        baselineDevices = history.first { $0.profileID == snapshot.profileID && $0.ipRange == snapshot.ipRange && $0.isComplete }?.devices ?? []
        selectedSection = .scan
        currentScanDevices = []; devices = []; selectedDeviceIDs = []; newDeviceIDs = []
        currentScanStartedAt = Date(); currentScanTotalHosts = 0; completedHosts = 0
        progress = 0; isScanning = true; hasScanned = true; scanError = nil
        statusMessage = "Сканирование \(snapshot.ipRange)…"
        scanTask = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await scanner.scan(config: snapshot) { [weak self] in self?.handleScanEvent($0) }
                finishScan(outcome: .completed)
            } catch is CancellationError { finishScan(outcome: .cancelled) }
            catch { finishScan(outcome: .failed, error: error.localizedDescription) }
        }
    }

    func stopScan() {
        guard isScanning else { return }
        statusMessage = "Остановка проверок…"
        scanTask?.cancel()
    }

    func handleScanEvent(_ event: ScanProgressEvent) {
        switch event {
        case .started(let total):
            currentScanTotalHosts = total; completedHosts = 0; progress = 0
            statusMessage = "Проверяем адреса: \(total)"
        case .hostFinished(let completed, let total):
            completedHosts = completed; progress = total == 0 ? 0 : Double(completed) / Double(total)
            statusMessage = "Проверено \(completed) из \(total) адресов"
        case .deviceFound(let device, let completed, let total):
            let enriched = decorate(device)
            if let index = currentScanDevices.firstIndex(where: { $0.ipAddress == device.ipAddress }) { currentScanDevices[index] = enriched }
            else { currentScanDevices.append(enriched) }
            devices = currentScanDevices.sorted { IPAddressSorter.compare($0.ipAddress, $1.ipAddress) }
            completedHosts = completed; progress = total == 0 ? 0 : Double(completed) / Double(total)
            statusMessage = "Проверено \(completed) из \(total) · найдено \(devices.count)"
        case .completed(let found, let total):
            currentScanTotalHosts = total; completedHosts = total
            currentScanDevices = found.map(decorate).sorted { IPAddressSorter.compare($0.ipAddress, $1.ipAddress) }
            devices = currentScanDevices; progress = 1
            for device in devices { monitor.update(device: device) }
            newDeviceIDs = Set(devices.filter { device in device.status == .online && !baselineDevices.contains { $0.matches(device) } }.map(\.id))
        }
    }

    func decorate(_ device: Device) -> Device {
        var result = device
        if result.profileID == nil { result.profileID = currentScanConfig?.profileID ?? config.profileID }
        if let metadata = deviceMetadata.first(where: { recordsMatch($0, result) }) {
            result.customName = metadata.customName; result.kind = metadata.kind; result.notes = metadata.notes; result.tags = metadata.tags
        }
        if let index = favorites.firstIndex(where: { recordsMatch($0, result) }) {
            result.isFavorite = true
            if result.customName.isEmpty { result.customName = favorites[index].customName; result.kind = favorites[index].kind; result.notes = favorites[index].notes; result.tags = favorites[index].tags }
            var refreshed = result; refreshed.id = favorites[index].id
            if refreshed.confirmedAt == nil { refreshed.confirmedAt = favorites[index].confirmedAt }
            favorites[index] = refreshed
        }
        return result
    }

    func finishScan(outcome: ScanOutcome, error: String? = nil) {
        let snapshot = currentScanConfig ?? config
        if let startedAt = currentScanStartedAt, currentScanTotalHosts > 0 {
            let entry = ScanHistory(startedAt: startedAt, finishedAt: Date(), ipRange: snapshot.ipRange, totalHosts: currentScanTotalHosts, foundDevices: currentScanDevices.count, devices: currentScanDevices, outcome: outcome, completedHosts: completedHosts, errorMessage: error, profileID: snapshot.profileID, config: snapshot)
            currentScanRecord = entry
            history.insert(entry, at: 0)
            history = Array(history.prefix(100))
            persistence.saveHistory(history)
        }
        persistence.saveFavorites(favorites)
        isScanning = false; scanTask = nil; currentScanStartedAt = nil
        scanError = error
        switch outcome {
        case .completed: statusMessage = "Готово · найдено \(devices.count), новых \(newDeviceIDs.count)"
        case .cancelled: statusMessage = "Остановлено · проверено \(completedHosts) из \(currentScanTotalHosts)"
        case .failed: statusMessage = "Ошибка: \(error ?? "не удалось завершить сканирование")"
        }
        notify(statusMessage)
    }

    func recordsMatch(_ lhs: Device, _ rhs: Device) -> Bool {
        guard lhs.profileID == rhs.profileID else { return false }
        if lhs.id == rhs.id { return true }
        switch (lhs.normalizedMAC, rhs.normalizedMAC) {
        case let (a?, b?): return a == b
        case (nil, nil): return lhs.ipAddress == rhs.ipAddress
        default: return false
        }
    }

    func notify(_ message: String) {
        noticeTask?.cancel(); notificationMessage = message
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.notificationMessage = nil
        }
    }
}
