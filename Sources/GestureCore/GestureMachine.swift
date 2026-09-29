import Foundation

public enum MouseButton: Equatable {
    case left, right, middle, button4, button5, other(Int)
    public init(cgNumber: Int) {
        switch cgNumber {
        case 0: self = .left
        case 1: self = .right
        case 2: self = .middle
        case 3: self = .button4
        case 4: self = .button5
        default: self = .other(cgNumber)
        }
    }
    public var name: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .middle: return "Middle"
        case .button4: return "Button4"
        case .button5: return "Button5"
        case .other(let number): return "Button(cg=\(number))"
        }
    }
}

public struct GestureConfig {
    public var deadZone = 8.0
    public var pixelsPerProgress = 600.0
    public var invert = false
    public var verticalEnabled = false
    public var completionProgress = 0.35
    public var flickVelocity = 1.2 // native progress / second; experimental calibration
    public init() {}
}

public enum GesturePhase: UInt32 { case began = 1, changed = 2, ended = 4, cancelled = 8 }
public enum GestureState: String { case idle, buttonHeld, detectingAxis, horizontal, vertical, rejectedVertical, ending }
public struct GestureFrame: Equatable {
    public let phase: GesturePhase
    public let progress: Double
    public let velocity: Double
    public init(_ phase: GesturePhase, _ progress: Double, _ velocity: Double = 0) {
        self.phase = phase; self.progress = progress; self.velocity = velocity
    }
}

public struct VelocityTracker {
    private var samples: [(time: Double, position: Double)] = []
    public init() {}
    public mutating func add(time: Double, position: Double) {
        if let last = samples.last, time <= last.time { return }
        samples.append((time, position))
        // Keep a time window and a fixed upper bound, even with adversarial timestamps.
        samples.removeAll { time - $0.time > 0.1 }
        if samples.count > 24 { samples.removeFirst(samples.count - 24) }
    }
    public func velocity(at time: Double) -> Double {
        guard let last = samples.last, let first = samples.first,
              time - last.time <= 0.075, time >= last.time,
              last.time - first.time > 0.001 else { return 0 }
        return (last.position - first.position) / (last.time - first.time)
    }
}

// Pure state machine. Only the engine's serial queue calls it. No OS APIs or timers.
public struct GestureMachine {
    public let config: GestureConfig
    public private(set) var state = GestureState.idle
    public private(set) var totalX = 0.0
    public private(set) var totalY = 0.0
    public private(set) var rawEvents = 0
    public private(set) var emittedEvents = 0
    public private(set) var startTime = 0.0
    private var pending = false
    private var lastMotionTime = 0.0
    private var tracker = VelocityTracker()
    public var progress: Double { totalX / max(1, config.pixelsPerProgress) * (config.invert ? 1 : -1) }
    public var active: Bool { state != .idle }

    public init(config: GestureConfig = GestureConfig()) { self.config = config }
    public mutating func down(at time: Double) {
        guard !active else { return }
        totalX = 0; totalY = 0; rawEvents = 0; emittedEvents = 0
        startTime = time; lastMotionTime = time; pending = false
        tracker = VelocityTracker(); tracker.add(time: time, position: 0)
        state = .buttonHeld
    }
    public mutating func move(dx: Double, dy: Double, at time: Double, count: Int = 1) {
        guard active, dx.isFinite, dy.isFinite, time.isFinite else { return }
        totalX += dx; totalY += dy; rawEvents += count
        if dx != 0 || dy != 0 { lastMotionTime = time; pending = true }
        if state == .buttonHeld { state = .detectingAxis }
    }
    public mutating func frame(at time: Double) -> [GestureFrame] {
        guard active, pending else { return [] }
        pending = false
        tracker.add(time: lastMotionTime, position: progress)
        if state == .buttonHeld || state == .detectingAxis {
            guard hypot(totalX, totalY) >= max(0, config.deadZone) else { return [] }
            guard abs(totalX) > abs(totalY) else {
                state = config.verticalEnabled ? .vertical : .rejectedVertical
                return []
            }
            state = .horizontal
            emittedEvents += 1
            return [GestureFrame(.began, progress)]
        }
        guard state == .horizontal else { return [] }
        emittedEvents += 1
        return [GestureFrame(.changed, progress, tracker.velocity(at: time))]
    }
    public mutating func finish(at time: Double, cancel: Bool = false) -> [GestureFrame] {
        guard active else { return [] }
        // Final unflushed delta is carried by the terminal event; never throw it away.
        var result: [GestureFrame] = []
        if state != .horizontal && !cancel { result = frame(at: time) }
        if state == .horizontal {
            if pending { tracker.add(time: lastMotionTime, position: progress) }
            let velocity = tracker.velocity(at: time)
            let reversing = abs(velocity) > 0.15 && velocity * progress < 0
            let complete = !reversing && (abs(progress) >= config.completionProgress ||
                (abs(velocity) >= config.flickVelocity && velocity * progress > 0))
            state = .ending
            result.append(GestureFrame(cancel || !complete ? .cancelled : .ended,
                                       progress, cancel ? 0 : velocity))
            emittedEvents += 1
        }
        state = .idle; pending = false
        return result
    }
}
