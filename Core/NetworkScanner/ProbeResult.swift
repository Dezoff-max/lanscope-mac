import Foundation

/// Bridges callback APIs to structured tasks without losing cancellation before startup.
final class ProbeResult<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Never>?
    private var result: Value?
    private var finished = false
    private var cleanup: (() -> Void)?

    init(cleanup: @escaping () -> Void = {}) { self.cleanup = cleanup }

    func install(_ continuation: CheckedContinuation<Value, Never>) {
        lock.lock()
        if finished {
            let result = self.result!
            lock.unlock()
            continuation.resume(returning: result)
        } else {
            self.continuation = continuation
            lock.unlock()
        }
    }

    /// The operation must not invoke finish synchronously.
    func start(_ operation: () throws -> Void) rethrows {
        lock.lock()
        defer { lock.unlock() }
        if !finished { try operation() }
    }

    func finish(_ value: Value) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        result = value
        let continuation = self.continuation
        self.continuation = nil
        let cleanup = self.cleanup
        self.cleanup = nil
        lock.unlock()
        cleanup?()
        continuation?.resume(returning: value)
    }
}
