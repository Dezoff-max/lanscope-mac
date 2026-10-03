import Foundation

extension AppState {
    func selectProfile(_ id: UUID) {
        guard !isScanning, let profile = profiles.first(where: { $0.id == id }) else { return }
        config = profile.config; config.profileID = id
        monitor.stopOutsideProfile(id)
        devices = []; selectedDeviceIDs = []; selectedHistoryID = nil; newDeviceIDs = []
        currentScanRecord = nil
        hasScanned = false; scanError = nil; searchText = ""; filter = .all; progress = 0
        statusMessage = "Профиль: \(profile.name)"
    }
    func saveProfile(name: String) {
        guard !isScanning else { return }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var profile = NetworkProfile(name: name, config: config)
        profile.config.profileID = profile.id
        profiles.append(profile); persistence.saveProfiles(profiles)
        selectProfile(profile.id); notify("Профиль «\(name)» создан")
    }
    func deleteProfile(_ id: UUID) {
        guard !isScanning, profiles.count > 1 else { return }
        guard !history.contains(where: { $0.profileID == id }),
              !favorites.contains(where: { $0.profileID == id }),
              !deviceMetadata.contains(where: { $0.profileID == id }) else {
            notify("Можно удалить только профиль без сохранённой истории и устройств. Ваши данные сохранены.")
            return
        }
        profiles.removeAll { $0.id == id }; persistence.saveProfiles(profiles)
        if config.profileID == id, let next = profiles.first { selectProfile(next.id) }
        notify("Пустой профиль удалён")
    }
    func selectInterface(_ name: String?) {
        guard !isScanning else { return }
        availableInterfaces = LocalNetworkInfo.interfaces()
        config.interfaceName = name
        if let network = availableInterfaces.first(where: { $0.name == name }) { config.ipRange = network.suggestedRange }
    }
    func useDetectedRange() {
        availableInterfaces = LocalNetworkInfo.interfaces()
        if let selected = availableInterfaces.first(where: { $0.name == config.interfaceName }) { config.ipRange = selected.suggestedRange }
        else if let suggested = LocalNetworkInfo.suggestedRange() { config.ipRange = suggested }
        else { notify("Активная сеть IPv4 не найдена"); return }
        statusMessage = "Диапазон: \(config.ipRange)"
    }
    func updateOUIDatabase() {
        guard !isUpdatingOUIDatabase else { return }
        isUpdatingOUIDatabase = true; ouiStatusMessage = "Обновляем базу IEEE…"
        Task {
            do {
                let count = try await OUIDatabaseStore.updateFromIEEE()
                vendorDatabaseCount = scanner.reloadVendorDatabase()
                ouiStatusMessage = "Обновлено \(Date().formatted(date: .abbreviated, time: .shortened)): \(count) записей"
            } catch { ouiStatusMessage = "Ошибка обновления: \(error.localizedDescription)" }
            isUpdatingOUIDatabase = false; notify(ouiStatusMessage)
        }
    }
    func updateDeviceMetadata(_ device: Device, name: String, kind: DeviceKind, notes: String, tags: [String]) {
        var metadata = device
        metadata.customName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        metadata.kind = kind; metadata.notes = notes
        metadata.tags = Array(Set(tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
        deviceMetadata.removeAll { recordsMatch($0, device) }
        if !metadata.customName.isEmpty || !metadata.notes.isEmpty || !metadata.tags.isEmpty || metadata.kind != .unknown { deviceMetadata.append(metadata) }
        persistence.saveDeviceMetadata(deviceMetadata)
        func updated(_ list: [Device]) -> [Device] {
            list.map { old in
                guard recordsMatch(old, device) else { return old }
                var result = old; result.customName = metadata.customName; result.kind = kind; result.notes = notes; result.tags = metadata.tags
                return result
            }
        }
        devices = updated(devices); currentScanDevices = updated(currentScanDevices); favorites = updated(favorites)
        persistence.saveFavorites(favorites)
        // User labels are annotations; preserve each historical observation's measured fields.
        for index in history.indices { history[index].devices = updated(history[index].devices) }
        persistence.saveHistory(history)
        notify("Карточка устройства сохранена")
    }
    func toggleFavorite(_ device: Device) {
        if favorites.contains(where: { recordsMatch($0, device) }) { removeFavorite(device); return }
        var favorite = device; favorite.isFavorite = true
        favorites.insert(favorite, at: 0); setFavorite(device, value: true)
        persistence.saveFavorites(favorites); notify("\(device.displayName) добавлен в избранное")
    }
    func removeFavorite(_ device: Device) {
        removedFavorites = favorites.filter { recordsMatch($0, device) }; canUndoRemoveFavorites = !removedFavorites.isEmpty
        favorites.removeAll { recordsMatch($0, device) }; setFavorite(device, value: false)
        monitor.stop(device: device)
        persistence.saveFavorites(favorites); notify("Удалено из избранного")
    }
    func removeSelectedFavorites() {
        let targets = filteredDevices.filter { selectedDeviceIDs.contains($0.id) }
        removedFavorites = favorites.filter { d in targets.contains { recordsMatch($0, d) } }
        for target in targets { favorites.removeAll { recordsMatch($0, target) }; setFavorite(target, value: false); monitor.stop(device: target) }
        canUndoRemoveFavorites = !removedFavorites.isEmpty; selectedDeviceIDs = []
        persistence.saveFavorites(favorites); notify("Удалено из избранного: \(removedFavorites.count)")
    }
    func undoRemoveFavorites() {
        for device in removedFavorites where !favorites.contains(where: { recordsMatch($0, device) }) { favorites.append(device); setFavorite(device, value: true) }
        removedFavorites = []; canUndoRemoveFavorites = false
        persistence.saveFavorites(favorites); notify("Избранное восстановлено")
    }
    func setFavorite(_ device: Device, value: Bool) {
        for i in devices.indices where recordsMatch(devices[i], device) { devices[i].isFavorite = value }
        for i in currentScanDevices.indices where recordsMatch(currentScanDevices[i], device) { currentScanDevices[i].isFavorite = value }
    }
    func clearHistory() {
        history.removeAll { $0.profileID == config.profileID }; selectedHistoryID = nil; selectedDeviceIDs = []
        persistence.saveHistory(history); notify("История текущего профиля очищена")
    }
    func recheckDevice(_ device: Device) {
        guard !recheckingIDs.contains(device.id) else { return }
        recheckingIDs.insert(device.id)
        var snapshot = profiles.first(where: { $0.id == device.profileID })?.config ?? config
        snapshot.ipRange = device.ipAddress; snapshot.profileID = device.profileID
        Task {
            defer { recheckingIDs.remove(device.id) }
            do {
                let found = try await scanner.scan(config: snapshot) { _ in }
                applyRecheckResult(found.first, to: device)
            } catch { notify("Проверка не завершена: \(error.localizedDescription)") }
        }
    }
    func applyRecheckResult(_ found: Device?, to device: Device) {
        currentScanRecord = nil
        var refreshed: Device
        let changedMAC = device.normalizedMAC != nil && found?.normalizedMAC != nil && device.normalizedMAC != found?.normalizedMAC
        let missingMAC = device.normalizedMAC != nil && found != nil && found?.normalizedMAC == nil
        if changedMAC || missingMAC {
            refreshed = device
            refreshed.status = .unknown; refreshed.openPorts = []; refreshed.services = []
            refreshed.observationSource = changedMAC ? "IP отвечает с другим MAC-адресом" : "IP отвечает, но MAC не подтверждён"
        } else if var confirmed = found {
            confirmed.id = device.id; refreshed = decorate(confirmed)
        } else {
            refreshed = device; refreshed.status = .offline; refreshed.openPorts = []; refreshed.services = []
            refreshed.observationSource = "Нет ответа на проверенные пробы"
        }
        if let i = devices.firstIndex(where: { $0.id == device.id }) { devices[i] = refreshed }
        if let i = favorites.firstIndex(where: { recordsMatch($0, device) }) {
            var favorite = refreshed; favorite.id = favorites[i].id; favorite.isFavorite = true; favorites[i] = favorite
        }
        persistence.saveFavorites(favorites); monitor.update(device: refreshed)
        notify(changedMAC ? "Адрес \(device.ipAddress) отвечает с другим MAC. Исходное устройство сохранено в избранном." : "\(refreshed.displayName): \(refreshed.status.title)")
    }

    func openBrowser(for device: Device) { DeviceActionService.openInBrowser(device) }
    func connectSSH(to device: Device) { DeviceActionService.openSSH(device) }
    func openSMB(for device: Device) { DeviceActionService.openSMB(device) }
    func openVNC(for device: Device) { DeviceActionService.openVNC(device) }
    func copyIP(_ device: Device) { DeviceActionService.copy(device.ipAddress); notify("IP скопирован") }
    func copyMAC(_ device: Device) {
        guard let mac = device.macAddress else { return }
        DeviceActionService.copy(mac); notify("MAC скопирован")
    }
    func wakeOnLAN(_ device: Device) {
        guard let mac = device.macAddress else { notify("Для пробуждения нужен MAC-адрес"); return }
        do { try WakeOnLAN.sendMagicPacket(to: mac); notify("Пакет Wake-on-LAN отправлен. Пробуждение ещё не подтверждено.") }
        catch { notify("Ошибка Wake-on-LAN: \(error.localizedDescription)") }
    }
    func exportDevices(scope: ExportScope) -> [Device] {
        switch scope {
        case .selected: return filteredDevices.filter { selectedDeviceIDs.contains($0.id) }
        case .filtered: return filteredDevices
        case .all: return visibleDevices
        }
    }
    func exportCSV(scope: ExportScope = .filtered) {
        let rows = exportDevices(scope: scope); guard !rows.isEmpty else { return }
        do { if try ExportService.saveCSV(devices: rows) { notify("CSV сохранён: \(rows.count) устройств") } }
        catch { notify("Ошибка экспорта CSV: \(error.localizedDescription)") }
    }
    func exportJSON(scope: ExportScope = .filtered) {
        let rows = exportDevices(scope: scope); guard !rows.isEmpty else { return }
        let scan = currentSection == .history ? selectedHistory : (currentSection == .scan && !isScanning ? currentScanRecord : nil)
        do { if try ExportService.saveJSON(devices: rows, scan: scan) { notify("JSON сохранён: \(rows.count) устройств") } }
        catch { notify("Ошибка экспорта JSON: \(error.localizedDescription)") }
    }
    func copySelectedRows() {
        let rows = exportDevices(scope: .selected); guard !rows.isEmpty else { return }
        ExportService.copyTSV(devices: rows); notify("Скопировано строк: \(rows.count)")
    }
}
