import Foundation
import CoreGraphics
import GestureCore

final class ShortClickTests {
    var machine: GestureMachine
    var clicks = SideButtonClickTracker()
    init() { var config = GestureConfig(); config.verticalEnabled = true; machine = GestureMachine(config: config) }
    func down(_ button: Int) { clicks.down(button, machine: machine); machine.down(at: 1) }
    func move(_ x: Double, _ y: Double = 0) { machine.move(dx: x, dy: y, at: 1.1); clicks.observe(machine) }
    func up(_ button: Int) -> Bool { clicks.observe(machine); return clicks.up(button) }
    func jitter() { down(3); move(3, 2); expectTrue(up(3)); expectTrue(machine.finish(at: 1.2).isEmpty) }
    func threshold() { down(3); move(8); expectFalse(up(3)); expectEqual(machine.finish(at: 1.2).first?.phase, .began) }
    func reverse() { down(3); move(10); move(-10); expectFalse(up(3)) }
    func started() { down(3); move(20); _ = machine.frame(at: 1.15); move(-20); expectFalse(up(3)) }
    func cancel() { down(3); move(20); _ = machine.finish(at: 1.2, cancel: true); clicks.reset(); expectFalse(up(3)) }
    func pendingCancel() { down(3); clicks.reset(); expectFalse(up(3)); expectTrue(clicks.states.isEmpty) }
    func independent() { down(3); down(4); expectTrue(up(3)); expectEqual(clicks.states[4], .pendingClick); expectTrue(up(4)) }
    func overlap() { down(3); down(4); move(10); expectFalse(up(3)); expectFalse(up(4)) }
    func joinGesture() { down(3); move(10); down(4); expectFalse(up(4)); expectFalse(up(3)) }
    func repeated() {
        for button in (0..<100).map({ $0 % 2 == 0 ? 3 : 4 }) {
            down(button); expectTrue(up(button)); _ = machine.finish(at: 1.2); expectTrue(clicks.states.isEmpty)
        }
    }
    func duplicates() { expectFalse(up(3)); down(3); down(3); expectTrue(up(3)); expectFalse(up(3)) }
    func vertical(_ y: Double) { down(3); move(0, y); expectFalse(up(3)); _ = machine.frame(at: 1.2); expectEqual(machine.state, .vertical) }
    func customThreshold() { var c = GestureConfig(); c.deadZone = 17; machine = GestureMachine(config: c); down(3); move(16); expectTrue(up(3)) }
    func rejected() { machine = GestureMachine(); down(3); move(0, 20); _ = machine.frame(at: 1.2); expectEqual(machine.state, .rejectedVertical); expectFalse(up(3)) }
    static func withStore(_ body: (ConfigStore, UserDefaults) -> Void) {
        let name = "local.macmousegesture.shortclick.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        body(ConfigStore(defaults: defaults), defaults)
    }
    static func persisted() {
        withStore { store, _ in
            var config = AppConfig()
            config.button4ClickAction = ButtonClickConfiguration(action: .showDesktop)
            config.button5ClickAction = ButtonClickConfiguration(action: .customShortcut,
                shortcut: KeyboardShortcut(keyCode: 13, modifierFlags: CGEventFlags.maskCommand.rawValue))
            store.save(config); expectEqual(store.load(), config)
        }
    }
    static func legacy() {
        withStore { store, defaults in
            defaults.set(["sensitivity": 900, "deadZone": 19], forKey: ConfigStore.key)
            let config = store.load(); expectEqual(config.sensitivity, 900); expectEqual(config.deadZone, 19)
            expectEqual(config.button4ClickAction.action, .none); expectEqual(config.button5ClickAction.action, .none)
        }
    }
    static func unknown() {
        expectEqual(ButtonClickConfiguration(values: ["action": "futureAction"]).action, .none)
        expectEqual(ButtonClickConfiguration(values: ["action": "customShortcut", "keyCode": true, "modifierFlags": 0]).action, .none)
        expectEqual(ButtonClickConfiguration(values: ["action": "customShortcut", "keyCode": 13.5, "modifierFlags": 0]).action, .none)
    }
    static func clear() {
        withStore { store, _ in
            var config = AppConfig(); config.button4ClickAction = ButtonClickConfiguration(action: .customShortcut,
                shortcut: KeyboardShortcut(keyCode: 13, modifierFlags: CGEventFlags.maskCommand.rawValue))
            store.save(config); config.button4ClickAction = ButtonClickConfiguration(); store.save(config)
            expectEqual(store.load().button4ClickAction, ButtonClickConfiguration())
        }
    }
    static func mappings() {
        var observed: [(UInt16, UInt64)] = []; var mediaCount = 0; var frames: [GestureFrame] = []
        var time = 10.0
        let mission = MissionControlAction(queue: DispatchQueue(label: "tests.mapping"), clock: { time },
            permissionGranted: { true }, verticalAvailable: { true }, frontmostApplication: { "test.app" },
            postVertical: { frames.append($0); return true }, automaticScheduling: false)
        let expose = AppExposeAction(queue: DispatchQueue(label: "tests.exposeMapping"), clock: { time },
            permissionGranted: { true }, inspectTarget: { AppExposeTarget(application: "test.app", result: .success, reason: "AX window") },
            systemEnabled: { true }, verticalAvailable: { true },
            postVertical: { frames.append($0); return true }, automaticScheduling: false)
        let executor = MouseButtonActionExecutor(verticalAvailable: { true }, postVertical: { frames.append($0); return true },
            postKeyboard: { observed.append(($0, $1.rawValue)); return true }, postMedia: { mediaCount += 1; return true }, systemHotKeys: { [:] }, missionControl: mission, appExpose: expose)
        let expected: [(MouseButtonAction, UInt16, CGEventFlags)] = [(.showDesktop, 103, .maskSecondaryFn), (.launchpad, 118, []),
            (.lockScreen, 12, [.maskCommand, .maskControl]), (.forward, 30, .maskCommand)]
        for (action, key, flags) in expected {
            expectTrue(executor.execute(ButtonClickConfiguration(action: action)))
            expectEqual(observed.last?.0, key); expectEqual(observed.last?.1, flags.rawValue)
        }
        let shortcut = KeyboardShortcut(keyCode: 20, modifierFlags: CGEventFlags([.maskCommand, .maskShift]).rawValue)!
        expectTrue(executor.execute(ButtonClickConfiguration(action: .customShortcut, shortcut: shortcut)))
        expectEqual(observed.last?.0, 20); expectEqual(observed.last?.1, shortcut.modifierFlags)
        let count = observed.count
        expectTrue(executor.execute(ButtonClickConfiguration())); expectEqual(observed.count, count)
        expectTrue(executor.execute(ButtonClickConfiguration(action: .playPause))); expectEqual(mediaCount, 1)
        frames.removeAll()
        expectTrue(executor.execute(ButtonClickConfiguration(action: .missionControl)))
        expectEqual(frames.map(\.phase), [.began])
        time += 0.05; mission.advance(); time += 0.2; mission.advance()
        expectEqual(frames.map(\.phase), [.began, .changed, .changed, .ended])
        expectEqual(frames.last?.progress, 1)
        for (action, progress) in [(MouseButtonAction.appExpose, -1.0)] {
            frames.removeAll(); expectTrue(executor.execute(ButtonClickConfiguration(action: action)))
            expectEqual(frames.map(\.phase), [.began])
            time += 0.05; expose.advance(); time += 0.2; expose.advance()
            expectEqual(frames.map(\.phase), [.began, .changed, .changed, .ended]); expectEqual(frames.last?.progress, progress)
        }
    }
    static func failure() {
        var frames: [GestureFrame] = []
        let mission = MissionControlAction(queue: DispatchQueue(label: "tests.failure"), permissionGranted: { true },
            verticalAvailable: { true }, frontmostApplication: { "test.app" },
            postVertical: { frames.append($0); return $0.phase == .cancelled }, automaticScheduling: false)
        let executor = MouseButtonActionExecutor(verticalAvailable: { true }, postVertical: { frames.append($0); return $0.phase == .cancelled },
            postKeyboard: { _, _ in false }, postMedia: { false }, missionControl: mission)
        expectFalse(executor.execute(ButtonClickConfiguration(action: .missionControl)))
        expectEqual(frames.map(\.phase), [.began, .cancelled])
        expectFalse(executor.execute(ButtonClickConfiguration(action: .forward)))
    }
    static func pipeline() {
        let mailbox = InputMailbox(buttons: [3, 4], gesture: true, freeze: true)
        for button in [3, 4] {
            let suite = ShortClickTests()
            func edge(_ down: Bool) {
                let event = CGEvent(mouseEventSource: nil, mouseType: down ? .otherMouseDown : .otherMouseUp,
                    mouseCursorPosition: .zero, mouseButton: .center)!
                event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button))
                expectTrue(mailbox.capture(type: down ? .otherMouseDown : .otherMouseUp, event: event))
            }
            edge(true); edge(false)
            var clickCount = 0
            for record in mailbox.drain() {
                switch record {
                case .button(let number, let down, _):
                    if down { suite.clicks.down(number, machine: suite.machine) }
                    else { suite.clicks.observe(suite.machine); if suite.clicks.up(number) { clickCount += 1 } }
                case .modifier(let down, let time):
                    if down { suite.machine.down(at: time) } else { _ = suite.machine.finish(at: time) }
                default: break
                }
            }
            expectEqual(clickCount, 1); expectTrue(suite.clicks.states.isEmpty); expectEqual(suite.machine.state, .idle)
        }
    }
}

let shortClickChecks: [(String, () throws -> Void)] = [
    ("click button4 down/up", { let s = ShortClickTests(); s.down(3); expectTrue(s.up(3)) }),
    ("click button5 down/up", { let s = ShortClickTests(); s.down(4); expectTrue(s.up(4)) }),
    ("click small jitter", { ShortClickTests().jitter() }),
    ("click exact existing threshold suppresses", { ShortClickTests().threshold() }),
    ("click crossing then reversal stays suppressed", { ShortClickTests().reverse() }),
    ("click started gesture suppressed", { ShortClickTests().started() }),
    ("click cancelled gesture suppressed", { ShortClickTests().cancel() }),
    ("click focus/stop pending reset", { ShortClickTests().pendingCancel() }),
    ("click independent buttons", { ShortClickTests().independent() }),
    ("click overlapping gesture buttons", { ShortClickTests().overlap() }),
    ("click button joins active gesture", { ShortClickTests().joinGesture() }),
    ("click 100 rapid cycles reset", { ShortClickTests().repeated() }),
    ("click duplicate/unmatched edges", { ShortClickTests().duplicates() }),
    ("click upward gesture suppressed", { ShortClickTests().vertical(-20) }),
    ("click downward gesture suppressed", { ShortClickTests().vertical(20) }),
    ("click uses configured existing threshold", { ShortClickTests().customThreshold() }),
    ("click disabled vertical still suppresses", { ShortClickTests().rejected() }),
    ("click independent configuration roundtrip", ShortClickTests.persisted),
    ("click legacy configuration defaults none", ShortClickTests.legacy),
    ("click unknown and malformed action fallback", ShortClickTests.unknown),
    ("shortcut keyCode preserved", { expectEqual(KeyboardShortcut(keyCode: 13, modifierFlags: 0)?.keyCode, 13) }),
    ("shortcut command flag preserved", { expectEqual(KeyboardShortcut(keyCode: 13, modifierFlags: CGEventFlags.maskCommand.rawValue)?.modifierFlags, CGEventFlags.maskCommand.rawValue) }),
    ("shortcut all modifiers preserved", { expectEqual(KeyboardShortcut(keyCode: 20, modifierFlags: KeyboardShortcut.modifierMask)?.modifierFlags, KeyboardShortcut.modifierMask) }),
    ("shortcut pure modifiers rejected", { for key in [54,55,56,57,58,59,60,61,62,63] { expectEqual(KeyboardShortcut(keyCode: UInt16(key), modifierFlags: 0), nil) } }),
    ("shortcut unsupported flags stripped", { expectEqual(KeyboardShortcut(keyCode: 13, modifierFlags: UInt64.max)?.modifierFlags, KeyboardShortcut.modifierMask) }),
    ("shortcut clearing persists", ShortClickTests.clear),
    ("actions mapped with intercepted OS boundary", ShortClickTests.mappings),
    ("action failure attempts terminal cancellation", ShortClickTests.failure),
    ("click mailbox ordered integration", ShortClickTests.pipeline),
    ("system shortcut respects customized binding", {
        let values: [String: Any] = ["36": ["enabled": true, "value": ["type": "standard", "parameters": [100, 2, 1048576]]]]
        expectEqual(MouseButtonActionExecutor.systemShortcut(.showDesktop, values: values), SystemKeyBinding(keyCode: 2, modifierFlags: 1048576))
    }),
    ("system shortcut disabled or corrupt safely fails", {
        expectEqual(MouseButtonActionExecutor.systemShortcut(.launchpad, values: ["160": ["enabled": false]]), nil)
        expectEqual(MouseButtonActionExecutor.systemShortcut(.showDesktop, values: ["36": ["value": ["type": "standard", "parameters": [0, 65535, 0]]]]), nil)
    }),
    ("desktop fallback matches real-device WindowServer binding", {
        // Captured on the acceptance Mac: hotkey 36 enabled, key=103, flags=0x800000.
        var posted: [SystemKeyBinding] = []
        let executor = MouseButtonActionExecutor(verticalAvailable: { false }, postVertical: { _ in false },
            postKeyboard: { posted.append(SystemKeyBinding(keyCode: $0, modifierFlags: $1.rawValue)); return true },
            systemHotKeys: { [:] })
        expectTrue(executor.execute(ButtonClickConfiguration(action: .showDesktop)))
        expectEqual(posted, [SystemKeyBinding(keyCode: 103, modifierFlags: 0x800000)])
    }),
    ("desktop explicit binding retains its own modifiers", {
        for flags: UInt64 in [0, 1048576, 8388608, 9437184] {
            let values: [String: Any] = ["36": ["enabled": true, "value": ["type": "standard", "parameters": [65535, 103, flags]]]]
            expectEqual(MouseButtonActionExecutor.systemShortcut(.showDesktop, values: values),
                        SystemKeyBinding(keyCode: 103, modifierFlags: flags))
        }
    }),
    ("desktop diagnostics distinguish submitted from failed", {
        for succeeds in [true, false] {
            var messages: [String] = []
            let executor = MouseButtonActionExecutor(verticalAvailable: { false }, postVertical: { _ in false },
                postKeyboard: { _, _ in succeeds }, systemHotKeys: { [:] }, diagnostic: { messages.append($0) })
            expectEqual(executor.execute(ButtonClickConfiguration(action: .showDesktop)), succeeds)
            expectEqual(messages, ["Short-click system action=showDesktop keyCode=103 flags=8388608 submitted=\(succeeds)"])
        }
    })
]
