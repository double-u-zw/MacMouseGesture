import Foundation
import GestureCore

// Observes the existing machine; owns no motion accumulator or second threshold.
// A threshold crossing is sticky, including rejected axes and cancelled gestures.
struct SideButtonClickTracker {
    enum State { case pendingClick, gestureStarted }
    private(set) var states: [Int: State] = [:]
    mutating func down(_ button: Int, machine: GestureMachine) {
        guard states[button] == nil else { return }
        states[button] = states.values.contains(.gestureStarted) || crossed(machine) ? .gestureStarted : .pendingClick
    }
    mutating func observe(_ machine: GestureMachine) {
        guard crossed(machine) else { return }
        for button in states.keys { states[button] = .gestureStarted }
    }
    mutating func up(_ button: Int) -> Bool {
        states.removeValue(forKey: button) == .pendingClick
    }
    mutating func reset() { states.removeAll() }
    private func crossed(_ machine: GestureMachine) -> Bool {
        guard machine.active else { return false }
        return [.horizontal, .vertical, .rejectedVertical, .ending].contains(machine.state) ||
            hypot(machine.totalX, machine.totalY) >= max(0, machine.config.deadZone)
    }
}
