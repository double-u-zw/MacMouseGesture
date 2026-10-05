import GestureCore

// Short-only buttons observe the SAME machine/deadZone, without driving Bridge.
// Legacy drag buttons retain their original machine/tracker/timer path.
struct StandaloneShortPressTracker {
    private struct Pending {
        var machine: GestureMachine
        var clicks = SideButtonClickTracker()
    }
    private var pending: [Int: Pending] = [:]
    var isActive: Bool { !pending.isEmpty }
    var dragStartedButtons: Set<Int> {
        Set(pending.compactMap { number, state in state.clicks.states[number] == .gestureStarted ? number : nil })
    }
    var oldestStart: Double? { pending.values.map { $0.machine.startTime }.min() }
    mutating func down(_ number: Int, at time: Double, config: GestureConfig, sharedMachine: GestureMachine? = nil) {
        guard pending[number] == nil else { return }
        var p = Pending(machine: GestureMachine(config: config))
        p.machine.down(at: time); p.clicks.down(number, machine: sharedMachine ?? p.machine)
        pending[number] = p
    }
    mutating func observeShared(_ machine: GestureMachine) {
        for number in Array(pending.keys) { pending[number]!.clicks.observe(machine) }
    }
    mutating func move(dx: Double, dy: Double, at time: Double, count: Int) {
        for number in Array(pending.keys) {
            pending[number]!.machine.move(dx: dx, dy: dy, at: time, count: count)
            pending[number]!.clicks.observe(pending[number]!.machine)
        }
    }
    mutating func up(_ number: Int) -> Bool {
        guard var p = pending.removeValue(forKey: number) else { return false }
        p.clicks.observe(p.machine)
        return p.clicks.up(number)
    }
    mutating func reset() { pending.removeAll() }
}
