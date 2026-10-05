import AppKit
import CoreGraphics
import GestureCore

private func sideEvent(_ type: CGEventType, button: Int = 3, marked: Bool = false) -> CGEvent {
    let event = CGEvent(source: nil)!
    event.type = type
    event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button))
    if marked { MouseActionEventOrigin.mark(event) }
    return event
}
private final class BackFixture {
    let app = WindowApplicationIdentity(pid: 42, identifier: "test.frontmost")
    var permission = true
    var losePermission = false
    var permissionReads = 0
    var applicationExists = true
    var changeApplication = false
    var applicationReads = 0
    var point: CGPoint? = CGPoint(x: 120, y: 80)
    var allocationFails = false
    var allocations = 0
    var failType: CGEventType?
    var posted: [CGEvent] = []
    var messages: [String] = []
    lazy var action = BackMouseAction(permissionGranted: { [unowned self] in
        self.permissionReads += 1; return self.permission && !(self.losePermission && self.permissionReads > 1)
    }, frontmostApplication: { [unowned self] in
        self.applicationReads += 1
        if !self.applicationExists { return nil }
        return self.changeApplication && self.applicationReads > 1 ? WindowApplicationIdentity(pid: 99, identifier: "other.app") : self.app
    }, pointerLocation: { [unowned self] in self.point }, makeEvents: { [unowned self] point in
        self.allocations += 1
        return self.allocationFails ? nil : SyntheticSideButtonEvents.make(buttonNumber: 3, at: point)
    }, postEvent: { [unowned self] event in
        self.posted.append(event); return event.type != self.failType
    }, diagnostic: { [unowned self] in self.messages.append($0) })
}

let backMouseActionChecks: [(String, () throws -> Void)] = [
    ("Back native paired events are other mouse button 3 with one click and own marker", {
        let pair = SyntheticSideButtonEvents.make(buttonNumber: 3, at: CGPoint(x: 80, y: 40))!
        expectEqual(pair.down.type, .otherMouseDown); expectEqual(pair.up.type, .otherMouseUp)
        for event in [pair.down, pair.up] {
            expectEqual(event.getIntegerValueField(.mouseEventButtonNumber), 3)
            expectEqual(event.getIntegerValueField(.mouseEventClickState), 1)
            expectEqual(event.flags.rawValue, 0); expectEqual(event.location, CGPoint(x: 80, y: 40))
            expectTrue(MouseActionEventOrigin.isOwnSideButton(type: event.type, event: event))
        }
    }),
    ("Back native pair maps to NSEvent side button 3 rather than middle click", {
        let pair = SyntheticSideButtonEvents.make(buttonNumber: 3, at: .zero)!
        expectEqual(NSEvent(cgEvent: pair.down)?.buttonNumber, 3)
        expectEqual(NSEvent(cgEvent: pair.up)?.buttonNumber, 3)
        expectEqual(NSEvent(cgEvent: pair.down)?.type, .otherMouseDown)
        expectEqual(NSEvent(cgEvent: pair.up)?.type, .otherMouseUp)
        let copy = pair.down.copy()!
        expectTrue(MouseActionEventOrigin.isOwnSideButton(type: copy.type, event: copy))
    }),
    ("Back event source down or up allocation failures create no partial pair", {
        var sourceCalls = 0; var types: [CGEventType] = []
        let absentSource = SyntheticSideButtonEvents.make(buttonNumber: 3, at: .zero, sourceFactory: { sourceCalls += 1; return nil },
            eventFactory: { _, type, _ in types.append(type); return CGEvent(source: nil) })
        expectTrue(absentSource == nil); expectEqual(sourceCalls, 1); expectTrue(types.isEmpty)
        for failingType in [CGEventType.otherMouseDown, .otherMouseUp] {
            types.removeAll()
            let pair = SyntheticSideButtonEvents.make(buttonNumber: 3, at: .zero, eventFactory: { _, type, _ in
                types.append(type); return type == failingType ? nil : CGEvent(source: nil)
            })
            expectTrue(pair == nil)
            expectEqual(types, failingType == .otherMouseDown ? [.otherMouseDown] : [.otherMouseDown, .otherMouseUp])
        }
    }),
    ("Back native builder rejects primary buttons invalid numbers or coordinates", {
        var allocations = 0
        for number in [-1, 0, 1, 2, 32] {
            expectTrue(SyntheticSideButtonEvents.make(buttonNumber: number, at: .zero,
                sourceFactory: { allocations += 1; return CGEventSource(stateID: .privateState) }) == nil)
        }
        expectTrue(SyntheticSideButtonEvents.make(buttonNumber: 3, at: CGPoint(x: Double.nan, y: 0),
            sourceFactory: { allocations += 1; return CGEventSource(stateID: .privateState) }) == nil)
        expectEqual(allocations, 0)
    }),
    ("Back action submits one paired down and up without keyboard or motion", {
        let f = BackFixture(); expectEqual(f.action.execute(button: 4), .success)
        expectEqual(f.posted.map(\.type), [.otherMouseDown, .otherMouseUp]); expectEqual(f.allocations, 1)
        expectEqual(f.action.lastResult, .success)
    }),
    ("Back action preserves negative global monitor coordinates", {
        let f = BackFixture(); f.point = CGPoint(x: -1920, y: -40)
        expectEqual(f.action.execute(), .success)
        expectTrue(f.posted.allSatisfy { $0.location == f.point })
    }),
    ("Back action permission denial and missing application post nothing", {
        let denied = BackFixture(); denied.permission = false
        expectEqual(denied.action.execute(), .permissionDenied); expectEqual(denied.allocations, 0); expectTrue(denied.posted.isEmpty)
        let absent = BackFixture(); absent.applicationExists = false
        expectEqual(absent.action.execute(), .noFrontmostApplication); expectEqual(absent.allocations, 0); expectTrue(absent.posted.isEmpty)
    }),
    ("Back action unavailable or invalid pointer fails before allocating", {
        for point in [nil, CGPoint(x: Double.infinity, y: 0), CGPoint(x: 0, y: Double.nan)] as [CGPoint?] {
            let f = BackFixture(); f.point = point
            expectEqual(f.action.execute(), .unknownFailure); expectEqual(f.allocations, 0); expectTrue(f.posted.isEmpty)
        }
    }),
    ("Back action pair allocation failure cannot leave a mouse down", {
        let f = BackFixture(); f.allocationFails = true
        expectEqual(f.action.execute(), .eventPostFailed); expectTrue(f.posted.isEmpty)
    }),
    ("Back action permission loss or application change before posting cancels safely", {
        let permission = BackFixture(); permission.losePermission = true
        expectEqual(permission.action.execute(), .permissionDenied); expectTrue(permission.posted.isEmpty)
        let app = BackFixture(); app.changeApplication = true
        expectEqual(app.action.execute(), .cancelled); expectTrue(app.posted.isEmpty)
    }),
    ("Back action down failure submits only one best effort release", {
        let f = BackFixture(); f.failType = .otherMouseDown
        expectEqual(f.action.execute(), .eventPostFailed)
        expectEqual(f.posted.map(\.type), [.otherMouseDown, .otherMouseUp])
        expectTrue(f.messages.contains { $0.contains("bestEffortReleaseSubmitted=true") })
    }),
    ("Back action up failure does not retry and potentially navigate twice", {
        let f = BackFixture(); f.failType = .otherMouseUp
        expectEqual(f.action.execute(), .eventPostFailed); expectEqual(f.posted.map(\.type), [.otherMouseDown, .otherMouseUp])
        expectTrue(f.messages.contains { $0.contains("mouse up submission failed; no retry") })
    }),
    ("Back tagged pair passes configured mailbox without wake counters or click records", {
        let box = InputMailbox(buttons: [3, 4], gesture: true, freeze: true); var wakes = 0
        box.wake = { wakes += 1 }
        let pair = SyntheticSideButtonEvents.make(buttonNumber: 3, at: .zero)!
        for _ in 0..<1000 {
            expectFalse(box.capture(type: .otherMouseDown, event: pair.down, receivedAt: 1))
            expectFalse(box.capture(type: .otherMouseUp, event: pair.up, receivedAt: 1.01))
        }
        expectTrue(box.drain().isEmpty); expectEqual(wakes, 0)
        expectEqual(box.counts().rawMouseEvents, 0); expectEqual(box.counts().button4Downs, 0)
        expectFalse(box.capture(type: .mouseMoved, event: sideEvent(.mouseMoved), receivedAt: 2))
    }),
    ("Back physical side buttons and third party source tags retain original interception", {
        for button in [3, 4] {
            for externalTag in [Int64(0), MouseActionEventOrigin.marker + 1] {
                let box = InputMailbox(buttons: [3, 4], gesture: true, freeze: true)
                let down = sideEvent(.otherMouseDown, button: button); down.setIntegerValueField(.eventSourceUserData, value: externalTag)
                let up = sideEvent(.otherMouseUp, button: button); up.setIntegerValueField(.eventSourceUserData, value: externalTag)
                expectTrue(box.capture(type: .otherMouseDown, event: down, receivedAt: 1))
                expectTrue(box.capture(type: .otherMouseUp, event: up, receivedAt: 1.01))
                expectEqual(box.drain().count, 4); expectEqual(box.counts().rawMouseEvents, 2)
            }
        }
    }),
    ("Back tagged release never clears physical held state for either side button", {
        for held in [3, 4] {
            let box = InputMailbox(buttons: [3, 4], gesture: true, freeze: true)
            expectTrue(box.capture(type: .otherMouseDown, event: sideEvent(.otherMouseDown, button: held), receivedAt: 1))
            _ = box.drain()
            expectFalse(box.capture(type: .otherMouseDown, event: sideEvent(.otherMouseDown, marked: true), receivedAt: 1.01))
            expectFalse(box.capture(type: .otherMouseUp, event: sideEvent(.otherMouseUp, marked: true), receivedAt: 1.02))
            expectTrue(box.capture(type: .otherMouseDragged, event: sideEvent(.otherMouseDragged, button: held), receivedAt: 1.03))
            expectTrue(box.capture(type: .otherMouseUp, event: sideEvent(.otherMouseUp, button: held), receivedAt: 1.04))
            let records = box.drain(); expectEqual(records.count, 3)
            if case .modifier(false, _) = records.last {} else { expectTrue(false, "physical release must still end original hold") }
        }
    }),
    ("Back tagged release cannot lift physical tap recovery quarantine", {
        let box = InputMailbox(buttons: [3, 4], gesture: true, freeze: true)
        _ = box.capture(type: .otherMouseDown, event: sideEvent(.otherMouseDown), receivedAt: 1); _ = box.drain()
        box.interruptForTapRecovery("test"); _ = box.drain(); expectTrue(box.resumeAfterTapRecovery())
        expectFalse(box.capture(type: .otherMouseUp, event: sideEvent(.otherMouseUp, marked: true), receivedAt: 1.01))
        expectFalse(box.capture(type: .otherMouseDown, event: sideEvent(.otherMouseDown), receivedAt: 1.02))
        expectFalse(box.capture(type: .otherMouseUp, event: sideEvent(.otherMouseUp), receivedAt: 1.03))
        expectTrue(box.capture(type: .otherMouseDown, event: sideEvent(.otherMouseDown), receivedAt: 1.04))
    }),
    ("Back origin filter does not alter Escape or other event-type behavior", {
        let box = InputMailbox(buttons: [3], gesture: true, freeze: true)
        _ = box.capture(type: .otherMouseDown, event: sideEvent(.otherMouseDown)); _ = box.drain()
        let escape = CGEvent(source: nil)!; escape.type = .keyDown
        escape.setIntegerValueField(.keyboardEventKeycode, value: 53); MouseActionEventOrigin.mark(escape)
        expectFalse(MouseActionEventOrigin.isOwnSideButton(type: .keyDown, event: escape))
        expectFalse(box.capture(type: .keyDown, event: escape))
        if case .cancel("Escape") = box.drain().last {} else { expectTrue(false, "Escape must retain existing cancellation") }
    }),
    ("Back actual click pipeline rejects no physical clicks and creates no recursive action", {
        let box = InputMailbox(buttons: [3, 4], gesture: true, freeze: true)
        var machine = GestureMachine(); var clicks = SideButtonClickTracker(); var actions = 0
        for button in [3, 4] {
            _ = box.capture(type: .otherMouseDown, event: sideEvent(.otherMouseDown, button: button), receivedAt: 1)
            _ = box.capture(type: .otherMouseUp, event: sideEvent(.otherMouseUp, button: button), receivedAt: 1.01)
            for record in box.drain() {
                switch record {
                case .button(let number, true, _): clicks.down(number, machine: machine)
                case .button(let number, false, _):
                    clicks.observe(machine)
                    if clicks.up(number) {
                        actions += 1
                        let pair = SyntheticSideButtonEvents.make(buttonNumber: 3, at: .zero)!
                        expectFalse(box.capture(type: .otherMouseDown, event: pair.down)); expectFalse(box.capture(type: .otherMouseUp, event: pair.up))
                    }
                case .modifier(true, let time): machine.down(at: time)
                case .modifier(false, let time): _ = machine.finish(at: time)
                default: break
                }
            }
            expectTrue(box.drain().isEmpty); expectTrue(clicks.states.isEmpty); expectEqual(machine.state, .idle)
        }
        expectEqual(actions, 2)
    }),
    ("Back diagnostics identify native path button app and submission-only result", {
        let f = BackFixture(); _ = f.action.execute(button: 5)
        expectTrue(f.messages.contains { $0.contains("button=5 action=back executor=nativeMouse-button3 frontmost=test.frontmost stage=request") })
        expectTrue(f.messages.contains { $0.contains("result=success") && $0.contains("application handling/history requires real-device acceptance") })
        expectFalse(f.messages.contains { $0.contains("title=") || $0.contains("url=") })
    }),
    ("Back executor routes native mouse outcome without keyboard fallback", {
        let f = BackFixture(); var keys = 0
        let executor = MouseButtonActionExecutor(verticalAvailable: { true }, postVertical: { _ in true },
            postKeyboard: { _, _ in keys += 1; return true }, backMouse: f.action)
        expectTrue(executor.execute(ButtonClickConfiguration(action: .back), button: 4)); expectEqual(keys, 0)
        expectEqual(f.posted.count, 2); f.allocationFails = true
        expectFalse(executor.execute(ButtonClickConfiguration(action: .back), button: 5)); expectEqual(keys, 0)
    })
]
