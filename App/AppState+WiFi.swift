import Foundation

extension AppState {
    func startWiFiScan() {
        guard !isWiFiScanning else { return }
        selectedSection = .wifi; isWiFiScanning = true
        let scanID = UUID(); wifiScanID = scanID
        wifiStatusMessage = "Запрашиваем доступ к именам Wi-Fi…"
        wifiScanTask = Task { [weak self] in
            guard let self else { return }
            let permission = wifiLocationPermission ?? WiFiLocationPermission()
            wifiLocationPermission = permission
            let status = await permission.requestAuthorizationIfNeeded()
            guard !Task.isCancelled, wifiScanID == scanID else { return }
            let restricted = status == .denied || status == .restricted || status == .notDetermined
            wifiStatusMessage = "Обновляем сети Wi-Fi; предыдущие данные остаются видимыми…"
            do {
                let result = try await wifiScanner.scan()
                guard !Task.isCancelled, wifiScanID == scanID else { return }
                wifiNetworks = result.networks.map { var n = $0; n.namesRestricted = restricted; return n }
                wifiInterfaceName = result.interfaceName; wifiScannedAt = result.scannedAt
                currentWiFiBSSID = result.currentBSSID; currentWiFiSSID = result.currentSSID
                selectedWiFiNetworkIDs.formIntersection(Set(wifiNetworks.map(\.id)))
                for network in wifiNetworks where network.bssid != "-" && !network.bssid.isEmpty {
                    var samples = wifiSignalHistory[network.id] ?? []
                    samples.append(WiFiSignalSample(date: result.scannedAt, rssi: network.rssi))
                    wifiSignalHistory[network.id] = Array(samples.suffix(120))
                }
                let cutoff = Date().addingTimeInterval(-3600)
                wifiSignalHistory = wifiSignalHistory.filter { $0.value.last.map { $0.date >= cutoff } ?? false }
                wifiStatusMessage = restricted ? "Имена могут быть скрыты macOS. Разрешите геолокацию для LanScope в настройках системы." : "Обновлено \(result.scannedAt.formatted(date: .omitted, time: .shortened)) · сетей: \(result.networks.count)"
            } catch is CancellationError { if wifiScanID == scanID { wifiStatusMessage = "Ожидание остановлено; сохранены предыдущие результаты" } }
            catch { if wifiScanID == scanID { wifiStatusMessage = "Ошибка Wi-Fi: \(error.localizedDescription)"; notify(wifiStatusMessage) } }
            if wifiScanID == scanID { isWiFiScanning = false; wifiScanTask = nil }
        }
    }
    func stopWiFiScan() {
        wifiScanTask?.cancel(); wifiLocationPermission?.cancelPendingRequest()
        wifiScanID = nil; isWiFiScanning = false; wifiScanTask = nil
        wifiStatusMessage = "Ожидание остановлено; предыдущие результаты сохранены"
    }
    func copyWiFiSSID(_ network: WiFiNetwork) { DeviceActionService.copy(network.displaySSID); notify("SSID скопирован") }
    func copyWiFiBSSID(_ network: WiFiNetwork) {
        guard network.bssid != "-" else { return }
        DeviceActionService.copy(network.bssid); notify("BSSID скопирован")
    }
}
