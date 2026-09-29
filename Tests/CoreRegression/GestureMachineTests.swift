import Foundation
import GestureCore
import SystemGestureBridge

final class GestureMachineTests {
    func testButtonNumbersAreZeroBasedAndOthersPreserved() {
        expectEqual(MouseButton(cgNumber: 3), .button4)
        expectEqual(MouseButton(cgNumber: 4), .button5)
        expectEqual(MouseButton(cgNumber: 7), .other(7))
    }
    func testDeadZoneNeverEmitsAndTapDoesNothing() {
        var m = GestureMachine(); m.down(at: 0)
        m.move(dx: 3, dy: 2, at: 0.01)
        expectTrue(m.frame(at: 0.01).isEmpty)
        expectTrue(m.finish(at: 0.02).isEmpty)
        expectEqual(m.state, .idle)
    }
    func testVerticalLockCannotTurnIntoHorizontalLater() {
        var m = GestureMachine(); m.down(at: 0)
        m.move(dx: 1, dy: 20, at: 0.01)
        expectTrue(m.frame(at: 0.01).isEmpty)
        m.move(dx: 200, dy: 0, at: 0.02)
        expectTrue(m.frame(at: 0.02).isEmpty)
        expectEqual(m.state, .rejectedVertical)
        expectTrue(m.finish(at: 0.03).isEmpty)
    }
    func testEnabledVerticalLockCannotTurnIntoHorizontalLater() {
        var config = GestureConfig(); config.verticalEnabled = true
        var m = GestureMachine(config: config); m.down(at: 0)
        m.move(dx: 1, dy: -20, at: 0.01)
        expectTrue(m.frame(at: 0.01).isEmpty)
        expectEqual(m.state, .vertical)
        m.move(dx: 200, dy: 0, at: 0.02)
        expectTrue(m.frame(at: 0.02).isEmpty)
        expectEqual(m.state, .vertical)
        expectTrue(m.finish(at: 0.03).isEmpty)
    }
    func testHorizontalLockSurvivesDiagonalAndSupportsReversal() {
        var m = GestureMachine(); m.down(at: 0)
        m.move(dx: 100, dy: 0, at: 0.01)
        expectEqual(m.frame(at: 0.01).first?.phase, .began)
        m.move(dx: -50, dy: 300, at: 0.02)
        expectEqual(m.frame(at: 0.02).first?.phase, .changed)
        expectEqual(m.state, .horizontal)
        expectEqual(m.progress, -50.0 / 600, accuracy: 1e-9)
    }
    func testEightKilohertzInputKeepsEveryDeltaAt120Frames() {
        var m = GestureMachine(); m.down(at: 0)
        var output: [GestureFrame] = []
        var next = 1.0 / 120
        for i in 1...8000 {
            let time = Double(i) / 8000
            m.move(dx: 0.25, dy: 0, at: time)
            if time >= next { output += m.frame(at: time); next += 1.0 / 120 }
        }
        output += m.finish(at: 1.001)
        expectEqual(m.rawEvents, 8000)
        expectEqual(m.totalX, 2000, accuracy: 1e-9)
        expectAtMost(output.count, 121)
        expectEqual(output.first?.phase, .began)
        expectEqual(output.last?.progress ?? 0, -2000.0 / 600, accuracy: 1e-9)
        expectEqual(output.filter { $0.phase == .began }.count, 1)
    }
    func testReleaseContainsMotionSinceLastFrame() {
        var m = GestureMachine(); m.down(at: 0)
        m.move(dx: 100, dy: 0, at: 0.02); _ = m.frame(at: 0.02)
        m.move(dx: 30, dy: 0, at: 0.025)
        let result = m.finish(at: 0.026)
        expectEqual(result.count, 1)
        expectEqual(result[0].progress, -130.0 / 600, accuracy: 1e-9)
    }
    func testStopAtHalfDoesNotEmitOrReplayVelocity() {
        var m = GestureMachine(); m.down(at: 0)
        m.move(dx: 100, dy: 0, at: 0.02); _ = m.frame(at: 0.02)
        expectTrue(m.frame(at: 0.5).isEmpty)
        let end = m.finish(at: 0.6)
        expectEqual(end.last?.velocity, 0)
        expectEqual(end.last?.phase, .cancelled)
    }
    func testFastFlickCompletesButSlowShortDragCancels() {
        var fast = GestureMachine(); fast.down(at: 0)
        fast.move(dx: 60, dy: 0, at: 0.02); _ = fast.frame(at: 0.02)
        expectEqual(fast.finish(at: 0.021).last?.phase, .ended)
        var slow = GestureMachine(); slow.down(at: 0)
        for i in 1...10 {
            slow.move(dx: 6, dy: 0, at: Double(i) * 0.1); _ = slow.frame(at: Double(i) * 0.1)
        }
        expectEqual(slow.finish(at: 1.01).last?.phase, .cancelled)
    }
    func testLargeSlowProgressCompletes() {
        var m = GestureMachine(); m.down(at: 0)
        m.move(dx: 250, dy: 0, at: 1); _ = m.frame(at: 1)
        expectEqual(m.finish(at: 2).last?.phase, .ended)
    }
    func testCancellationIsSingleTerminalAndNextGestureStartsFresh() {
        var m = GestureMachine(); m.down(at: 0)
        m.move(dx: 300, dy: 0, at: 0.01); _ = m.frame(at: 0.01)
        expectEqual(m.finish(at: 0.02, cancel: true).last?.phase, .cancelled)
        expectTrue(m.finish(at: 0.03, cancel: true).isEmpty)
        m.down(at: 0.04)
        expectEqual(m.rawEvents, 0); expectEqual(m.progress, 0)
    }
    func testOneHundredSessionsResetCleanly() {
        var m = GestureMachine()
        for i in 0..<100 {
            let t = Double(i)
            m.down(at: t)
            m.move(dx: i % 2 == 0 ? 300 : -300, dy: 0, at: t + 0.02)
            expectEqual(m.frame(at: t + 0.02).first?.phase, .began)
            expectEqual(m.finish(at: t + 0.03).last?.phase, .ended)
            expectEqual(m.state, .idle)
            expectEqual(m.emittedEvents, 2)
        }
    }
    func testDirectionConfigurationAndInvalidMotion() {
        var c = GestureConfig(); c.invert = true
        var m = GestureMachine(config: c); m.down(at: 0)
        m.move(dx: .nan, dy: 0, at: 0.01)
        m.move(dx: 60, dy: 0, at: 0.02)
        expectEqual(m.frame(at: 0.02).first?.progress ?? 0, 0.1, accuracy: 1e-9)
        expectEqual(m.rawEvents, 1)
    }
    func testPrivateBridgeAttachmentWithoutPosting() throws {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27 else {
            throw CheckError.skip("macOS 27 runtime required")
        }
        var buffer = [CChar](repeating: 0, count: 512)
        expectTrue(MGBackendProbe(&buffer, UInt(buffer.count)), String(cString: buffer))
        // Invalid requests must never post anything.
        expectFalse(MGPostHorizontal(.nan, 0, 1))
        expectFalse(MGPostHorizontal(0, 0, 99))
    }
}
