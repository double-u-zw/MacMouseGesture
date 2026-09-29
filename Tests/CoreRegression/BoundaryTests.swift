import Foundation
import CoreGraphics
import GestureCore

final class BoundaryTests {
    func testSlowDragPauseResumeAndDeadZoneBoundary() {
        var c = AppConfig.defaults.gestureConfig
        c.deadZone = 8
        var m = GestureMachine(config: c); m.down(at: 0)
        var frames: [GestureFrame] = []
        for i in 1...7 {
            m.move(dx: 1, dy: 0, at: Double(i) * 0.2)
            expectTrue(m.frame(at: Double(i) * 0.2).isEmpty)
        }
        m.move(dx: 2, dy: 0, at: 1.6); frames += m.frame(at: 1.6)
        expectEqual(frames.map(\.phase), [.began])
        expectEqual(frames[0].progress, 9.0 / 600, accuracy: 1e-9)
        for t in [1.7, 2.0, 2.6] { expectTrue(m.frame(at: t).isEmpty) }
        expectEqual(m.state, .horizontal)
        m.move(dx: 3, dy: 0, at: 2.7); frames += m.frame(at: 2.7)
        frames += m.finish(at: 2.8)
        expectEqual(frames.map(\.phase), [.began, .changed, .cancelled])
        expectEqual(m.state, .idle)
    }
    func testTwoSecondHalfwayPauseThenContinue() {
        var m = GestureMachine(config: AppConfig.defaults.gestureConfig); m.down(at: 0)
        m.move(dx: 240, dy: 2, at: 0.02)
        let first = m.frame(at: 0.02)
        for i in 1...240 { expectTrue(m.frame(at: 0.02 + Double(i) / 120).isEmpty) }
        expectEqual(m.progress, 0.4); expectEqual(m.state, .horizontal)
        m.move(dx: 120, dy: 0, at: 2.1)
        let resumed = m.frame(at: 2.1)
        expectEqual(first.first?.phase, .began); expectEqual(resumed.first?.phase, .changed)
        expectEqual(resumed.first?.progress, 0.6)
        expectEqual(m.finish(at: 2.3).last?.phase, .ended)
    }
    func testReversalKeepsOneSequenceAndJitterStaysBelowDeadZone() {
        var m = GestureMachine(config: AppConfig.defaults.gestureConfig); m.down(at: 0)
        var t = 0.0
        for delta in [1.0, -1, 2, -2, 3, -3] {
            t += 0.01; m.move(dx: delta, dy: 0, at: t); expectTrue(m.frame(at: t).isEmpty)
        }
        m.move(dx: -100, dy: 0, at: 0.1)
        expectEqual(m.frame(at: 0.1).first?.phase, .began)
        m.move(dx: 80, dy: 0, at: 0.2)
        let reversed = m.frame(at: 0.2)
        expectEqual(reversed.first?.phase, .changed)
        expectEqual(reversed.first?.progress ?? 0, -20.0 / 600, accuracy: 1e-9)
        expectEqual(m.emittedEvents, 2)
        expectEqual(m.finish(at: 0.3).count, 1)
    }
    private func event(_ type: CGEventType, _ button: Int = 3, dx: Int64 = 0) -> CGEvent {
        let event = CGEvent(source: nil)!; event.type = type
        event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button))
        event.setIntegerValueField(.mouseEventDeltaX, value: dx)
        return event
    }
    private func pump(_ box: InputMailbox, _ m: inout GestureMachine, _ counts: inout GestureCounters) {
        for record in box.drain() {
            var frames: [GestureFrame] = []
            switch record {
            case .modifier(true, let time): m.down(at: time)
            case .modifier(false, let time): frames = m.finish(at: time)
            case .motion(let x, let y, let time, let count):
                m.move(dx: x, dy: y, at: time, count: count); frames = m.frame(at: time)
            case .cancel, .tapDisabled: frames = m.finish(at: m.startTime + 0.05, cancel: true)
            default: break
            }
            for frame in frames { counts.record(frame) }
        }
    }
    func testReleaseJitterAnd100AlternatingButtonsHaveNoOrphans() {
        let box = InputMailbox(buttons: [3, 4], gesture: true, freeze: true)
        var m = GestureMachine(config: AppConfig.defaults.gestureConfig)
        var counts = GestureCounters()
        for i in 0..<100 {
            let button = i.isMultiple(of: 2) ? 3 : 4
            let t = Double(i) * 3
            let sign: Int64 = i.isMultiple(of: 2) ? 1 : -1
            _ = box.capture(type: .otherMouseDown, event: event(.otherMouseDown, button), receivedAt: t)
            _ = box.capture(type: .otherMouseDragged, event: event(.otherMouseDragged, button, dx: sign * 300), receivedAt: t + 0.02)
            pump(box, &m, &counts)
            // A small reverse delta during a slow release must still yield one terminal.
            _ = box.capture(type: .otherMouseDragged, event: event(.otherMouseDragged, button, dx: -sign * Int64(i % 5 + 1)), receivedAt: t + 0.5)
            _ = box.capture(type: .otherMouseUp, event: event(.otherMouseUp, button), receivedAt: t + 0.6)
            pump(box, &m, &counts)
            expectFalse(box.capture(type: .mouseMoved, event: event(.mouseMoved, dx: 5), receivedAt: t + 0.61))
            _ = box.capture(type: .otherMouseUp, event: event(.otherMouseUp, button), receivedAt: t + 0.62)
            pump(box, &m, &counts)
            expectEqual(m.state, .idle)
            expectEqual(counts.gestureBegins, i + 1)
            expectEqual(counts.gestureEnds, i + 1)
            expectEqual(counts.openGestures, 0); expectEqual(counts.sequenceErrors, 0)
        }
        expectEqual(box.counts().button4Downs, 50); expectEqual(box.counts().button5Downs, 50)
        expectEqual(box.counts().rawMouseEvents, 600)
    }
    func testTapInterruptionFailsOpenCancelsOnceAndWaitsForRelease() {
        for reason in ["timeout", "user input", "health monitor"] {
            let box = InputMailbox(buttons: [3, 4], gesture: true, freeze: true)
            var m = GestureMachine(); var counts = GestureCounters()
            _ = box.capture(type: .otherMouseDown, event: event(.otherMouseDown), receivedAt: 1)
            _ = box.capture(type: .mouseMoved, event: event(.mouseMoved, dx: 300), receivedAt: 1.02)
            pump(box, &m, &counts)
            box.interruptForTapRecovery(reason); box.interruptForTapRecovery(reason)
            expectFalse(box.capture(type: .mouseMoved, event: event(.mouseMoved, dx: 20), receivedAt: 1.03))
            pump(box, &m, &counts)
            expectEqual(counts.gestureCancels, 1); expectEqual(counts.openGestures, 0)
            expectTrue(box.resumeAfterTapRecovery())
            expectFalse(box.capture(type: .otherMouseDown, event: event(.otherMouseDown), receivedAt: 1.04))
            expectFalse(box.capture(type: .mouseMoved, event: event(.mouseMoved, dx: 100), receivedAt: 1.05))
            expectFalse(box.capture(type: .otherMouseUp, event: event(.otherMouseUp), receivedAt: 1.06))
            expectTrue(box.capture(type: .otherMouseDown, event: event(.otherMouseDown), receivedAt: 2))
            _ = box.capture(type: .mouseMoved, event: event(.mouseMoved, dx: -300), receivedAt: 2.02)
            _ = box.capture(type: .otherMouseUp, event: event(.otherMouseUp), receivedAt: 2.03)
            pump(box, &m, &counts)
            expectEqual(m.totalX, -300); expectEqual(counts.gestureBegins, 2)
            expectEqual(counts.gestureEnds, 1); expectEqual(counts.sequenceErrors, 0)
            box.interruptForTapRecovery(reason); box.stop()
            expectFalse(box.resumeAfterTapRecovery())
        }
    }
    func testRecoveryRateLimitAndDisplayRestartRespectStop() {
        var budget = TapRecoveryBudget()
        for t in [1.0, 2, 3] { expectTrue(budget.take(at: t)) }
        expectFalse(budget.take(at: 4)); expectFalse(budget.take(at: 60))
        expectTrue(budget.take(at: 61))
        var automatic = AutoStartState()
        _ = automatic.takeStartIfReady(permissionGranted: true)
        automatic.requestRestartIfEnabled()
        expectTrue(automatic.takeStartIfReady(permissionGranted: true))
        automatic.stop(); automatic.requestRestartIfEnabled()
        expectFalse(automatic.takeStartIfReady(permissionGranted: true))
        automatic.requestStart(); automatic.suspend(.sleep); automatic.requestRestartIfEnabled()
        expectFalse(automatic.takeStartIfReady(permissionGranted: true))
        automatic.resume(.sleep)
        expectTrue(automatic.takeStartIfReady(permissionGranted: true))
    }
    func testCountersExposeIncompleteOrInvalidSequences() {
        var c = GestureCounters(); c.record(GestureFrame(.began, 0.2))
        expectEqual(c.openGestures, 1)
        c.record(GestureFrame(.cancelled, 0.2))
        expectEqual(c.gestureBegins, c.gestureEnds + c.gestureCancels)
        c.record(GestureFrame(.changed, 0.3))
        expectEqual(c.sequenceErrors, 1)
    }
}
