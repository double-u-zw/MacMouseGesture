import AppKit
import ApplicationServices
import GestureCore

enum ActionExecutionResult: String {
    case success, unsupported, permissionDenied, noFrontmostApplication, noFocusedWindow
    case systemFeatureUnavailable, eventPostFailed, unknownFailure, cancelled
}

// A click-only trajectory. The existing physical gesture tracker and Bridge are
// reused without changing their parameters, axis selection or completion rules.
struct MissionControlPulse {
    static let duration = 0.2
    static let interval = 1.0 / 120
    private let startedAt: Double
    private var tracker = VerticalGestureTracker()
    private(set) var finished = false
    var progress: Double { tracker.progress }
    init(at time: Double) {
        startedAt = time
        tracker.down(at: time)
    }
    mutating func advance(at time: Double) -> [GestureFrame] {
        guard !finished, time.isFinite, time >= startedAt else { return [] }
        let elapsed = time - startedAt
        let target = max(progress, max(0.02, min(1, elapsed / Self.duration)))
        tracker.move(totalY: -tracker.pixelsPerProgress * target, at: time)
        if elapsed >= Self.duration {
            finished = true
            return tracker.finish(verticalLocked: true, at: time)
        }
        return tracker.frame(verticalLocked: true, at: time)
    }
    mutating func cancel(at time: Double) -> [GestureFrame] {
        guard !finished else { return [] }
        finished = true
        return tracker.finish(verticalLocked: true, at: time, cancel: true)
    }
}

// All methods run on the owning engine queue. Tests drive the same advance()
// manually with an injected clock; production uses actual 120 Hz timer delivery.
final class MissionControlAction {
    private let queue: DispatchQueue
    private let clock: () -> Double
    private let permissionGranted: () -> Bool
    private let verticalAvailable: () -> Bool
    private let frontmostApplication: () -> String?
    private let postVertical: (GestureFrame) -> Bool
    private let diagnostic: (String) -> Void
    private let automaticScheduling: Bool
    private var timer: DispatchSourceTimer?
    private var pulse: MissionControlPulse?
    private var context = ""
    private var postedFrames = 0
    private(set) var lastResult: ActionExecutionResult?
    var isRunning: Bool { pulse != nil }

    init(queue: DispatchQueue, clock: @escaping () -> Double = monotonicTime,
         permissionGranted: @escaping () -> Bool = { AXIsProcessTrusted() },
         verticalAvailable: @escaping () -> Bool,
         frontmostApplication: @escaping () -> String? = {
             guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
             return app.bundleIdentifier ?? "pid:\(app.processIdentifier)"
         }, postVertical: @escaping (GestureFrame) -> Bool,
         diagnostic: @escaping (String) -> Void = { _ in }, automaticScheduling: Bool = true) {
        self.queue = queue; self.clock = clock; self.permissionGranted = permissionGranted
        self.verticalAvailable = verticalAvailable; self.frontmostApplication = frontmostApplication
        self.postVertical = postVertical; self.diagnostic = diagnostic; self.automaticScheduling = automaticScheduling
    }

    @discardableResult func start(button: Int? = nil) -> ActionExecutionResult {
        let frontmost = frontmostApplication()
        let request = "[ShortClick] button=\(button.map(String.init) ?? "unspecified") action=missionControl executor=nativeHID-oneShot frontmost=\(frontmost ?? "none")"
        diagnostic("\(request) stage=request")
        func reject(_ result: ActionExecutionResult, _ reason: String) -> ActionExecutionResult {
            // A rejected second request must not change the in-flight sequence.
            if !isRunning { lastResult = result }
            diagnostic("\(request) stage=rejected result=\(result.rawValue) reason=\(reason)")
            return result
        }
        guard !isRunning else { return reject(.unsupported, "one-shot already running") }
        guard permissionGranted() else { return reject(.permissionDenied, "Accessibility unavailable") }
        guard frontmost != nil else { return reject(.noFrontmostApplication, "no active application") }
        guard verticalAvailable() else { return reject(.systemFeatureUnavailable, "macOS vertical HID backend unavailable") }
        let now = clock()
        guard now.isFinite else { return reject(.unknownFailure, "invalid monotonic clock") }
        context = request; postedFrames = 0; lastResult = nil
        pulse = MissionControlPulse(at: now)
        advance()
        guard isRunning else { return lastResult ?? .unknownFailure }
        if automaticScheduling {
            let source = DispatchSource.makeTimerSource(queue: queue)
            source.schedule(deadline: .now() + MissionControlPulse.interval,
                            repeating: MissionControlPulse.interval, leeway: .microseconds(300))
            source.setEventHandler { [weak self] in self?.advance() }
            timer = source; source.resume()
        }
        diagnostic("\(context) stage=scheduled duration=\(MissionControlPulse.duration)s")
        // Accepted for asynchronous execution; only stage=complete reports success.
        return .success
    }

    func advance() {
        guard var current = pulse else { return }
        guard permissionGranted() else { cancel(reason: "Accessibility permission lost", result: .permissionDenied); return }
        let now = clock()
        guard now.isFinite else { cancel(reason: "invalid monotonic clock", result: .unknownFailure); return }
        let frames = current.advance(at: now)
        pulse = current
        for frame in frames {
            guard postVertical(frame) else {
                let cleanup = postVertical(GestureFrame(.cancelled, frame.progress))
                complete(.eventPostFailed, reason: "HID phase=\(frame.phase.rawValue) failed; cancellationSubmitted=\(cleanup)")
                return
            }
            postedFrames += 1
        }
        if current.finished {
            complete(.success, reason: "HID sequence submitted; Dock response requires real-device acceptance")
        }
    }

    func cancel(reason: String, result: ActionExecutionResult = .cancelled) {
        guard var current = pulse else { return }
        var cleanup = true
        for frame in current.cancel(at: clock()) { if !postVertical(frame) { cleanup = false } }
        complete(result, reason: "\(reason); cancellationSubmitted=\(cleanup)")
    }
    private func complete(_ result: ActionExecutionResult, reason: String) {
        timer?.cancel(); timer = nil; pulse = nil; lastResult = result
        diagnostic("\(context) stage=complete result=\(result.rawValue) postedFrames=\(postedFrames) reason=\(reason)")
    }
}
