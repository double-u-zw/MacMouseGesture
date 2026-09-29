import Foundation
import GestureCore
import SystemGestureBridge

struct MissionControlPOCTests {
    func testVerticalLockSelectsMissionControlOnlyAfterDeadZone() {
        var axis = GestureMachine()
        var vertical = VerticalGestureTracker()
        axis.down(at: 0); vertical.down(at: 0)
        axis.move(dx: 1, dy: -7, at: 0.01); vertical.move(totalY: axis.totalY, at: 0.01)
        expectTrue(axis.frame(at: 0.01).isEmpty)
        expectTrue(vertical.frame(verticalLocked: axis.state == .rejectedVertical, at: 0.01).isEmpty)
        axis.move(dx: 1, dy: -13, at: 0.02); vertical.move(totalY: axis.totalY, at: 0.02)
        expectTrue(axis.frame(at: 0.02).isEmpty)
        expectEqual(axis.state, .rejectedVertical)
        expectEqual(vertical.frame(verticalLocked: true, at: 0.02).first?.phase, .began)
        expectEqual(vertical.action, .missionControl)
        expectEqual(vertical.progress, 20.0 / 300, accuracy: 1e-9)
    }

    func testDownwardLockSelectsAppExposeAndCannotSwitchOnReversal() {
        var vertical = VerticalGestureTracker()
        vertical.down(at: 0)
        vertical.move(totalY: 40, at: 0.02)
        expectEqual(vertical.frame(verticalLocked: true, at: 0.02).first?.phase, .began)
        expectEqual(vertical.action, .appExpose)
        expectEqual(vertical.progress, -40.0 / 300, accuracy: 1e-9)
        vertical.move(totalY: -120, at: 0.1)
        expectEqual(vertical.frame(verticalLocked: true, at: 0.1).first?.phase, .changed)
        expectEqual(vertical.action, .appExpose)
        expectEqual(vertical.progress, 0)
        expectEqual(vertical.finish(verticalLocked: true, at: 0.11).last?.phase, .cancelled)
    }

    func testAppExposeSlowCompletionAndStationaryHold() {
        var vertical = VerticalGestureTracker()
        vertical.down(at: 0)
        vertical.move(totalY: 200, at: 0.1)
        expectEqual(vertical.frame(verticalLocked: true, at: 0.1).first?.phase, .began)
        expectEqual(vertical.action, .appExpose)
        expectEqual(vertical.progress, -2.0 / 3, accuracy: 1e-9)
        expectTrue(vertical.frame(verticalLocked: true, at: 2.1).isEmpty)
        let terminal = vertical.finish(verticalLocked: true, at: 2.11)
        expectEqual(terminal.last?.phase, .ended)
        expectEqual(terminal.last?.velocity, 0)
        expectTrue(vertical.finish(verticalLocked: true, at: 2.12).isEmpty)
    }

    func testAppExposeFlickAndSmallSlowRebound() {
        var flick = VerticalGestureTracker()
        flick.down(at: 0)
        flick.move(totalY: 60, at: 0.02)
        _ = flick.frame(verticalLocked: true, at: 0.02)
        expectEqual(flick.finish(verticalLocked: true, at: 0.021).last?.phase, .ended)

        var slow = VerticalGestureTracker()
        slow.down(at: 0)
        slow.move(totalY: 30, at: 0.1)
        _ = slow.frame(verticalLocked: true, at: 0.1)
        expectEqual(slow.finish(verticalLocked: true, at: 0.4).last?.phase, .cancelled)
    }

    func testReverseKeepsMissionControlActionAndCanRebound() {
        var vertical = VerticalGestureTracker()
        vertical.down(at: 0)
        vertical.move(totalY: -180, at: 0.1)
        expectEqual(vertical.frame(verticalLocked: true, at: 0.1).first?.phase, .began)
        vertical.move(totalY: -45, at: 0.2)
        expectEqual(vertical.frame(verticalLocked: true, at: 0.2).first?.phase, .changed)
        expectEqual(vertical.action, .missionControl)
        expectEqual(vertical.progress, 0.15, accuracy: 1e-9)
        expectEqual(vertical.finish(verticalLocked: true, at: 0.201).last?.phase, .cancelled)
    }

    func testStationaryHoldAndReleaseUseFreshVelocity() {
        var vertical = VerticalGestureTracker()
        vertical.down(at: 0)
        vertical.move(totalY: -120, at: 0.1)
        _ = vertical.frame(verticalLocked: true, at: 0.1)
        expectTrue(vertical.frame(verticalLocked: true, at: 2.1).isEmpty)
        let terminal = vertical.finish(verticalLocked: true, at: 2.11)
        expectEqual(terminal.last?.velocity, 0)
        expectEqual(terminal.last?.phase, .cancelled)
    }

    func testFastFlickCompletesAndCancellationOccursExactlyOnce() {
        var flick = VerticalGestureTracker()
        flick.down(at: 0)
        flick.move(totalY: -60, at: 0.02)
        _ = flick.frame(verticalLocked: true, at: 0.02)
        expectEqual(flick.finish(verticalLocked: true, at: 0.021).last?.phase, .ended)

        var cancel = VerticalGestureTracker()
        cancel.down(at: 1)
        cancel.move(totalY: -100, at: 1.03)
        _ = cancel.frame(verticalLocked: true, at: 1.03)
        expectEqual(cancel.finish(verticalLocked: true, at: 1.04, cancel: true).last?.phase, .cancelled)
        expectTrue(cancel.finish(verticalLocked: true, at: 1.05, cancel: true).isEmpty)
    }

    func testHorizontalPathDoesNotSelectVerticalAction() {
        var axis = GestureMachine()
        var vertical = VerticalGestureTracker()
        axis.down(at: 0); vertical.down(at: 0)
        axis.move(dx: 100, dy: 5, at: 0.02); vertical.move(totalY: axis.totalY, at: 0.02)
        expectEqual(axis.frame(at: 0.02).first?.phase, .began)
        expectEqual(axis.state, .horizontal)
        expectTrue(vertical.frame(verticalLocked: false, at: 0.02).isEmpty)
        expectEqual(vertical.action, .undecided)
        expectEqual(axis.finish(at: 0.03).last?.phase, .ended)
        expectTrue(vertical.finish(verticalLocked: false, at: 0.03).isEmpty)
    }

    func testVerticalHIDRoundTripWithoutPosting() throws {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27 else {
            throw CheckError.skip("macOS 27 runtime required")
        }
        var buffer = [CChar](repeating: 0, count: 512)
        expectTrue(MGVerticalProbe(&buffer, UInt(buffer.count)), String(cString: buffer))
        expectFalse(MGPostVertical(.nan, 0, 1))
        expectFalse(MGPostVertical(.infinity, 0, 1))
        expectFalse(MGPostVertical(0, 0, 99))
    }
}
