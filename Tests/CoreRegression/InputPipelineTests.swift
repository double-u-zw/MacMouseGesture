import Foundation
import CoreGraphics
import GestureCore

final class InputPipelineTests {
    private func event(_ type: CGEventType, button: Int = 3, dx: Int64 = 0, dy: Int64 = 0) -> CGEvent {
        let event = CGEvent(source: nil)!
        event.type = type
        event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button))
        event.setIntegerValueField(.mouseEventDeltaX, value: dx)
        event.setIntegerValueField(.mouseEventDeltaY, value: dy)
        return event
    }
    func testButtonBoundariesAndHighRateAccumulation() {
        let box = InputMailbox(buttons: [3], gesture: true, freeze: true)
        expectTrue(box.capture(type: .otherMouseDown, event: event(.otherMouseDown)))
        for _ in 0..<8000 { expectTrue(box.capture(type: .otherMouseDragged, event: event(.otherMouseDragged, dx: 2, dy: -1))) }
        expectTrue(box.capture(type: .otherMouseUp, event: event(.otherMouseUp)))
        let items = box.drain()
        expectEqual(items.count, 5)
        guard items.count == 5 else { return }
        if case .button(3, true, _) = items[0] {} else { expectTrue(false, "missing DOWN boundary") }
        if case .modifier(true, _) = items[1] {} else { expectTrue(false, "missing logical hold") }
        if case .motion(let x, let y, _, let n) = items[2] {
            expectEqual(x, 16000); expectEqual(y, -8000); expectEqual(n, 8000)
        } else { expectTrue(false, "motion not accumulated") }
        if case .button(3, false, _) = items[3] {} else { expectTrue(false, "missing UP boundary") }
        if case .modifier(false, _) = items[4] {} else { expectTrue(false, "missing logical release") }
    }
    func testUnrelatedInputAndStoppedHookAlwaysPass() {
        let box = InputMailbox(buttons: [3], gesture: true, freeze: true)
        expectFalse(box.capture(type: .otherMouseDown, event: event(.otherMouseDown, button: 4)))
        expectFalse(box.capture(type: .mouseMoved, event: event(.mouseMoved, dx: 5)))
        _ = box.capture(type: .otherMouseDown, event: event(.otherMouseDown))
        expectFalse(box.capture(type: .leftMouseDown, event: event(.leftMouseDown, button: 0)))
        expectFalse(box.capture(type: .scrollWheel, event: event(.scrollWheel)))
        box.stop()
        expectFalse(box.capture(type: .mouseMoved, event: event(.mouseMoved, dx: 5)))
        expectFalse(box.capture(type: .otherMouseDown, event: event(.otherMouseDown)))
    }
    func testObservationNeverConsumesAndOverflowFailsOpen() {
        let observer = InputMailbox(buttons: [3], gesture: false, freeze: true)
        expectFalse(observer.capture(type: .otherMouseDown, event: event(.otherMouseDown)))
        expectFalse(observer.capture(type: .mouseMoved, event: event(.mouseMoved)))
        let box = InputMailbox(buttons: [3], gesture: true, freeze: true)
        for _ in 0..<257 { _ = box.capture(type: .otherMouseDown, event: event(.otherMouseDown)) }
        let records = box.drain()
        expectEqual(records.count, 1)
        if case .cancel = records.first {} else { expectTrue(false, "overflow must cancel") }
        expectFalse(box.capture(type: .mouseMoved, event: event(.mouseMoved)))
    }
    func testEscapeReleasesFreezeAndDisablingFreezePassesMotion() {
        let box = InputMailbox(buttons: [3], gesture: true, freeze: true)
        _ = box.capture(type: .otherMouseDown, event: event(.otherMouseDown))
        let escape = event(.keyDown); escape.setIntegerValueField(.keyboardEventKeycode, value: 53)
        expectFalse(box.capture(type: .keyDown, event: escape))
        expectFalse(box.capture(type: .mouseMoved, event: event(.mouseMoved)))
        let records = box.drain()
        expectEqual(records.count, 3)
        if case .cancel("Escape") = records.last {} else { expectTrue(false, "Escape must cancel") }
        let moving = InputMailbox(buttons: [3], gesture: true, freeze: false)
        expectTrue(moving.capture(type: .otherMouseDown, event: event(.otherMouseDown)))
        expectFalse(moving.capture(type: .mouseMoved, event: event(.mouseMoved, dx: 20)))
        expectEqual(moving.drain().count, 3)
    }
    func testZeroAndForeignTimestampsCannotExpireGesture() {
        let box = InputMailbox(buttons: [3], gesture: true, freeze: false)
        let down = event(.otherMouseDown); down.timestamp = 0
        let motion = event(.mouseMoved, dx: 30); motion.timestamp = 1
        let up = event(.otherMouseUp); up.timestamp = UInt64.max
        _ = box.capture(type: .otherMouseDown, event: down, receivedAt: 82_000)
        _ = box.capture(type: .mouseMoved, event: motion, receivedAt: 82_000.01)
        _ = box.capture(type: .otherMouseUp, event: up, receivedAt: 82_000.02)
        let records = box.drain()
        var machine = GestureMachine()
        for record in records {
            switch record {
            case .modifier(true, let time): machine.down(at: time)
            case .motion(let x, let y, let time, let count):
                machine.move(dx: x, dy: y, at: time, count: count)
                expectEqual(machine.frame(at: time).first?.phase, .began)
                expectTrue(time - machine.startTime < 20, "invalid event timestamp must not trip safety lease")
            case .modifier(false, let time):
                expectTrue(time - machine.startTime < 0.03)
                expectEqual(machine.finish(at: time).last?.phase, .ended)
            default: break
            }
        }
        expectEqual(machine.startTime, 82_000)
        expectTrue(box.stats().contains("rejected=3"))
        expectTrue(box.stats().contains("max=unavailable"))
    }
    func testTimingReportsOnlyComparableTimestampAges() {
        var timing = InputTiming()
        timing.observe(timestamp: 0, receivedAt: 82_000)
        timing.observe(timestamp: 5_000_000_000, receivedAt: 82_000)
        timing.observe(timestamp: 82_001_000_000_000, receivedAt: 82_000)
        timing.observe(timestamp: 81_999_998_000_000, receivedAt: 82_000)
        expectEqual(timing.rejectedTimestamps, 3)
        expectEqual(timing.validTimestamps, 1)
        expectEqual(timing.maxEventAgeMS ?? -1, 2, accuracy: 0.0001)
    }

    // Feed the real mailbox's logical edges and accumulated deltas to the core;
    // no events are posted to macOS by these tests.
    private func pump(_ box: InputMailbox, _ machine: inout GestureMachine, _ frames: inout [GestureFrame]) {
        for record in box.drain() {
            switch record {
            case .modifier(true, let time): machine.down(at: time)
            case .modifier(false, let time): frames += machine.finish(at: time)
            case .motion(let x, let y, let time, let count):
                machine.move(dx: x, dy: y, at: time, count: count)
                frames += machine.frame(at: time)
            case .cancel: frames += machine.finish(at: 2, cancel: true)
            default: break
            }
        }
    }
    func testEitherSideButtonDrivesTheConfirmedDirection() {
        for button in [3, 4] {
            let box = InputMailbox(buttons: [3, 4], gesture: true, freeze: true)
            var config = GestureConfig(); config.invert = true
            var machine = GestureMachine(config: config)
            var frames: [GestureFrame] = []
            let delta: Int64 = button == 3 ? 300 : -300
            expectTrue(box.capture(type: .otherMouseDown, event: event(.otherMouseDown, button: button), receivedAt: 1))
            expectTrue(box.capture(type: .otherMouseDragged, event: event(.otherMouseDragged, button: button, dx: delta), receivedAt: 1.02))
            pump(box, &machine, &frames)
            expectTrue(box.capture(type: .otherMouseUp, event: event(.otherMouseUp, button: button), receivedAt: 1.03))
            pump(box, &machine, &frames)
            expectEqual(frames.map { $0.phase }, [.began, .ended])
            expectEqual(frames.last?.progress ?? 0, Double(delta) / 600, accuracy: 1e-9)
            expectTrue((frames.last?.velocity ?? 0) * Double(delta) > 0, "release velocity must follow the configured direction")
            expectEqual(machine.state, .idle)
            expectFalse(box.capture(type: .mouseMoved, event: event(.mouseMoved, dx: 10)))
        }
    }
    func testOverlappingButtonsFinishOnlyAfterLastRelease() {
        for first in [3, 4] {
            let second = first == 3 ? 4 : 3
            for releasedFirst in [first, second] {
                let releasedLast = releasedFirst == 3 ? 4 : 3
                let box = InputMailbox(buttons: [3, 4], gesture: true, freeze: true)
                var machine = GestureMachine()
                var frames: [GestureFrame] = []
                _ = box.capture(type: .otherMouseDown, event: event(.otherMouseDown, button: first), receivedAt: 1)
                _ = box.capture(type: .mouseMoved, event: event(.mouseMoved, dx: 180), receivedAt: 1.01)
                pump(box, &machine, &frames)
                expectEqual(frames.map { $0.phase }, [.began])
                expectTrue(box.capture(type: .otherMouseDown, event: event(.otherMouseDown, button: second), receivedAt: 1.02))
                _ = box.capture(type: .mouseMoved, event: event(.mouseMoved, dx: 60), receivedAt: 1.03)
                pump(box, &machine, &frames)
                expectTrue(box.capture(type: .otherMouseUp, event: event(.otherMouseUp, button: releasedFirst), receivedAt: 1.04))
                expectTrue(box.capture(type: .mouseMoved, event: event(.mouseMoved, dx: 60), receivedAt: 1.05))
                pump(box, &machine, &frames)
                expectEqual(machine.state, .horizontal)
                expectEqual(machine.startTime, 1)
                expectEqual(machine.totalX, 300)
                expectEqual(frames.map { $0.phase }, [.began, .changed, .changed])
                expectTrue(box.capture(type: .otherMouseUp, event: event(.otherMouseUp, button: releasedLast), receivedAt: 1.06))
                pump(box, &machine, &frames)
                expectEqual(frames.map { $0.phase }, [.began, .changed, .changed, .ended])
                expectEqual(frames.last?.progress, -0.5)
                expectEqual(machine.state, .idle)
                expectFalse(box.capture(type: .mouseMoved, event: event(.mouseMoved, dx: 10)))
            }
        }
    }
    func testDuplicateDownAndUnmatchedUpDoNotRestartOrEndGesture() {
        let box = InputMailbox(buttons: [3, 4], gesture: true, freeze: true)
        var machine = GestureMachine()
        var frames: [GestureFrame] = []
        _ = box.capture(type: .otherMouseUp, event: event(.otherMouseUp, button: 4), receivedAt: 0.9)
        _ = box.capture(type: .otherMouseDown, event: event(.otherMouseDown, button: 3), receivedAt: 1)
        _ = box.capture(type: .mouseMoved, event: event(.mouseMoved, dx: 180), receivedAt: 1.01)
        pump(box, &machine, &frames)
        _ = box.capture(type: .otherMouseDown, event: event(.otherMouseDown, button: 3), receivedAt: 1.02)
        _ = box.capture(type: .otherMouseUp, event: event(.otherMouseUp, button: 4), receivedAt: 1.03)
        expectFalse(box.capture(type: .otherMouseDown, event: event(.otherMouseDown, button: 5), receivedAt: 1.04))
        expectFalse(box.capture(type: .otherMouseUp, event: event(.otherMouseUp, button: 5), receivedAt: 1.05))
        expectTrue(box.capture(type: .mouseMoved, event: event(.mouseMoved, dx: 120), receivedAt: 1.06))
        pump(box, &machine, &frames)
        expectEqual(machine.startTime, 1)
        expectEqual(machine.totalX, 300)
        expectEqual(machine.state, .horizontal)
        _ = box.capture(type: .otherMouseUp, event: event(.otherMouseUp, button: 3), receivedAt: 1.07)
        _ = box.capture(type: .otherMouseUp, event: event(.otherMouseUp, button: 3), receivedAt: 1.08)
        pump(box, &machine, &frames)
        expectEqual(frames.map { $0.phase }, [.began, .changed, .ended])
        // A later independent gesture must start with a fresh distance.
        _ = box.capture(type: .otherMouseDown, event: event(.otherMouseDown, button: 4), receivedAt: 2)
        _ = box.capture(type: .mouseMoved, event: event(.mouseMoved, dx: -240), receivedAt: 2.02)
        _ = box.capture(type: .otherMouseUp, event: event(.otherMouseUp, button: 4), receivedAt: 2.03)
        pump(box, &machine, &frames)
        expectEqual(frames.map { $0.phase }, [.began, .changed, .ended, .began, .ended])
        expectEqual(machine.totalX, -240)
    }
    func testDualButtonCancellationImmediatelyFailsOpen() {
        for escapeKey in [true, false] {
            let box = InputMailbox(buttons: [3, 4], gesture: true, freeze: true)
            var machine = GestureMachine()
            var frames: [GestureFrame] = []
            for button in [3, 4] {
                _ = box.capture(type: .otherMouseDown, event: event(.otherMouseDown, button: button), receivedAt: 1)
            }
            _ = box.capture(type: .mouseMoved, event: event(.mouseMoved, dx: 300), receivedAt: 1.02)
            pump(box, &machine, &frames)
            if escapeKey {
                let escape = event(.keyDown); escape.setIntegerValueField(.keyboardEventKeycode, value: 53)
                expectFalse(box.capture(type: .keyDown, event: escape, receivedAt: 1.03))
            } else { box.cancel("event tap disabled") }
            // A second button event arriving before the engine drains cancellation
            // must not re-freeze the pointer or restart the sequence.
            for button in [3, 4] {
                expectFalse(box.capture(type: .otherMouseDown, event: event(.otherMouseDown, button: button), receivedAt: 1.04))
                expectFalse(box.capture(type: .otherMouseUp, event: event(.otherMouseUp, button: button), receivedAt: 1.05))
            }
            expectFalse(box.capture(type: .mouseMoved, event: event(.mouseMoved, dx: 20), receivedAt: 1.06))
            pump(box, &machine, &frames)
            expectEqual(frames.map { $0.phase }, [.began, .cancelled])
            expectEqual(machine.state, .idle)
        }
    }
    func testDualButtonObservationDoesNotGenerateModifierOrConsume() {
        let box = InputMailbox(buttons: [3, 4], gesture: false, freeze: true)
        for button in [3, 4] {
            expectFalse(box.capture(type: .otherMouseDown, event: event(.otherMouseDown, button: button)))
            expectFalse(box.capture(type: .otherMouseDragged, event: event(.otherMouseDragged, button: button, dx: 100)))
            expectFalse(box.capture(type: .otherMouseUp, event: event(.otherMouseUp, button: button)))
        }
        let records = box.drain()
        expectEqual(records.count, 6)
        for record in records {
            if case .modifier = record { expectTrue(false, "observation must not start a gesture") }
        }
    }
}
