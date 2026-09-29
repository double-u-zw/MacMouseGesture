import Foundation
import GestureCore

struct EngineUISnapshot {
    var eventTap = "stopped"
    var hidActive = false
    var gestureState = "idle"
    var started = 0
    var completed = 0
    var cancelled = 0
    var open = 0
    var eventTapRestarts = 0
    var postFailures = 0
    var sequenceErrors = 0

    init(eventTap: String = "stopped", hidActive: Bool = false, gestureState: String = "idle",
         started: Int = 0, completed: Int = 0, cancelled: Int = 0, open: Int = 0, eventTapRestarts: Int = 0,
         postFailures: Int = 0, sequenceErrors: Int = 0) {
        self.eventTap = eventTap; self.hidActive = hidActive; self.gestureState = gestureState
        self.started = started; self.completed = completed; self.cancelled = cancelled; self.open = open
        self.eventTapRestarts = eventTapRestarts; self.postFailures = postFailures
        self.sequenceErrors = sequenceErrors
    }
}

// Engine-queue owned; counts refer to frames accepted by the bridge, not Dock
// acknowledgments. Failed terminal delivery remains visible as an orphan.
struct GestureCounters {
    var coalescedFrames = 0
    var gestureBegins = 0
    var gestureChanges = 0
    var gestureEnds = 0
    var gestureCancels = 0
    var eventTapRestarts = 0
    var eventTapRecoveryAttempts = 0
    var postFailures = 0
    var sequenceErrors = 0
    private(set) var openGestures = 0
    mutating func record(_ frame: GestureFrame) {
        switch frame.phase {
        case .began:
            if openGestures != 0 { sequenceErrors += 1 }
            gestureBegins += 1; openGestures += 1; coalescedFrames += 1
        case .changed:
            if openGestures != 1 { sequenceErrors += 1 }
            gestureChanges += 1; coalescedFrames += 1
        case .ended, .cancelled:
            if openGestures != 1 { sequenceErrors += 1 }
            openGestures -= 1
            if frame.phase == .ended { gestureEnds += 1 } else { gestureCancels += 1 }
        }
    }
    var summary: String {
        "coalescedFrames=\(coalescedFrames); gestureBegins=\(gestureBegins); gestureChanges=\(gestureChanges); gestureEnds=\(gestureEnds); gestureCancels=\(gestureCancels)\n" +
        "Balance: started=\(gestureBegins), ended+cancelled=\(gestureEnds + gestureCancels), open=\(openGestures), sequenceErrors=\(sequenceErrors), postFailures=\(postFailures)\n" +
        "eventTapRestarts=\(eventTapRestarts); recoveryAttempts=\(eventTapRecoveryAttempts) (automatic only; counters span manual engine restarts)"
    }
}

struct TapRecoveryBudget {
    private var attempts: [Double] = []
    mutating func take(at time: Double) -> Bool {
        attempts.removeAll { time - $0 >= 60 }
        guard attempts.count < 3 else { return false }
        attempts.append(time); return true
    }
}

struct InputCounters {
    var rawMouseEvents = 0
    var button4Downs = 0
    var button5Downs = 0
    var lastMouseAt: Double?
    var lastSideButtonAt: Double?
    mutating func add(_ other: InputCounters) {
        rawMouseEvents += other.rawMouseEvents
        button4Downs += other.button4Downs; button5Downs += other.button5Downs
        lastMouseAt = other.lastMouseAt ?? lastMouseAt
        lastSideButtonAt = other.lastSideButtonAt ?? lastSideButtonAt
    }
    func summary(at now: Double) -> String {
        func age(_ time: Double?) -> String { time.map { String(format: "%.1fs ago", max(0, now - $0)) } ?? "none" }
        return "rawMouseEvents=\(rawMouseEvents) (mouse callbacks, all buttons/motion/scroll); Button4Downs=\(button4Downs); Button5Downs=\(button5Downs)\n" +
            "Last mouse=\(age(lastMouseAt)); last configured side button=\(age(lastSideButtonAt))"
    }
}
