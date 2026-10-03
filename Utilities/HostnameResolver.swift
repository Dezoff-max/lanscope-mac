import Darwin
import Foundation

protocol HostnameResolving {
    func hostname(for ipAddress: String) async -> String?
}

struct HostnameResolver: HostnameResolving {
    private static let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "LanScopeMac.ReverseDNS"
        queue.qualityOfService = .utility
        // getnameinfo itself cannot be cancelled. Bound background system calls,
        // while every caller has its own deadline and immediate cancellation.
        queue.maxConcurrentOperationCount = 4
        return queue
    }()
    private let timeout: TimeInterval
    private let lookup: @Sendable (String) -> String?

    init(timeout: TimeInterval = 1.2, lookup: @escaping @Sendable (String) -> String? = { HostnameResolver.reverseDNS($0) }) {
        self.timeout = timeout.isFinite ? min(max(timeout, 0.001), 10) : 1.2
        self.lookup = lookup
    }

    func hostname(for ipAddress: String) async -> String? {
        guard !Task.isCancelled else { return nil }
        let operation = BlockOperation()
        let completion = ProbeResult<String?> { operation.cancel() }
        operation.addExecutionBlock { [weak operation] in
            guard operation?.isCancelled == false else { return }
            completion.finish(lookup(ipAddress))
        }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                completion.install(continuation)
                completion.start { Self.queue.addOperation(operation) }
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                    completion.finish(nil)
                }
            }
        } onCancel: { completion.finish(nil) }
    }

    static func reverseDNS(_ ipAddress: String) -> String? {
        var socketAddress = sockaddr_in()
        socketAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        socketAddress.sin_family = sa_family_t(AF_INET)
        guard inet_pton(AF_INET, ipAddress, &socketAddress.sin_addr) == 1 else {
            return nil
        }

        var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = withUnsafePointer(to: &socketAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketPointer in
                getnameinfo(
                    socketPointer,
                    socklen_t(MemoryLayout<sockaddr_in>.size),
                    &hostBuffer,
                    socklen_t(hostBuffer.count),
                    nil,
                    0,
                    NI_NAMEREQD
                )
            }
        }

        guard result == 0 else {
            return nil
        }

        return String(cString: hostBuffer)
    }
}
