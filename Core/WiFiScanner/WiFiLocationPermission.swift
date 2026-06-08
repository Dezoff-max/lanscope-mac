import CoreLocation
import Foundation

@MainActor
final class WiFiLocationPermission: NSObject, CLLocationManagerDelegate {
    private var manager: CLLocationManager?
    private var continuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    func requestAuthorizationIfNeeded() async -> CLAuthorizationStatus {
        let manager = CLLocationManager()
        self.manager = manager
        manager.delegate = self

        let status = manager.authorizationStatus
        guard status == .notDetermined else {
            return status
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard status != .notDetermined else {
                return
            }
            continuation?.resume(returning: status)
            continuation = nil
        }
    }
}
