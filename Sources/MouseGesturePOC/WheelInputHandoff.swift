import AppKit

extension WheelScrollSample {
    init?(event: CGEvent) {
        // Fail open if AppKit cannot supply inversion metadata. Do not guess from
        // a global preference or use independent CG delta-sign paths elsewhere.
        guard let scroll = NSEvent(cgEvent: event), scroll.type == .scrollWheel else { return nil }
        self.init(delta: Double(scroll.scrollingDeltaY),
                  isContinuous: scroll.hasPreciseScrollingDeltas || event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0,
                  isDirectionInvertedFromDevice: scroll.isDirectionInvertedFromDevice,
                  isMomentum: !scroll.momentumPhase.isEmpty)
    }
}

// Consumption has to be decided before the tap returns. Resolve on the SAME
// engine queue, first draining preceding edges/motion. A late request is revoked,
// so fail-open events cannot claim a press or execute an action later.
final class WheelInputHandoff {
    static let decisionBudget: Double = 0.008
    private let queue: DispatchQueue
    private let prepare: () -> Void
    private let resolve: (WheelScrollSample, Double) -> Bool
    init(queue: DispatchQueue, prepare: @escaping () -> Void, resolve: @escaping (WheelScrollSample, Double) -> Bool) {
        self.queue = queue; self.prepare = prepare; self.resolve = resolve
    }
    func capture(_ sample: WheelScrollSample, at time: Double) -> Bool {
        let request = Request()
        queue.async { [self] in
            guard request.isPending else { return }
            prepare()
            request.complete { resolve(sample, time) }
        }
        _ = request.ready.wait(timeout: .now() + Self.decisionBudget)
        return request.takeOrCancel()
    }
    private final class Request {
        let ready = DispatchSemaphore(value: 0)
        private let lock = NSLock()
        private var pending = true
        private var result = false
        var isPending: Bool { lock.lock(); defer { lock.unlock() }; return pending }
        func complete(_ resolve: () -> Bool) {
            lock.lock()
            if pending { result = resolve(); pending = false }
            lock.unlock(); ready.signal()
        }
        func takeOrCancel() -> Bool {
            lock.lock(); defer { lock.unlock() }
            pending = false; return result
        }
    }
}
