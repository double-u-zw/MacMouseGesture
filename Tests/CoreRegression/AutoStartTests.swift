final class AutoStartTests {
    func testPermissionGrantStartsOnceAndDoesNotRetryFailures() {
        var state = AutoStartState()
        for _ in 0..<10 { expectFalse(state.takeStartIfReady(permissionGranted: false)) }
        expectTrue(state.takeStartIfReady(permissionGranted: true))
        for _ in 0..<10 { expectFalse(state.takeStartIfReady(permissionGranted: true)) }
        // Revoking and regranting does not silently undo an engine safety stop.
        expectFalse(state.takeStartIfReady(permissionGranted: false))
        expectFalse(state.takeStartIfReady(permissionGranted: true))
        state.requestStart()
        expectTrue(state.takeStartIfReady(permissionGranted: true))
    }
    func testManualStopWhileWaitingForPermissionIsRespected() {
        var state = AutoStartState()
        expectFalse(state.takeStartIfReady(permissionGranted: false))
        state.stop()
        expectFalse(state.takeStartIfReady(permissionGranted: true))
        state.suspend(.sleep); state.resume(.sleep)
        expectFalse(state.takeStartIfReady(permissionGranted: true))
        state.requestStart()
        expectTrue(state.takeStartIfReady(permissionGranted: true))
    }
    func testResumeWaitsForEverySuspensionAndPermission() {
        var state = AutoStartState()
        expectTrue(state.takeStartIfReady(permissionGranted: true))
        state.suspend(.sleep); state.suspend(.screenSleep); state.suspend(.inactiveSession)
        state.resume(.sleep)
        expectFalse(state.takeStartIfReady(permissionGranted: true))
        state.resume(.screenSleep)
        expectFalse(state.takeStartIfReady(permissionGranted: true))
        state.resume(.inactiveSession)
        expectFalse(state.takeStartIfReady(permissionGranted: false))
        expectTrue(state.takeStartIfReady(permissionGranted: true))
        state.resume(.inactiveSession)
        expectFalse(state.takeStartIfReady(permissionGranted: true))
    }
    func testStopOrObservationDuringSuspensionPreventsRestart() {
        var state = AutoStartState()
        expectTrue(state.takeStartIfReady(permissionGranted: true))
        state.suspend(.sleep)
        state.stop() // Same explicit intent when switching to passive observation.
        state.resume(.sleep)
        expectFalse(state.takeStartIfReady(permissionGranted: true))
        state.suspend(.inactiveSession)
        state.requestStart()
        expectFalse(state.takeStartIfReady(permissionGranted: true))
        state.resume(.inactiveSession)
        expectTrue(state.takeStartIfReady(permissionGranted: true))
    }
}
