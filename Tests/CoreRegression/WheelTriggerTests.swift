import Foundation
import AppKit
import GestureCore

private final class WheelScheduler: LongPressScheduler {
    final class Ticket: LongPressCancellation {
        let at: Double; let action: () -> Void; var cancelled = false
        init(_ at: Double, _ action: @escaping () -> Void) { self.at = at; self.action = action }
        func cancel() { cancelled = true }
    }
    var now = 0.0
    var tickets: [Ticket] = []
    var activeCount: Int { tickets.filter { !$0.cancelled }.count }
    func schedule(at deadline: Double, _ action: @escaping () -> Void) -> LongPressCancellation {
        let ticket = Ticket(deadline, action); tickets.append(ticket); return ticket
    }
    func advance(_ time: Double) {
        now = time
        for ticket in tickets where !ticket.cancelled && ticket.at <= time { ticket.cancel(); ticket.action() }
    }
}
private let wheelA = MouseAction.keyboardShortcut(KeyboardShortcut(keyCode: 17, modifierFlags: MouseModifiers.command.rawValue)!)
private let wheelB = MouseAction.keyboardShortcut(KeyboardShortcut(keyCode: 13, modifierFlags: MouseModifiers.command.rawValue)!)
private func wheelSample(_ delta: Double = 1, continuous: Bool = false, inverted: Bool = false, momentum: Bool = false) -> WheelScrollSample {
    .init(delta: delta, isContinuous: continuous, isDirectionInvertedFromDevice: inverted, isMomentum: momentum)
}
private func wheelRow(_ button: Int = 5, direction: MouseWheelDirection = .up, modifiers: MouseModifiers = [],
                      action: MouseAction = wheelA, enabled: Bool = true) -> MouseMapping {
    .init(input: .button(button), trigger: .wheel(direction, modifiers: modifiers), action: action, isEnabled: enabled)
}
private final class WheelHarness {
    let scheduler = WheelScheduler()
    lazy var presses = LongPressCoordinator(scheduler: scheduler)
    var longActions: [MouseAction] = []
    init() {
        presses.onDeadline = { [weak self] button, generation in
            guard let self, let action = self.presses.fire(button, generation: generation) else { return }
            self.longActions.append(action)
        }
    }
    func down(_ button: Int = 4, at time: Double = 0, modifiers: MouseModifiers = [], long: MouseAction? = .system(.showDesktop),
              wheel: [MouseWheelDirection: MouseAction] = [.up: wheelA, .down: wheelB]) {
        presses.down(button, at: time, modifiers: modifiers, action: long, wheelActions: wheel)
    }
    func scroll(_ delta: Double = 1, at time: Double = 0.2, continuous: Bool = false) -> WheelPressResolution {
        presses.wheel(wheelSample(delta, continuous: continuous), at: time)
    }
}
private func wheelCG(_ type: CGEventType, button: Int = 4, dx: Int64 = 0, flags: CGEventFlags = []) -> CGEvent {
    let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: .zero, mouseButton: .center)!
    event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button))
    event.setIntegerValueField(.mouseEventDeltaX, value: dx); event.flags = flags; return event
}
private func wheelScrollCG(_ delta: Int32 = 1, horizontal: Int32 = 0, continuous: Bool = false) -> CGEvent {
    CGEvent(scrollWheelEvent2Source: nil, units: continuous ? .pixel : .line, wheelCount: 2, wheel1: delta, wheel2: horizontal, wheel3: 0)!
}
// Integrates production mailbox + coordinator + ORIGINAL trackers/machine. No real
// wheel timing or action posting; injected samples test inversion independently of OS preferences.
private final class WheelPipeline {
    let scheduler = WheelScheduler()
    lazy var presses = LongPressCoordinator(scheduler: scheduler)
    let mappings: MouseMappingStore
    let box: InputMailbox
    var machine = GestureMachine()
    var clicks = SideButtonClickTracker()
    var contexts = MousePressContexts()
    var actions: [MouseAction] = []
    var sample = wheelSample()
    init(_ rows: [MouseMapping] = [wheelRow(), wheelRow(direction: .down, action: wheelB)]) {
        mappings = MouseMappingStore(mappings: rows)
        box = InputMailbox(buttons: [3,4], gesture: true, freeze: true, wheelButtons: mappings.wheelCGButtons)
        box.wheelCapture = { [weak self] _, time in
            guard let self else { return false }; self.drain()
            let result = self.presses.wheel(self.sample, at: time)
            if result.newlyClaimed, let number = result.button {
                _ = self.clicks.up(number)
                if self.box.retirePressDriver(number, at: time) { _ = self.machine.finish(at: time) }
            }
            if let action = result.action { self.actions.append(action) }
            return result.consumed
        }
    }
    func down(_ button: Int = 4, at time: Double = 0, flags: CGEventFlags = []) {
        _ = box.capture(type: .otherMouseDown, event: wheelCG(.otherMouseDown, button: button, flags: flags), receivedAt: time)
    }
    func move(_ dx: Int64, at time: Double = 0.1) {
        _ = box.capture(type: .otherMouseDragged, event: wheelCG(.otherMouseDragged, dx: dx), receivedAt: time)
    }
    func up(_ button: Int = 4, at time: Double = 0.4) {
        _ = box.capture(type: .otherMouseUp, event: wheelCG(.otherMouseUp, button: button), receivedAt: time); drain()
    }
    func scroll(_ delta: Double = 1, at time: Double = 0.2) -> Bool {
        sample = wheelSample(delta)
        return box.capture(type: .scrollWheel, event: wheelScrollCG(delta >= 0 ? 1 : -1), receivedAt: time)
    }
    func drain() {
        for record in box.drain() {
            switch record {
            case .buttonContext(let button, let flags): contexts.down(button, modifiers: flags)
            case .button(let button, let down, let time):
                guard box.buttons.contains(button) else { continue }
                if down {
                    contexts.down(button); clicks.down(button, machine: machine)
                    let flags = contexts.values[button] ?? []
                    presses.down(button, at: time, modifiers: flags, action: mappings.longPressAction(for: .button(button+1), modifiers: flags),
                                 dragClaimed: clicks.states[button] == .gestureStarted, wheelActions: mappings.wheelActions(for: .button(button+1), modifiers: flags))
                } else {
                    let flags = contexts.up(button); clicks.observe(machine)
                    presses.observeDrag(Set(clicks.states.filter { $0.value == .gestureStarted }.keys))
                    let result = presses.release(button, at: time)
                    if clicks.up(button) && result == .shortPressAllowed,
                       let action = mappings.shortPressAction(for: .button(button+1), modifiers: flags) { actions.append(action) }
                }
            case .modifier(let down, let time):
                if down { machine.down(at: time) } else { _ = machine.finish(at: time) }
            case .motion(let x, let y, let time, let count):
                if !presses.isActive || !clicks.states.isEmpty { machine.move(dx: x, dy: y, at: time, count: count) }
                clicks.observe(machine); presses.observeDrag(Set(clicks.states.filter { $0.value == .gestureStarted }.keys))
            case .cancel, .tapDisabled: presses.reset(); clicks.reset(); contexts.reset(); _ = machine.finish(at: 1, cancel: true)
            default: break
            }
        }
    }
}

let wheelTriggerChecks: [(String, () throws -> Void)] = [
    ("wheel up claims and executes exactly one action", {
        let h = WheelHarness(); h.down(); let r = h.scroll()
        expectTrue(r.consumed); expectTrue(r.newlyClaimed); expectEqual(r.action, wheelA); expectEqual(h.presses.claim(for: 4), .wheel)
    }),
    ("wheel down resolves distinct action", {
        let h = WheelHarness(); h.down(); expectEqual(h.scroll(-1).action, wheelB)
    }),
    ("wheel repeats three clear discrete detents", {
        let h = WheelHarness(); h.down()
        expectEqual([0.1,0.2,0.3].compactMap { h.scroll(at: $0).action }, [wheelA,wheelA,wheelA])
    }),
    ("wheel reverse direction stays in same family", {
        let h = WheelHarness(); h.down(); _ = h.scroll()
        let r = h.scroll(-1, at: 0.3); expectEqual(r.action, wheelB); expectFalse(r.newlyClaimed); expectEqual(h.presses.claim(for: 4), .wheel)
    }),
    ("wheel release suppresses short and ends owner", {
        let h = WheelHarness(); h.down(); _ = h.scroll()
        expectEqual(h.presses.release(4, at: 0.3), .suppressed); expectEqual(h.scroll(at: 0.4), .pass); expectFalse(h.presses.isActive)
    }),
    ("wheel fresh press restores short eligibility", {
        let h = WheelHarness(); h.down(); _ = h.scroll(); _ = h.presses.release(4, at: 0.3)
        h.down(at: 1); expectEqual(h.presses.release(4, at: 1.1), .shortPressAllowed)
    }),
    ("wheel absent preserves immediate short", {
        let h = WheelHarness(); h.down(); expectEqual(h.presses.release(4, at: 0.1), .shortPressAllowed)
    }),
    ("wheel long first passes subsequent scroll", {
        let h = WheelHarness(); h.down(); h.scheduler.advance(0.5)
        expectEqual(h.scroll(at: 0.6), .pass); expectEqual(h.presses.claim(for: 4), .longPress); expectEqual(h.longActions.count, 1)
    }),
    ("wheel first cancels long timer and stale callback", {
        let h = WheelHarness(); h.down(); let stale = h.scheduler.tickets[0]; _ = h.scroll()
        h.scheduler.advance(1); stale.action(); expectTrue(h.longActions.isEmpty); expectEqual(h.scheduler.activeCount, 0)
    }),
    ("wheel drag first passes scroll and suppresses short", {
        let h = WheelHarness(); h.down(); h.presses.observeDrag([4]); expectEqual(h.scroll(), .pass)
        expectEqual(h.presses.release(4, at: 0.3), .suppressed)
    }),
    ("wheel claim cannot turn into drag after later movement", {
        let h = WheelHarness(); h.down(); _ = h.scroll(); h.presses.observeDrag([4])
        expectEqual(h.presses.claim(for: 4), .wheel); expectEqual(h.scroll(at: 0.3).action, wheelA)
    }),
    ("wheel only has no long timer even after deadline", {
        let h = WheelHarness(); h.down(long: nil); expectEqual(h.scheduler.activeCount, 0)
        expectEqual(h.scroll(at: 2).action, wheelA); expectEqual(h.presses.release(4, at: 3), .suppressed)
    }),
    ("wheel only pending release remains short after 500ms", {
        let h = WheelHarness(); h.down(long: nil); expectEqual(h.presses.release(4, at: 1), .shortPressAllowed)
    }),
    ("wheel no physical press passes", { expectEqual(WheelHarness().scroll(), .pass) }),
    ("wheel held long-only button passes", {
        let h = WheelHarness(); h.down(wheel: [:]); expectEqual(h.scroll(), .pass); expectEqual(h.presses.claim(for: 4), .pending)
    }),
    ("wheel disabled or none directions create no candidate", {
        let h = WheelHarness(); h.down(long: nil, wheel: [.up: .none]); expectFalse(h.presses.isActive); expectEqual(h.scroll(), .pass)
    }),
    ("wheel unmapped reverse before claim passes", {
        let h = WheelHarness(); h.down(wheel: [.up: wheelA]); expectEqual(h.scroll(-1), .pass); expectEqual(h.presses.claim(for: 4), .pending)
    }),
    ("wheel unmapped reverse after claim consumes without action", {
        let h = WheelHarness(); h.down(wheel: [.up: wheelA]); _ = h.scroll(); let r = h.scroll(-1, at: 0.3)
        expectTrue(r.consumed); expectEqual(r.action, nil); expectEqual(h.presses.claim(for: 4), .wheel)
    }),
    ("wheel horizontal zero never claims or consumes", {
        let h = WheelHarness(); h.down(); expectEqual(h.scroll(0), .pass); _ = h.scroll(); expectEqual(h.scroll(0), .pass)
    }),
    ("wheel small continuous sample consumes but waits to claim", {
        let h = WheelHarness(); h.down(); let r = h.scroll(3, continuous: true)
        expectTrue(r.consumed); expectEqual(r.action, nil); expectEqual(h.presses.claim(for: 4), .pending); expectEqual(h.scheduler.activeCount, 1)
    }),
    ("wheel continuous threshold acquires and cancels timer", {
        let h = WheelHarness(); h.down(); _ = h.scroll(4, at: 0.1, continuous: true)
        expectEqual(h.scroll(6, continuous: true).action, wheelA); expectEqual(h.scheduler.activeCount, 0)
    }),
    ("wheel unmatched direction clears pre-claim remainder", {
        let h = WheelHarness(); h.down(wheel: [.up: wheelA]); _ = h.scroll(8, at: 0.1, continuous: true)
        expectEqual(h.scroll(-4, at: 0.2, continuous: true), .pass); expectEqual(h.scroll(3, at: 0.3, continuous: true).action, nil)
    }),
    ("wheel newest eligible button wins once", {
        let h = WheelHarness(); h.down(3); h.down(4, at: 0.1)
        expectEqual(h.scroll().button, 4); expectEqual(h.presses.claim(for: 3), .pending)
    }),
    ("wheel owner pinned against newer down", {
        let h = WheelHarness(); h.down(3); _ = h.scroll(); h.down(4, at: 0.25)
        expectEqual(h.scroll(at: 0.3).button, 3)
    }),
    ("wheel release owner lets remaining button acquire", {
        let h = WheelHarness(); h.down(3); h.down(4, at: 0.1); _ = h.scroll(); _ = h.presses.release(4, at: 0.3)
        let r = h.scroll(at: 0.4); expectEqual(r.button, 3); expectTrue(r.newlyClaimed)
    }),
    ("wheel releasing nonowner preserves owner", {
        let h = WheelHarness(); h.down(3); h.down(4); _ = h.scroll(); _ = h.presses.release(3, at: 0.3)
        expectEqual(h.scroll(at: 0.4).button, 4)
    }),
    ("wheel newest eligible missing direction does not fall back to older button", {
        let h = WheelHarness(); h.down(3); h.down(4, wheel: [.down: wheelB]); expectEqual(h.scroll(), .pass)
        expectEqual(h.scroll(-1, at: 0.3).button, 4)
    }),
    ("wheel newest ineligible button does not shadow eligible button", {
        let h = WheelHarness(); h.down(3); h.down(4, wheel: [:]); expectEqual(h.scroll().button, 3)
    }),
    ("wheel drag-owned newer button leaves older candidate", {
        let h = WheelHarness(); h.down(3); h.down(4); h.presses.observeDrag([4]); expectEqual(h.scroll().button, 3)
    }),
    ("wheel duplicate down does not update recency or frozen modifiers", {
        let h = WheelHarness(); h.down(3, modifiers: .command); h.down(4); h.down(3, at: 0.1)
        expectEqual(h.scroll().button, 4); expectEqual(h.presses.modifiers(for: 3), .command)
    }),
    ("wheel plain and command exact actions independent", {
        let store = MouseMappingStore(mappings: [wheelRow(),wheelRow(modifiers: .command, action: wheelB)])
        expectEqual(store.wheelActions(for: .button(5), modifiers: [])[.up], wheelA)
        expectEqual(store.wheelActions(for: .button(5), modifiers: .command)[.up], wheelB)
    }),
    ("wheel multiple modifiers exact, no subset or plain fallback", {
        let flags: MouseModifiers = [.command,.shift,.option]
        let store = MouseMappingStore(mappings: [wheelRow(),wheelRow(modifiers: flags)])
        expectEqual(store.wheelActions(for: .button(5), modifiers: flags)[.up], wheelA)
        expectTrue(store.wheelActions(for: .button(5), modifiers: .command).isEmpty)
    }),
    ("wheel disabled exact mapping cannot consume through fallback", {
        let store = MouseMappingStore(mappings: [wheelRow(),wheelRow(modifiers: .command, enabled: false)])
        expectTrue(store.wheelActions(for: .button(5), modifiers: .command).isEmpty)
    }),
    ("wheel action and modifiers frozen at down", {
        var store = MouseMappingStore(mappings: [wheelRow(modifiers: .command)])
        let h = WheelHarness(); h.down(modifiers: .command, wheel: store.wheelActions(for: .button(5), modifiers: .command))
        store.delete(store.mappings[0].id)
        expectEqual(h.scroll().action, wheelA); expectEqual(h.presses.modifiers(for: 4), .command)
    }),
    ("wheel normalizer discrete detent emits one", {
        var n = WheelStepNormalizer(); expectEqual(n.step(wheelSample(), at: 0), .up)
    }),
    ("wheel normalizer discrete accelerated value still one step", {
        var n = WheelStepNormalizer(); expectEqual(n.step(wheelSample(9), at: 0), .up); expectEqual(n.remainder, 0)
    }),
    ("wheel normalizer fractional discrete accumulation", {
        var n = WheelStepNormalizer(); expectEqual(n.step(wheelSample(0.4), at: 0), nil)
        expectEqual(n.step(wheelSample(0.6), at: 0.1), .up)
    }),
    ("wheel normalizer small continuous deltas reach injectable threshold", {
        var n = WheelStepNormalizer(configuration: .init(continuousThreshold: 6))
        expectEqual(n.step(wheelSample(2, continuous: true), at: 0), nil)
        expectEqual(n.step(wheelSample(2, continuous: true), at: 0.1), nil)
        expectEqual(n.step(wheelSample(2, continuous: true), at: 0.2), .up)
    }),
    ("wheel normalizer preserves remainder", {
        var n = WheelStepNormalizer(); expectEqual(n.step(wheelSample(12, continuous: true), at: 0), .up)
        expectEqual(n.remainder, 2); expectEqual(n.step(wheelSample(8, continuous: true), at: 0.1), .up)
    }),
    ("wheel normalizer huge delta has no full-step debt", {
        var n = WheelStepNormalizer(); expectEqual(n.step(wheelSample(10002, continuous: true), at: 0), .up)
        expectEqual(n.remainder, 2); expectEqual(n.step(wheelSample(1, continuous: true), at: 0.1), nil)
    }),
    ("wheel normalizer finite huge value cannot overflow", {
        var n = WheelStepNormalizer(); expectEqual(n.step(wheelSample(Double.greatestFiniteMagnitude, continuous: true), at: 0), .up)
        expectTrue(n.remainder.isFinite); expectTrue(n.remainder < 10)
    }),
    ("wheel normalizer reversal resets accumulation", {
        var n = WheelStepNormalizer(); _ = n.step(wheelSample(8, continuous: true), at: 0)
        expectEqual(n.step(wheelSample(-3, continuous: true), at: 0.1), nil); expectEqual(n.remainder, 3)
        expectEqual(n.step(wheelSample(-7, continuous: true), at: 0.2), .down)
    }),
    ("wheel normalizer changing event units resets accumulation", {
        var n = WheelStepNormalizer(); _ = n.step(wheelSample(8, continuous: true), at: 0)
        expectEqual(n.step(wheelSample(0.5), at: 0.1), nil); expectEqual(n.remainder, 0.5)
    }),
    ("wheel normalizer idle gap drops old remainder", {
        var n = WheelStepNormalizer(configuration: .init(accumulationIdleInterval: 0.2))
        _ = n.step(wheelSample(8, continuous: true), at: 0)
        expectEqual(n.step(wheelSample(3, continuous: true), at: 0.3), nil); expectEqual(n.remainder, 3)
    }),
    ("wheel normalizer rate cap drops excess with no timer replay", {
        var n = WheelStepNormalizer(); var steps = 0
        for i in 0..<20 { if n.step(wheelSample(1000), at: Double(i)*0.001) != nil { steps += 1 } }
        expectEqual(steps, 1); expectEqual(n.step(wheelSample(0), at: 1), nil)
        expectEqual(n.step(wheelSample(), at: 1.1), .up)
    }),
    ("wheel normalizer exact cooldown boundary emits", {
        var n = WheelStepNormalizer(); _ = n.step(wheelSample(), at: 0)
        expectEqual(n.step(wheelSample(), at: 0.039), nil); expectEqual(n.step(wheelSample(), at: 0.04), .up)
    }),
    ("wheel normalizer natural off positive is physical up", {
        var n = WheelStepNormalizer(); expectEqual(n.step(wheelSample(1), at: 0), .up)
    }),
    ("wheel normalizer natural on negative is same physical up", {
        var n = WheelStepNormalizer(); expectEqual(n.step(wheelSample(-1, inverted: true), at: 0), .up)
    }),
    ("wheel normalizer natural toggles keep physical down", {
        var n = WheelStepNormalizer(); expectEqual(n.step(wheelSample(-1), at: 0), .down)
        expectEqual(n.step(wheelSample(1, inverted: true), at: 0.1), .down)
    }),
    ("wheel normalizer momentum has no action or accumulation", {
        var n = WheelStepNormalizer(); expectEqual(n.step(wheelSample(100, momentum: true), at: 0), nil); expectEqual(n.remainder, 0)
    }),
    ("wheel momentum passes pending and consumes claimed without repeat", {
        let h = WheelHarness(); h.down(); expectEqual(h.presses.wheel(wheelSample(10, momentum: true), at: 0.1), .pass)
        _ = h.scroll(); let r = h.presses.wheel(wheelSample(10, momentum: true), at: 0.3)
        expectTrue(r.consumed); expectEqual(r.action, nil)
    }),
    ("wheel invalid delta or time never emits", {
        var n = WheelStepNormalizer()
        for delta in [Double.nan, .infinity, -.infinity, 0] { expectEqual(n.step(wheelSample(delta), at: 0), nil) }
        expectEqual(n.step(wheelSample(), at: .nan), nil)
    }),
    ("wheel invalid configuration uses central defaults", {
        let c = WheelStepConfiguration(continuousThreshold: .nan, minimumStepInterval: -1, accumulationIdleInterval: 0)
        expectEqual(c.continuousThreshold, WheelStepConfiguration.defaultContinuousThreshold)
        expectEqual(c.minimumStepInterval, WheelStepConfiguration.defaultMinimumStepInterval)
        expectEqual(c.accumulationIdleInterval, WheelStepConfiguration.defaultAccumulationIdleInterval)
    }),
    ("wheel Codable up down modifier round trips and titles", {
        for direction in MouseWheelDirection.allCases {
            for flags: MouseModifiers in [[], .command, [.command,.shift,.control,.option]] {
                let trigger = MouseTrigger.wheel(direction, modifiers: flags)
                expectEqual(try JSONDecoder().decode(MouseTrigger.self, from: JSONEncoder().encode(trigger)), trigger)
                expectEqual(trigger.base, .wheel(direction)); expectEqual(trigger.modifiers, flags); expectTrue(trigger.isButtonPress)
                expectFalse(trigger.title.contains("wheel"))
            }
        }
    }),
    ("wheel recorder preserves selected wheel family", {
        let recorded = RecordedMouseInput(button: MouseButtonIdentifier(rawValue: 7)!, modifiers: [.command,.shift])
        expectEqual(MouseTrigger.wheelDown.withModifiers(recorded.modifiers), .modifiedWheel(.down, [.command,.shift]))
        expectEqual(recorded.trigger.base, .shortPress)
    }),
    ("wheel display order short long wheel then drag", {
        let triggers: [MouseTrigger] = [.shortPress,.longPress,.wheelUp,.wheelDown,.drag(.left),.drag(.right),.drag(.up),.drag(.down)]
        expectEqual(triggers.map(\.displayOrder), Array(0...7)); expectEqual(MouseTrigger.drag(.left).order, 1)
    }),
    ("wheel v4 roundtrip and idempotent reencode", {
        let store = MouseMappingStore(mappings: [wheelRow(),wheelRow(direction: .down, modifiers: .command)])
        let data = try store.encoded(); let obj = try JSONSerialization.jsonObject(with: data) as! [String:Any]
        expectEqual(obj["version"] as? Int, 4); let loaded = try MouseMappingStore(data: data)
        expectEqual(loaded, store); expectEqual(try MouseMappingStore(data: loaded.encoded()), loaded)
    }),
    ("wheel reader still loads v1 v2 v3", {
        for row in [MouseMapping(input: .button(5), trigger: .shortPress, action: wheelA),
                    MouseMapping(input: .button(5), trigger: .shortPress(modifiers: .command), action: wheelA),
                    MouseMapping(input: .button(5), trigger: .longPress, action: wheelA)] {
            let store = MouseMappingStore(mappings: [row]); expectEqual(try MouseMappingStore(data: store.encoded()), store)
        }
    }),
    ("wheel future trigger and direction fail safely", {
        for json in [#"{"kind":"wheelFuture","direction":"up"}"#, #"{"kind":"wheel","direction":"left"}"#] {
            expectTrue((try? JSONDecoder().decode(MouseTrigger.self, from: Data(json.utf8))) == nil)
        }
    }),
    ("wheel cannot be encoded as older format", {
        let data = try MouseMappingStore(mappings: [wheelRow()]).encoded()
        var obj = try JSONSerialization.jsonObject(with: data) as! [String:Any]
        for version in [1,2,3,5] {
            obj["version"] = version; expectTrue((try? MouseMappingStore(data: JSONSerialization.data(withJSONObject: obj))) == nil)
        }
    }),
    ("wheel persistence preserves other mappings and settings", {
        let name = "local.macmousegesture.wheel.\(UUID())"; let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        var config = AppConfig(); config.deadZone = 13; config.horizontalInvert = false
        config.mappings += [wheelRow(),wheelRow(direction: .down),MouseMapping(input: .button(5),trigger: .longPress,action: wheelB)]
        let store = ConfigStore(defaults: defaults); store.save(config); expectEqual(store.load(), config.validated())
    }),
    ("wheel future document never falls back to legacy short", {
        let name = "local.macmousegesture.wheel.future.\(UUID())"; let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set([ConfigStore.mappingsKey: Data(#"{"version":99,"mappings":[]}"#.utf8),
                      "button5ClickAction": ButtonClickConfiguration(action: .showDesktop).values], forKey: ConfigStore.key)
        expectEqual(ConfigStore(defaults: defaults).load().mappingStore.shortPressAction(for: .button(5), modifiers: []), nil)
    }),
    ("wheel duplicates keep existing editor and independent directions", {
        let row = wheelRow(); var store = MouseMappingStore(mappings: [row]); expectEqual(store.add(wheelRow()), row.id)
        expectTrue(store.add(wheelRow(direction: .down)) != nil); expectEqual(store.mappings.count, 2)
    }),
    ("wheel UI model edits disables deletes and service wheel-only eligibility", {
        var c = AppConfig(); c.horizontalEnabled = false; c.verticalEnabled = false; c.mappings = [wheelRow(8)]
        expectTrue(c.shouldRun); expectEqual(c.mappingStore.pressCGButtons, [7]); expectEqual(c.mappingStore.wheelCGButtons, [7])
        let model = AppViewModel(config: c); model.applyConfig = { next, _ in model.show(next) }
        let row = wheelRow(direction: .down); if case .saved = model.saveMapping(row) {} else { expectTrue(false) }
        model.setMappingEnabled(false, id: row.id); expectEqual(model.config.mappingStore.wheelActions(for: .button(5), modifiers: [])[.down], nil)
        model.deleteMapping(row.id); expectEqual(model.config.mappingStore.mapping(for: .button(5), trigger: .wheelDown), nil)
    }),
    ("wheel primary buttons remain protected", { expectTrue(MouseMappingStore(mappings: [wheelRow(1),wheelRow(2)]).mappings.isEmpty) }),
    ("wheel P0 no button ordinary wheel passes through mailbox", {
        let h = WheelPipeline(); expectFalse(h.scroll()); expectTrue(h.actions.isEmpty)
    }),
    ("wheel P0 held button without wheel mapping passes mailbox", {
        let h = WheelPipeline([]); h.down(); expectFalse(h.scroll()); expectTrue(h.actions.isEmpty)
    }),
    ("wheel mailbox mapped event consumes and release never short", {
        let short = MouseMapping(input: .button(5), trigger: .shortPress, action: .system(.showDesktop))
        let h = WheelPipeline([wheelRow(),short]); h.down(); expectTrue(h.scroll()); h.up(); expectEqual(h.actions, [wheelA])
        expectFalse(h.scroll(at: 0.5)); expectFalse(h.machine.active)
    }),
    ("wheel mailbox drains buffered small motion before claim", {
        let h = WheelPipeline(); h.down(); h.move(7); expectTrue(h.scroll()); expectEqual(h.actions, [wheelA])
    }),
    ("wheel mailbox drains deadZone crossing before wheel", {
        let h = WheelPipeline(); h.down(); h.move(8); expectFalse(h.scroll()); expectTrue(h.actions.isEmpty)
        expectEqual(h.presses.claim(for: 4), .drag)
    }),
    ("wheel mailbox claimed later motion never begins gesture", {
        let h = WheelPipeline(); h.down(); expectTrue(h.scroll()); h.move(200, at: 0.3); h.drain()
        expectTrue(h.machine.frame(at: 0.4).isEmpty); expectFalse(h.machine.active); expectEqual(h.presses.claim(for: 4), .wheel)
    }),
    ("wheel mailbox reverse unmapped is consumed only after first match", {
        let h = WheelPipeline([wheelRow()]); h.down(); expectFalse(h.scroll(-1)); expectTrue(h.scroll(at: 0.3))
        expectTrue(h.scroll(-1, at: 0.4)); expectEqual(h.actions, [wheelA])
    }),
    ("wheel mailbox horizontal-only scroll passes", {
        let h = WheelPipeline(); h.down(); h.sample = wheelSample(0)
        expectFalse(h.box.capture(type: .scrollWheel, event: wheelScrollCG(0, horizontal: 5), receivedAt: 0.2))
        expectEqual(h.presses.claim(for: 4), .pending)
    }),
    ("wheel mailbox frozen command survives key release", {
        let h = WheelPipeline([wheelRow(modifiers: .command, action: wheelB)]); h.down(flags: .maskCommand)
        expectTrue(h.scroll()); expectEqual(h.actions, [wheelB]); expectEqual(h.presses.modifiers(for: 4), .command)
    }),
    ("wheel mailbox exact mismatched modifier passes", {
        let h = WheelPipeline([wheelRow(modifiers: .command)]); h.down(); expectFalse(h.scroll()); expectTrue(h.actions.isEmpty)
    }),
    ("wheel mailbox multiple held buttons only newest action", {
        let h = WheelPipeline([wheelRow(4),wheelRow(5, action: wheelB)]); h.down(3); h.down(4, at: 0.1)
        expectTrue(h.scroll()); expectEqual(h.actions, [wheelB]); h.up(4, at: 0.3)
        expectTrue(h.scroll(at: 0.4)); expectEqual(h.actions, [wheelB,wheelA])
    }),
    ("wheel mailbox retirement does not retire another drag driver", {
        let h = WheelPipeline([wheelRow(4),wheelRow(5)]); h.down(3); h.down(4); expectTrue(h.scroll())
        expectTrue(h.machine.active); h.move(20, at: 0.3); h.drain()
        expectEqual(h.presses.claim(for: 4), .wheel); expectEqual(h.presses.claim(for: 3), .drag)
    }),
    ("wheel AppKit adapter uses scrolling event metadata", {
        let event = wheelScrollCG(1); let ns = NSEvent(cgEvent: event)!
        let sample = WheelScrollSample(event: event)!
        expectEqual(sample.delta, Double(ns.scrollingDeltaY)); expectEqual(sample.isDirectionInvertedFromDevice, ns.isDirectionInvertedFromDevice)
        expectFalse(sample.isContinuous); expectTrue(WheelScrollSample(event: wheelCG(.otherMouseDown)) == nil)
    }),
    ("wheel AppKit pixel event detected as continuous", {
        let sample = WheelScrollSample(event: wheelScrollCG(3, continuous: true))!
        expectTrue(sample.isContinuous); expectTrue(sample.direction != nil)
    }),
    ("wheel handoff preceding input processed before decision", {
        let queue = DispatchQueue(label: "Wheel.test.resolve"); var prepared = false
        let handoff = WheelInputHandoff(queue: queue, prepare: { prepared = true }, resolve: { _, _ in prepared })
        expectTrue(handoff.capture(wheelSample(), at: 0)); queue.sync {}
    }),
    ("wheel handoff timeout revokes delayed claim and action", {
        let queue = DispatchQueue(label: "Wheel.test.blocked"); let unblock = DispatchSemaphore(value: 0)
        queue.async { unblock.wait() }; var resolved = 0
        let handoff = WheelInputHandoff(queue: queue, prepare: {}, resolve: { _, _ in resolved += 1; return true })
        expectFalse(handoff.capture(wheelSample(), at: 0)); unblock.signal(); queue.sync {}
        expectEqual(resolved, 0)
    }),
    ("wheel handoff prepare cancellation cannot resolve afterwards", {
        let queue = DispatchQueue(label: "Wheel.test.prepare"); let unblock = DispatchSemaphore(value: 0); var resolved = 0
        let handoff = WheelInputHandoff(queue: queue, prepare: { unblock.wait() }, resolve: { _, _ in resolved += 1; return true })
        expectFalse(handoff.capture(wheelSample(), at: 0)); unblock.signal(); queue.sync {}; expectEqual(resolved, 0)
    })
] + ["Escape", "recording", "service stop", "mapping disabled", "tap recovery", "permission lost"].map { reason in
    ("wheel cancellation never restores short or repeat: \(reason)", {
        let h = WheelHarness(); h.down(); _ = h.scroll(); h.presses.cancelAll()
        expectEqual(h.scroll(at: 0.3), .pass); expectEqual(h.presses.release(4, at: 0.4), .suppressed)
        expectEqual(h.scheduler.activeCount, 0)
    })
}
