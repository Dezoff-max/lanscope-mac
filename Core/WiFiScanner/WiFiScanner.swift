import CoreWLAN
import Foundation

enum WiFiScanError: LocalizedError {
    case noInterface
    case poweredOff(interfaceName: String)
    case scanUnavailable

    var errorDescription: String? {
        switch self {
        case .noInterface:
            return "Интерфейс Wi-Fi не найден"
        case .poweredOff(let interfaceName):
            return "Wi-Fi выключен на \(interfaceName)"
        case .scanUnavailable:
            return "macOS не вернула результаты Wi-Fi вовремя"
        }
    }
}

final class WiFiScanner {
    private static let queue = DispatchQueue(label: "LanScope.WiFi.scan", qos: .utility)

    func scan(includeHidden: Bool = true) async throws -> WiFiScanResult {
        let completion = WiFiCompletion()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                completion.install(continuation)
                Self.queue.async {
                    guard !completion.isFinished else { return }
                    do { completion.finish(.success(try Self.performScan(includeHidden: includeHidden))) }
                    catch { completion.finish(.failure(error)) }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 25) {
                    completion.finish(.failure(WiFiScanError.scanUnavailable))
                }
            }
        } onCancel: { completion.finish(.failure(CancellationError())) }
    }

    private static func performScan(includeHidden: Bool) throws -> WiFiScanResult {
        let client = CWWiFiClient.shared()
        let interface = (client.interfaces() ?? []).first(where: { $0.powerOn() }) ?? client.interface()
        guard let interface else { throw WiFiScanError.noInterface }
        let name = interface.interfaceName ?? "Wi-Fi"
        guard interface.powerOn() else { throw WiFiScanError.poweredOff(interfaceName: name) }
        let results = try interface.scanForNetworks(withName: nil, includeHidden: includeHidden)
        let date = Date()
        let networks = results.map { makeNetwork(from: $0, scannedAt: date) }.sorted { $0.rssi > $1.rssi }
        return WiFiScanResult(interfaceName: name, networks: networks, scannedAt: date,
                              currentBSSID: interface.bssid(), currentSSID: interface.ssid())
    }

    private static func makeNetwork(from network: CWNetwork, scannedAt: Date) -> WiFiNetwork {
        let channel = network.wlanChannel
        let bssid = network.bssid ?? "-"
        let ssid = network.ssid ?? ""

        return WiFiNetwork(
            ssid: ssid,
            bssid: bssid,
            rssi: network.rssiValue,
            noise: network.noiseMeasurement == 0 ? nil : network.noiseMeasurement,
            channel: channel?.channelNumber,
            band: channel.map { bandDescription($0.channelBand) } ?? "Unknown",
            channelWidth: channel.map { widthDescription($0.channelWidth) } ?? "Unknown",
            security: securityDescription(for: network),
            phyModes: phyModes(for: network),
            lastSeen: scannedAt
        )
    }

    private static func securityDescription(for network: CWNetwork) -> String {
        if network.supportsSecurity(.wpa3Transition) {
            return "WPA3/WPA2"
        }
        if network.supportsSecurity(.wpa3Personal) {
            return "WPA3 Personal"
        }
        if network.supportsSecurity(.wpa3Enterprise) {
            return "WPA3 Enterprise"
        }
        if network.supportsSecurity(.wpa2Personal) {
            return "WPA2 Personal"
        }
        if network.supportsSecurity(.wpa2Enterprise) {
            return "WPA2 Enterprise"
        }
        if network.supportsSecurity(.wpaPersonal) || network.supportsSecurity(.wpaPersonalMixed) {
            return "WPA Personal"
        }
        if network.supportsSecurity(.wpaEnterprise) || network.supportsSecurity(.wpaEnterpriseMixed) {
            return "WPA Enterprise"
        }
        if let owe = CWSecurity(rawValue: 14), network.supportsSecurity(owe) {
            return "OWE"
        }
        if let oweTransition = CWSecurity(rawValue: 15), network.supportsSecurity(oweTransition) {
            return "OWE Transition"
        }
        if network.supportsSecurity(.WEP) {
            return "WEP"
        }
        if network.supportsSecurity(.dynamicWEP) {
            return "Dynamic WEP"
        }
        if network.supportsSecurity(.none) {
            return "Open"
        }
        return "Unknown"
    }

    private static func phyModes(for network: CWNetwork) -> [String] {
        let candidates: [(CWPHYMode?, String)] = [
            (CWPHYMode(rawValue: 7), "802.11be"),
            (.mode11ax, "802.11ax"),
            (.mode11ac, "802.11ac"),
            (.mode11n, "802.11n"),
            (.mode11g, "802.11g"),
            (.mode11a, "802.11a"),
            (.mode11b, "802.11b")
        ]

        return candidates
            .compactMap { mode, label in
                guard let mode, network.supportsPHYMode(mode) else { return nil }
                return label
            }
    }

    private static func bandDescription(_ band: CWChannelBand) -> String {
        switch band {
        case .band2GHz:
            return "2.4 GHz"
        case .band5GHz:
            return "5 GHz"
        case .band6GHz:
            return "6 GHz"
        default:
            return "Unknown"
        }
    }

    private static func widthDescription(_ width: CWChannelWidth) -> String {
        switch width {
        case .width20MHz:
            return "20 MHz"
        case .width40MHz:
            return "40 MHz"
        case .width80MHz:
            return "80 MHz"
        case .width160MHz:
            return "160 MHz"
        default:
            return "Unknown"
        }
    }
}

// Cancellation ends the caller's wait; CoreWLAN's synchronous scan may finish later.
private final class WiFiCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<WiFiScanResult, Error>?
    private var continuation: CheckedContinuation<WiFiScanResult, Error>?
    var isFinished: Bool { lock.lock(); defer { lock.unlock() }; return result != nil }
    func install(_ value: CheckedContinuation<WiFiScanResult, Error>) {
        lock.lock()
        if let result { lock.unlock(); value.resume(with: result) }
        else { continuation = value; lock.unlock() }
    }
    func finish(_ value: Result<WiFiScanResult, Error>) {
        lock.lock()
        guard result == nil else { lock.unlock(); return }
        result = value; let pending = continuation; continuation = nil
        lock.unlock(); pending?.resume(with: value)
    }
}
