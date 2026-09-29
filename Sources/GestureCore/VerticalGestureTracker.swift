import Foundation

// Phase 1/2 POC. GestureMachine still owns button lifetime, dead zone,
// axis lock, and the unchanged horizontal path. The first locked vertical
// direction chooses one Dock action for the entire gesture.
public enum VerticalGestureAction: String {
    case undecided, missionControl, appExpose
}

public struct VerticalGestureTracker {
    public let pixelsPerProgress: Double
    public let upDeltaSign: Double
    public private(set) var action: VerticalGestureAction = .undecided
    public private(set) var rawY = 0.0
    public private(set) var emittedEvents = 0
    private var lastMotionTime = 0.0
    private var pending = false
    private var began = false
    private var finished = true
    private var tracker = VelocityTracker()

    private var signedProgress: Double { rawY * upDeltaSign / pixelsPerProgress }
    public var progress: Double {
        switch action {
        case .undecided: return 0
        case .missionControl: return max(0, signedProgress)
        case .appExpose: return min(0, signedProgress)
        }
    }
    public var hasOpenGesture: Bool { began && !finished }

    // Both values are experimental and isolated from Build 7 horizontal feel.
    // Verified on this Mac: a physical upward drag reports negative CG deltaY.
    public init(pixelsPerProgress: Double = 300, upDeltaSign: Double = -1) {
        precondition(pixelsPerProgress.isFinite && pixelsPerProgress > 0 &&
                     (upDeltaSign == 1 || upDeltaSign == -1))
        self.pixelsPerProgress = pixelsPerProgress
        self.upDeltaSign = upDeltaSign
    }

    public mutating func down(at time: Double) {
        action = .undecided; rawY = 0; emittedEvents = 0
        lastMotionTime = time; pending = false; began = false; finished = false
        tracker = VelocityTracker(); tracker.add(time: time, position: 0)
    }

    public mutating func move(totalY: Double, at time: Double) {
        guard !finished, totalY.isFinite, time.isFinite else { return }
        if totalY != rawY { rawY = totalY; lastMotionTime = time; pending = true }
    }

    public mutating func frame(verticalLocked: Bool, at time: Double) -> [GestureFrame] {
        guard !finished, verticalLocked, pending else { return [] }
        pending = false
        if action == .undecided {
            guard signedProgress != 0 else { return [] }
            action = signedProgress > 0 ? .missionControl : .appExpose
        }
        tracker.add(time: lastMotionTime, position: progress)
        emittedEvents += 1
        if !began {
            began = true
            return [GestureFrame(.began, progress)]
        }
        return [GestureFrame(.changed, progress, tracker.velocity(at: time))]
    }

    public mutating func finish(verticalLocked: Bool, at time: Double, cancel: Bool = false) -> [GestureFrame] {
        guard !finished else { return [] }
        // Cancellation never starts a gesture that has not yet been posted.
        var result = cancel ? [] : frame(verticalLocked: verticalLocked, at: time)
        if began {
            let velocity = tracker.velocity(at: time)
            let outward = action == .missionControl ? velocity : -velocity
            let reversing = outward < -0.15
            let complete = !reversing && (abs(progress) >= 0.55 ||
                (outward >= 1.2 && progress != 0))
            result.append(GestureFrame(cancel || !complete ? .cancelled : .ended,
                                       progress, cancel ? 0 : velocity))
            emittedEvents += 1
        }
        finished = true; began = false; pending = false
        return result
    }
}
