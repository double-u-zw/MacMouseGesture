import Foundation
import Darwin

enum CheckError: Error { case skip(String) }
if CommandLine.arguments.count == 3, ["--write-config-fixture", "--read-config-fixture"].contains(CommandLine.arguments[1]) {
    let defaults = UserDefaults(suiteName: CommandLine.arguments[2])!
    let store = ConfigStore(defaults: defaults)
    var fixture = AppConfig(); fixture.enabled = false; fixture.deadZone = 17; fixture.sensitivity = 760
    fixture.horizontalInvert = true; fixture.gestureButtons = [4]; fixture.freezePointer = false
    if CommandLine.arguments[1] == "--write-config-fixture" {
        store.save(fixture)
        // Deterministic test process flush, not required by production UI writes.
        exit(defaults.synchronize() ? 0 : 1)
    }
    exit(store.load() == fixture ? 0 : 1)
}
var failures = 0
func fail(_ message: String, _ file: StaticString, _ line: UInt) {
    failures += 1; print("FAIL \(file):\(line): \(message)")
}
func expectTrue(_ value: Bool, _ message: String = "expected true", file: StaticString = #filePath, line: UInt = #line) {
    if !value { fail(message, file, line) }
}
func expectFalse(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
    if value { fail("expected false", file, line) }
}
func expectEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) {
    if actual != expected { fail("\(actual) != \(expected)", file, line) }
}
func expectEqual(_ actual: Double, _ expected: Double, accuracy: Double, file: StaticString = #filePath, line: UInt = #line) {
    if !actual.isFinite || abs(actual - expected) > accuracy { fail("\(actual) not near \(expected)", file, line) }
}
func expectAtMost(_ actual: Int, _ expected: Int, file: StaticString = #filePath, line: UInt = #line) {
    if actual > expected { fail("\(actual) > \(expected)", file, line) }
}
let suite = GestureMachineTests()
let input = InputPipelineTests()
let automatic = AutoStartTests()
let configuration = ConfigTests()
let boundary = BoundaryTests()
let presentation = PresentationTests()
let missionPOC = MissionControlPOCTests()
let checks: [(String, () throws -> Void)] = [
    ("button mapping", suite.testButtonNumbersAreZeroBasedAndOthersPreserved),
    ("dead zone", suite.testDeadZoneNeverEmitsAndTapDoesNothing),
    ("vertical axis lock", suite.testVerticalLockCannotTurnIntoHorizontalLater),
    ("enabled vertical axis lock remains fixed", suite.testEnabledVerticalLockCannotTurnIntoHorizontalLater),
    ("horizontal axis lock + reverse", suite.testHorizontalLockSurvivesDiagonalAndSupportsReversal),
    ("8000 Hz → 120 Hz, all deltas retained", suite.testEightKilohertzInputKeepsEveryDeltaAt120Frames),
    ("release flush", suite.testReleaseContainsMotionSinceLastFrame),
    ("stationary hold + stale velocity", suite.testStopAtHalfDoesNotEmitOrReplayVelocity),
    ("flick vs slow release", suite.testFastFlickCompletesButSlowShortDragCancels),
    ("progress completion", suite.testLargeSlowProgressCompletes),
    ("cancel + restart", suite.testCancellationIsSingleTerminalAndNextGestureStartsFresh),
    ("100 simulated sessions", suite.testOneHundredSessionsResetCleanly),
    ("invert + invalid input", suite.testDirectionConfigurationAndInvalidMotion),
    ("private HID round-trip; NO event injection", suite.testPrivateBridgeAttachmentWithoutPosting),
    ("8000 input reports + ordered button boundaries", input.testButtonBoundariesAndHighRateAccumulation),
    ("unrelated inputs + stopped hook pass through", input.testUnrelatedInputAndStoppedHookAlwaysPass),
    ("observe mode + overflow fail open", input.testObservationNeverConsumesAndOverflowFailsOpen),
    ("Escape + optional pointer freeze", input.testEscapeReleasesFreezeAndDisablingFreezePassesMotion),
    ("invalid input timestamps cannot expire a gesture", input.testZeroAndForeignTimestampsCannotExpireGesture),
    ("event age rejects missing/stale/future timestamps", input.testTimingReportsOnlyComparableTimestampAges),
    ("either side button + confirmed direction", input.testEitherSideButtonDrivesTheConfirmedDirection),
    ("overlapping buttons + both release orders", input.testOverlappingButtonsFinishOnlyAfterLastRelease),
    ("duplicate/unmatched edges + alternating buttons", input.testDuplicateDownAndUnmatchedUpDoNotRestartOrEndGesture),
    ("dual-button Escape/tap cancellation fails open", input.testDualButtonCancellationImmediatelyFailsOpen),
    ("dual-button observation remains passive", input.testDualButtonObservationDoesNotGenerateModifierOrConsume),
    ("permission grant starts once without retry loops", automatic.testPermissionGrantStartsOnceAndDoesNotRetryFailures),
    ("manual stop overrides pending automatic start", automatic.testManualStopWhileWaitingForPermissionIsRespected),
    ("resume waits for all suspensions and permission", automatic.testResumeWaitsForEverySuspensionAndPermission),
    ("stopped/observation mode stays stopped on wake", automatic.testStopOrObservationDuringSuspensionPreventsRestart),
    ("first launch retains Build 4 settings", configuration.testFirstLaunchKeepsBuild4Defaults),
    ("all config fields + disabled intent round trip", configuration.testAllExposedSettingsRoundTripAndDisablePersists),
    ("corrupt defaults, NaN, infinity and type protection", configuration.testCorruptionAndTypesDoNotReachEngine),
    ("config limits and side-button input validation", configuration.testBoundsAndButtonParsing),
    ("vertical preference migrates and enables independently", configuration.testVerticalPreferenceMigrationAndIndependentEnablement),
    ("config persists across separate processes", configuration.testSeparateProcessRestoresSavedSettings),
    ("slow drag, 7+2px dead zone and pause/resume", boundary.testSlowDragPauseResumeAndDeadZoneBoundary),
    ("halfway two-second pause keeps one sequence", boundary.testTwoSecondHalfwayPauseThenContinue),
    ("reverse 100/80 and small jitter", boundary.testReversalKeepsOneSequenceAndJitterStaysBelowDeadZone),
    ("100 alternating buttons + release jitter + balanced counters", boundary.testReleaseJitterAnd100AlternatingButtonsHaveNoOrphans),
    ("tap interrupt cancels once, fails open, requires release", boundary.testTapInterruptionFailsOpenCancelsOnceAndWaitsForRelease),
    ("bounded recovery + display resume respects stop/sleep", boundary.testRecoveryRateLimitAndDisplayRestartRespectStop),
    ("counters expose orphan and invalid sequences", boundary.testCountersExposeIncompleteOrInvalidSequences),
    ("menu status maps real engine and permission state", presentation.testStatusUsesExistingEngineAndPermissionState),
    ("side-button settings cannot remove the last button", presentation.testSideButtonsCannotBecomeEmpty),
    ("sensitivity slider preserves the confirmed default", presentation.testSliderPositionsRoundTripExistingDefaults),
    ("settings bindings save through the existing config store", presentation.testSettingsBindingUsesExistingConfigStore),
    ("login item approval is distinct from off", presentation.testLoginStateDoesNotMistakeApprovalForOff),
    ("reset only gesture settings", presentation.testResetRestoresOnlyGestureSettings),
    ("user status labels are Chinese", presentation.testUserStatusLabelsAreChinese),
    ("vertical axis locks after dead zone", missionPOC.testVerticalLockSelectsMissionControlOnlyAfterDeadZone),
    ("downward lock selects App Exposé and stays locked on reversal", missionPOC.testDownwardLockSelectsAppExposeAndCannotSwitchOnReversal),
    ("App Exposé slow completion and stationary hold", missionPOC.testAppExposeSlowCompletionAndStationaryHold),
    ("App Exposé flick and small slow rebound", missionPOC.testAppExposeFlickAndSmallSlowRebound),
    ("Mission Control remains selected on reverse movement", missionPOC.testReverseKeepsMissionControlActionAndCanRebound),
    ("stationary vertical hold discards old velocity", missionPOC.testStationaryHoldAndReleaseUseFreshVelocity),
    ("vertical flick and exactly-once cancellation", missionPOC.testFastFlickCompletesAndCancellationOccursExactlyOnce),
    ("horizontal path stays isolated from vertical POC", missionPOC.testHorizontalPathDoesNotSelectVerticalAction),
    ("vertical HID round-trip; NO event injection", missionPOC.testVerticalHIDRoundTripWithoutPosting)
]
for (name, check) in checks {
    let before = failures
    do { try check(); if failures == before { print("PASS \(name)") } }
    catch CheckError.skip(let reason) { print("SKIP \(name): \(reason)") }
    catch { fail("\(name): \(error)", #filePath, #line) }
}
print("\(checks.count) checks, \(failures) failures. No real mouse/Spaces acceptance implied.")
exit(failures == 0 ? 0 : 1)
