import Foundation
import Network

enum PortProbe {
    private static let queue = DispatchQueue(label: "LanScopeMac.PortProbe", qos: .utility, attributes: .concurrent)

    static func isOpen(host: String, port: Int, timeout: TimeInterval, interface: NWInterface? = nil) async -> Bool {
        guard !Task.isCancelled, (1...65535).contains(port),
              let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else { return false }
        let parameters = NWParameters.tcp
        parameters.requiredInterface = interface
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: parameters)
        let completion = ProbeResult<Bool> {
            connection.stateUpdateHandler = nil
            connection.cancel()
        }
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready: completion.finish(true)
            case .failed, .cancelled: completion.finish(false)
            default: break
            }
        }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                completion.install(continuation)
                completion.start { connection.start(queue: queue) }
                let duration = timeout.isFinite ? min(max(timeout, 0.001), 60) : 1
                queue.asyncAfter(deadline: .now() + duration) { completion.finish(false) }
            }
        } onCancel: { completion.finish(false) }
    }

    /// NWInterface has no public name initializer; resolve it once before a scan.
    static func interface(named name: String) async -> NWInterface? {
        guard !Task.isCancelled else { return nil }
        let monitor = NWPathMonitor()
        let completion = ProbeResult<NWInterface?> {
            monitor.pathUpdateHandler = nil
            monitor.cancel()
        }
        monitor.pathUpdateHandler = { path in
            completion.finish(path.availableInterfaces.first { $0.name == name })
        }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                completion.install(continuation)
                completion.start { monitor.start(queue: queue) }
                queue.asyncAfter(deadline: .now() + 1) { completion.finish(nil) }
            }
        } onCancel: { completion.finish(nil) }
    }
}
