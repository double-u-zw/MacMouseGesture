// Main-thread lifecycle intent, separate from whether the input hook is running.
// A consumed start is never retried in a loop; failures still require intervention.
struct AutoStartState {
    enum Suspension: Hashable { case sleep, inactiveSession, screenSleep }
    private(set) var wantsHorizontal = true
    private(set) var pendingStart = true
    private var deviceRecoveryTimes: [Double] = []
    private var suspensions: Set<Suspension> = []

    mutating func requestStart() { wantsHorizontal = true; pendingStart = true }
    mutating func requestRestartIfEnabled() { if wantsHorizontal { pendingStart = true } }
    // A real removal notification may request one bounded restart. Generic failures
    // still require intervention; disabled/suspended/unauthorized states stay safe.
    @discardableResult mutating func inputDeviceRemoved(at time: Double) -> Bool {
        guard wantsHorizontal else { return false }
        deviceRecoveryTimes.removeAll { time - $0 >= 60 }
        guard deviceRecoveryTimes.count < 3 else { return false }
        deviceRecoveryTimes.append(time)
        pendingStart = true
        return true
    }
    mutating func stop() { wantsHorizontal = false; pendingStart = false }
    mutating func suspend(_ reason: Suspension) {
        suspensions.insert(reason)
        if wantsHorizontal { pendingStart = true }
    }
    mutating func resume(_ reason: Suspension) { suspensions.remove(reason) }
    mutating func takeStartIfReady(permissionGranted: Bool) -> Bool {
        guard wantsHorizontal, pendingStart, suspensions.isEmpty, permissionGranted else { return false }
        pendingStart = false
        return true
    }
}
