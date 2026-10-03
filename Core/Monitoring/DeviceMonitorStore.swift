import AppKit
import Combine
import Foundation
import Network
import UserNotifications

struct DeviceMonitorKey: Hashable, Sendable {
    let profileID: UUID?
    let address: String

    init(device: Device) {
        profileID = device.profileID
        address = device.normalizedMAC.map { "mac:\($0)" } ?? "ip:\(device.ipAddress)"
    }
}

/// Explicit, session-only monitoring. Creating the store never starts network probes.
@MainActor
final class DeviceMonitorStore: ObservableObject {
    typealias Probe = @Sendable (String, TimeInterval, String?) async -> PingMeasurement

    @Published private(set) var states: [DeviceMonitorKey: DeviceMonitorSnapshot] = [:]
    @Published private(set) var events: [DeviceMonitorEvent] = []
    @Published private(set) var pauseReason: String?
    @Published private(set) var notificationsEnabled = false
    @Published private(set) var notificationMessage: String?
    @Published var interval: TimeInterval = 5
    @Published var failureThreshold: Int = 3

    var onStatusChange: ((Device, Bool) -> Void)?
    var timeout: TimeInterval = 1

    private struct Target {
        var device: Device
        var interfaceName: String?
    }

    private let probe: Probe
    private let historyDuration: TimeInterval = 300
    private let maximumSamples = 300
    private var targets: [DeviceMonitorKey: Target] = [:]
    private var loops: [DeviceMonitorKey: Task<Void, Never>] = [:]
    private var pending: [DeviceMonitorKey: Task<PingMeasurement, Never>] = [:]
    private var pendingTokens: [DeviceMonitorKey: UUID] = [:]
    private var workspaceObservers: [NSObjectProtocol] = []
    private var pathMonitor: NWPathMonitor?
    private var isSleeping = false
    private var networkAvailable = true

    init(
        observeSystem: Bool = true,
        probe: @escaping Probe = { host, timeout, interface in
            await PingProbe.measure(host: host, timeout: timeout, interfaceName: interface)
        }
    ) {
        self.probe = probe
        if observeSystem { observeSystemAvailability() }
    }

    deinit {
        loops.values.forEach { $0.cancel() }
        pending.values.forEach { $0.cancel() }
        pathMonitor?.cancel()
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { center.removeObserver($0) }
    }

    func snapshot(for device: Device) -> DeviceMonitorSnapshot {
        states[DeviceMonitorKey(device: device)] ?? DeviceMonitorSnapshot()
    }

    func samples(for device: Device) -> [MonitorSample] { snapshot(for: device).samples }

    func isMonitoring(_ device: Device) -> Bool { snapshot(for: device).isMonitoring }

    var monitoredCount: Int { states.values.filter(\.isMonitoring).count }

    func start(device: Device, interfaceName: String? = nil) {
        let key = DeviceMonitorKey(device: device)
        targets[key] = Target(device: device, interfaceName: interfaceName)
        var state = states[key] ?? DeviceMonitorSnapshot()
        state.isMonitoring = true
        states[key] = state
        startLoop(for: key)
    }

    func stop(device: Device) {
        stop(key: DeviceMonitorKey(device: device))
    }

    func stopAll() {
        for key in Array(states.keys) { stop(key: key) }
    }

    /// A profile switch must not continue checking addresses from the previous network.
    func stopOutsideProfile(_ profileID: UUID?) {
        for key in Array(states.keys) where key.profileID != profileID { stop(key: key) }
    }

    /// Refreshes a monitored device's DHCP address and user-visible name after a scan.
    func update(device: Device) {
        let key = DeviceMonitorKey(device: device)
        guard var target = targets[key] else { return }
        target.device = device
        targets[key] = target
    }

    func probeOnce(device: Device, interfaceName: String? = nil) async {
        let key = DeviceMonitorKey(device: device)
        if let previous = targets[key] {
            targets[key] = Target(device: device, interfaceName: interfaceName ?? previous.interfaceName)
        } else {
            targets[key] = Target(device: device, interfaceName: interfaceName)
        }
        await performProbe(for: key)
    }

    func clearHistory(for device: Device) {
        let key = DeviceMonitorKey(device: device)
        guard var state = states[key] else { return }
        state.samples = []
        states[key] = state
    }

    func requestNotifications() async {
        // UNUserNotificationCenter requires an app bundle. CLI/test launches remain usable.
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            notificationMessage = "Системные уведомления доступны в установленном приложении."
            return
        }
        do {
            notificationsEnabled = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            notificationMessage = notificationsEnabled
                ? "Уведомления об изменении доступности включены."
                : "Уведомления выключены. Разрешить их можно в настройках macOS."
        } catch {
            notificationMessage = "Не удалось включить уведомления: \(error.localizedDescription)"
        }
    }

    private func stop(key: DeviceMonitorKey) {
        loops.removeValue(forKey: key)?.cancel()
        cancelPending(for: key)
        guard var state = states[key] else { return }
        state.isMonitoring = false
        state.consecutiveFailures = 0
        states[key] = state
    }

    private func startLoop(for key: DeviceMonitorKey) {
        guard pauseReason == nil, states[key]?.isMonitoring == true, loops[key] == nil else { return }
        loops[key] = Task { [weak self] in
            while !Task.isCancelled {
                guard let delay = await self?.runIteration(for: key) else { return }
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch { return }
            }
        }
    }

    private func runIteration(for key: DeviceMonitorKey) async -> TimeInterval? {
        guard states[key]?.isMonitoring == true, pauseReason == nil else { return nil }
        await performProbe(for: key)
        guard !Task.isCancelled, states[key]?.isMonitoring == true, pauseReason == nil else { return nil }
        return min(60, max(1, interval))
    }

    private func performProbe(for key: DeviceMonitorKey) async {
        guard pauseReason == nil, pending[key] == nil, let target = targets[key], !Task.isCancelled else { return }
        let token = UUID()
        let probe = self.probe
        let timeout = min(10, max(0.2, self.timeout))
        let task = Task { await probe(target.device.ipAddress, timeout, target.interfaceName) }
        pending[key] = task
        pendingTokens[key] = token
        var state = states[key] ?? DeviceMonitorSnapshot()
        state.isProbing = true
        states[key] = state

        let result = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        guard pendingTokens[key] == token else { return }
        pending.removeValue(forKey: key)
        pendingTokens.removeValue(forKey: key)
        guard var current = states[key] else { return }
        current.isProbing = false
        states[key] = current
        guard !Task.isCancelled, !task.isCancelled, pauseReason == nil else { return }
        record(result, for: key, device: targets[key]?.device ?? target.device)
    }

    private func record(_ result: PingMeasurement, for key: DeviceMonitorKey, device: Device) {
        var state = states[key] ?? DeviceMonitorSnapshot()
        let sample = MonitorSample(reachable: result.reachable, latencyMS: result.latencyMS)
        state.append(sample, historyDuration: historyDuration, maximumSamples: maximumSamples)
        let previous = state.confirmedReachable
        if result.reachable {
            state.consecutiveFailures = 0
            state.confirmedReachable = true
        } else {
            state.consecutiveFailures += 1
            if state.consecutiveFailures >= max(1, failureThreshold) {
                state.confirmedReachable = false
            }
        }
        states[key] = state

        // A first successful check is a baseline, not a recovery notification.
        if let current = state.confirmedReachable,
           current != previous,
           !current || previous == false {
            let message = current
                ? "\(device.displayName): ответы на ping восстановились."
                : "\(device.displayName): нет ответа на \(max(1, failureThreshold)) проверки подряд."
            let event = DeviceMonitorEvent(timestamp: sample.timestamp, device: device, reachable: current, message: message)
            events.insert(event, at: 0)
            if events.count > 50 { events.removeLast(events.count - 50) }
            onStatusChange?(device, current)
            notify(event)
        }
    }

    private func cancelPending(for key: DeviceMonitorKey) {
        pending.removeValue(forKey: key)?.cancel()
        pendingTokens.removeValue(forKey: key)
        if var state = states[key] {
            state.isProbing = false
            states[key] = state
        }
    }

    private func notify(_ event: DeviceMonitorEvent) {
        guard notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = event.reachable ? "Связь восстановлена" : "Устройство не отвечает"
        content.body = event.message
        content.sound = .default
        let request = UNNotificationRequest(identifier: event.id.uuidString, content: content, trigger: nil)
        Task { try? await UNUserNotificationCenter.current().add(request) }
    }

    private func observeSystemAvailability() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isSleeping = true
                self?.updatePauseState()
            }
        })
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isSleeping = false
                self?.updatePauseState()
            }
        })
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let available = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.networkAvailable = available
                self?.updatePauseState()
            }
        }
        pathMonitor = monitor
        monitor.start(queue: DispatchQueue(label: "LanScope.monitor-path"))
    }

    private func updatePauseState() {
        let newReason = isSleeping ? "Mac находится в режиме сна" : (networkAvailable ? nil : "Нет подключения к сети")
        guard newReason != pauseReason else { return }
        pauseReason = newReason
        if newReason != nil {
            loops.values.forEach { $0.cancel() }
            loops.removeAll()
            for key in Array(pending.keys) { cancelPending(for: key) }
            for key in Array(states.keys) { states[key]?.consecutiveFailures = 0 }
        } else {
            for key in states.keys where states[key]?.isMonitoring == true { startLoop(for: key) }
        }
    }
}
