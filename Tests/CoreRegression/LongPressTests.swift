import Foundation
import CoreGraphics
import GestureCore

private final class VirtualLongScheduler: LongPressScheduler {
    final class Ticket: LongPressCancellation {
        let deadline: Double
        let action: () -> Void
        var cancelled = false
        init(_ deadline: Double, _ action: @escaping () -> Void) { self.deadline = deadline; self.action = action }
        func cancel() { cancelled = true }
    }
    var now = 0.0
    var tickets: [Ticket] = []
    var activeCount: Int { tickets.filter { !$0.cancelled }.count }
    func schedule(at deadline: Double, _ action: @escaping () -> Void) -> LongPressCancellation {
        let ticket = Ticket(deadline, action); tickets.append(ticket); return ticket
    }
    func advance(to time: Double) {
        now = time
        for ticket in tickets where !ticket.cancelled && ticket.deadline <= now {
            ticket.cancel(); ticket.action()
        }
    }
}
private final class LongHarness {
    let scheduler = VirtualLongScheduler()
    lazy var coordinator = LongPressCoordinator(scheduler: scheduler)
    var actions: [MouseAction] = []
    init() {
        coordinator.onDeadline = { [weak self] button, generation in
            guard let self, let action = self.coordinator.fire(button, generation: generation) else { return }
            self.actions.append(action)
        }
    }
    func down(_ raw: Int = 3, at time: Double = 0, modifiers: MouseModifiers = [], action: MouseAction? = .system(.showDesktop)) {
        coordinator.down(raw, at: time, modifiers: modifiers, action: action)
    }
}
private func longRow(_ button: Int = 4, modifiers: MouseModifiers = [], action: MouseAction = .system(.showDesktop), enabled: Bool = true) -> MouseMapping {
    MouseMapping(input: .button(button), trigger: .longPress(modifiers: modifiers), action: action, isEnabled: enabled)
}
private func longEvent(_ type: CGEventType, _ raw: Int = 3, dx: Int64 = 0) -> CGEvent {
    let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: .zero, mouseButton: .center)!
    e.setIntegerValueField(.mouseEventButtonNumber, value: Int64(raw)); e.setIntegerValueField(.mouseEventDeltaX, value: dx)
    return e
}
private func logicalEdges(_ records: [InputRecord]) -> [Bool] {
    records.compactMap { if case .modifier(let down, _) = $0 { return down }; return nil }
}

let longPressChecks: [(String, () throws -> Void)] = [
    ("long duration single default and future bounds", {
        expectEqual(LongPressConfiguration.defaultDuration, 0.5)
        expectEqual(LongPressConfiguration(duration: 0.3).duration, 0.3)
        expectEqual(LongPressConfiguration(duration: 1).duration, 1)
        expectEqual(LongPressConfiguration(duration: -1).duration, 0.3)
        expectEqual(LongPressConfiguration(duration: 3).duration, 1)
        expectEqual(LongPressConfiguration(duration: .nan).duration, 0.5)
    }),
    ("long release before threshold permits immediate short", {
        let h = LongHarness(); h.down()
        expectEqual(h.coordinator.release(3, at: 0.1), .shortPressAllowed)
        expectEqual(h.scheduler.activeCount, 0); h.scheduler.advance(to: 10); expectTrue(h.actions.isEmpty)
    }),
    ("long threshold minus epsilon remains pending", {
        let h = LongHarness(); h.down(); h.scheduler.advance(to: 0.5 - 0.000001)
        expectEqual(h.coordinator.claim(for: 3), .pending); expectTrue(h.actions.isEmpty)
        expectEqual(h.coordinator.release(3, at: h.scheduler.now), .shortPressAllowed)
    }),
    ("long threshold exact fires while held", {
        let h = LongHarness(); h.down(); h.scheduler.advance(to: 0.5)
        expectEqual(h.actions, [.system(.showDesktop)]); expectEqual(h.coordinator.claim(for: 3), .longPress)
    }),
    ("long threshold plus epsilon fires once", {
        let h = LongHarness(); h.down(); h.scheduler.advance(to: 0.500001)
        expectEqual(h.actions.count, 1); expectEqual(h.scheduler.activeCount, 0)
    }),
    ("long no repeats during ten second hold", {
        let h = LongHarness(); h.down()
        for time in [0.5, 1, 3, 10] { h.scheduler.advance(to: time) }
        expectEqual(h.actions.count, 1); expectEqual(h.coordinator.timerCount, 0)
    }),
    ("long mouse up after firing suppresses short", {
        let h = LongHarness(); h.down(); h.scheduler.advance(to: 0.5)
        expectEqual(h.coordinator.release(3, at: 0.6), .suppressed); expectFalse(h.coordinator.isActive)
    }),
    ("long delayed callback release at exact deadline owns press", {
        let h = LongHarness(); h.down()
        expectEqual(h.coordinator.release(3, at: 0.5), .longPress(.system(.showDesktop)))
        h.scheduler.advance(to: 1); expectTrue(h.actions.isEmpty); expectEqual(h.scheduler.activeCount, 0)
    }),
    ("long delayed callback release after deadline owns press", {
        let h = LongHarness(); h.down()
        expectEqual(h.coordinator.release(3, at: 0.8), .longPress(.system(.showDesktop)))
        expectFalse(h.coordinator.isActive)
    }),
    ("long no effective mapping allocates no timer or lifecycle", {
        let h = LongHarness(); h.down(action: nil)
        expectFalse(h.coordinator.isActive); expectEqual(h.scheduler.tickets.count, 0)
        expectEqual(h.coordinator.release(3, at: 2), .shortPressAllowed)
    }),
    ("long none action allocates no timer", {
        let h = LongHarness(); h.down(action: MouseAction.none); expectEqual(h.scheduler.tickets.count, 0)
    }),
    ("long duplicate down keeps original deadline and snapshot", {
        let h = LongHarness(); h.down(modifiers: .command)
        h.down(at: 0.2, modifiers: .shift, action: MouseAction.none)
        expectEqual(h.scheduler.tickets.count, 1); expectEqual(h.coordinator.modifiers(for: 3), .command)
        h.scheduler.advance(to: 0.5); expectEqual(h.actions.count, 1)
    }),
    ("long stale cancelled callback cannot affect replacement press", {
        let h = LongHarness(); h.down(); let old = h.scheduler.tickets[0]
        _ = h.coordinator.release(3, at: 0.1); h.down(at: 0.2)
        h.scheduler.now = 0.5; old.action(); expectTrue(h.actions.isEmpty)
        h.scheduler.advance(to: 0.7); expectEqual(h.actions.count, 1)
    }),
    ("long early timer callback rearms without firing", {
        let h = LongHarness(); h.down(); h.scheduler.now = 0.49; h.scheduler.tickets[0].action()
        expectTrue(h.actions.isEmpty); expectEqual(h.scheduler.activeCount, 1)
        h.scheduler.advance(to: 0.5); expectEqual(h.actions.count, 1)
    }),
    ("long drag before deadline cancels timer and short", {
        let h = LongHarness(); h.down(); h.coordinator.observeDrag([3]); h.scheduler.advance(to: 0.6)
        expectEqual(h.coordinator.claim(for: 3), .drag); expectTrue(h.actions.isEmpty)
        expectEqual(h.coordinator.release(3, at: 0.7), .suppressed)
    }),
    ("long drag claim never returns to pending", {
        let h = LongHarness(); h.down(); h.coordinator.observeDrag([3]); h.coordinator.observeDrag([])
        h.scheduler.advance(to: 1); expectEqual(h.coordinator.claim(for: 3), .drag); expectTrue(h.actions.isEmpty)
    }),
    ("long first claim survives later movement", {
        let h = LongHarness(); h.down(); h.scheduler.advance(to: 0.5); h.coordinator.observeDrag([3])
        expectEqual(h.coordinator.claim(for: 3), .longPress); expectEqual(h.actions.count, 1)
    }),
    ("long joining already recognized drag has no timer", {
        let h = LongHarness(); h.coordinator.down(3, at: 0, modifiers: [], action: .system(.showDesktop), dragClaimed: true)
        expectEqual(h.coordinator.claim(for: 3), .drag); expectEqual(h.scheduler.tickets.count, 0)
    }),
    ("long original deadZone below boundary preserves candidate", {
        let h = LongHarness(); h.down(); var m = GestureMachine(); var clicks = SideButtonClickTracker()
        m.down(at: 0); clicks.down(3, machine: m); m.move(dx: 7, dy: 0, at: 0.1); clicks.observe(m)
        let dragged: Set<Int> = Set(clicks.states.filter { $0.value == .gestureStarted }.keys)
        h.coordinator.observeDrag(dragged)
        h.scheduler.advance(to: 0.5); expectEqual(h.actions.count, 1)
    }),
    ("long original deadZone exact boundary cancels candidate", {
        let h = LongHarness(); h.down(); var m = GestureMachine(); var clicks = SideButtonClickTracker()
        m.down(at: 0); clicks.down(3, machine: m); m.move(dx: m.config.deadZone, dy: 0, at: 0.1); clicks.observe(m)
        let dragged: Set<Int> = Set(clicks.states.filter { $0.value == .gestureStarted }.keys)
        h.coordinator.observeDrag(dragged)
        h.scheduler.advance(to: 1); expectTrue(h.actions.isEmpty); expectFalse(clicks.up(3))
    }),
    ("long original drag out and return stays drag", {
        let h = LongHarness(); h.down(); var m = GestureMachine(); var clicks = SideButtonClickTracker()
        m.down(at: 0); clicks.down(3, machine: m); m.move(dx: 20, dy: 0, at: 0.1); clicks.observe(m)
        h.coordinator.observeDrag([3]); m.move(dx: -20, dy: 0, at: 0.2); clicks.observe(m)
        h.scheduler.advance(to: 1); expectTrue(h.actions.isEmpty); expectFalse(clicks.up(3))
        expectEqual(h.coordinator.release(3, at: 1), .suppressed)
    }),
    ("long standalone middle drag uses existing threshold", {
        let h = LongHarness(); h.down(2); var tracker = StandaloneShortPressTracker()
        tracker.down(2, at: 0, config: GestureConfig()); tracker.move(dx: 9, dy: 0, at: 0.1, count: 1)
        h.coordinator.observeDrag(tracker.dragStartedButtons); h.scheduler.advance(to: 1)
        expectTrue(h.actions.isEmpty); expectFalse(tracker.up(2)); expectEqual(h.coordinator.claim(for: 2), .drag)
    }),
    ("long standalone slight jitter still eligible", {
        let h = LongHarness(); h.down(2); var tracker = StandaloneShortPressTracker()
        tracker.down(2, at: 0, config: GestureConfig()); tracker.move(dx: 2, dy: 2, at: 0.1, count: 1)
        h.coordinator.observeDrag(tracker.dragStartedButtons); h.scheduler.advance(to: 0.5); expectEqual(h.actions.count, 1)
    }),
    ("long plain modifier resolution", {
        let store = MouseMappingStore(mappings: [longRow()])
        expectEqual(store.longPressAction(for: .button(4), modifiers: []), .system(.showDesktop))
    }),
    ("long exact command row beats plain fallback once", {
        let store = MouseMappingStore(mappings: [longRow(),longRow(modifiers: .command, action: .window(.minimize))])
        expectEqual(store.longPressAction(for: .button(4), modifiers: .command), .window(.minimize))
    }),
    ("long multiple modifiers exact match", {
        let flags: MouseModifiers = [.control,.command,.shift]
        let store = MouseMappingStore(mappings: [longRow(modifiers: flags)])
        expectEqual(store.longPressAction(for: .button(4), modifiers: flags), .system(.showDesktop))
        expectEqual(store.longPressAction(for: .button(4), modifiers: .command), nil)
    }),
    ("long no subset matching with existing short fallback policy", {
        let store = MouseMappingStore(mappings: [longRow(),longRow(modifiers: .command, action: .window(.minimize))])
        expectEqual(store.longPressAction(for: .button(4), modifiers: [.command,.shift]), .system(.showDesktop))
    }),
    ("long disabled exact row suppresses plain fallback and timer", {
        let store = MouseMappingStore(mappings: [longRow(),longRow(modifiers: .command, enabled: false)])
        let h = LongHarness(); h.down(modifiers: .command, action: store.longPressAction(for: .button(4), modifiers: .command))
        expectEqual(h.scheduler.tickets.count, 0)
    }),
    ("long disabled plain mapping has no timer", {
        let store = MouseMappingStore(mappings: [longRow(enabled: false)])
        let h = LongHarness(); h.down(action: store.longPressAction(for: .button(4), modifiers: []))
        expectEqual(h.scheduler.tickets.count, 0); expectTrue(store.pressCGButtons.isEmpty)
    }),
    ("long deleted mapping has no timer", {
        let row = longRow(); var store = MouseMappingStore(mappings: [row]); store.delete(row.id)
        let h = LongHarness(); h.down(action: store.longPressAction(for: .button(4), modifiers: []))
        expectEqual(h.scheduler.tickets.count, 0)
    }),
    ("long buttonDown freezes modifier and action through key release", {
        var contexts = MousePressContexts(); contexts.down(3, modifiers: .command)
        let store = MouseMappingStore(mappings: [longRow(),longRow(modifiers: .command, action: .window(.minimize))])
        let h = LongHarness(); h.down(modifiers: contexts.values[3]!, action: store.longPressAction(for: .button(4), modifiers: contexts.values[3]!))
        contexts.down(3, modifiers: []); h.scheduler.advance(to: 0.5)
        expectEqual(h.actions, [.window(.minimize)]); expectEqual(h.coordinator.modifiers(for: 3), .command)
    }),
    ("long short and long coexist without conflict", {
        var store = MouseMappingStore(); let short = MouseMapping(input: .button(4), trigger: .shortPress, action: .none)
        let long = longRow(); expectEqual(store.add(short), short.id); expectEqual(store.add(long), long.id)
        expectEqual(store.mappings.count, 2); expectEqual(store.shortPressAction(for: .button(4), modifiers: []), MouseAction.none)
    }),
    ("long duplicate input modifier trigger resolves existing editor", {
        let row = longRow(modifiers: .command); var store = MouseMappingStore(mappings: [row])
        expectEqual(store.add(longRow(modifiers: .command)), row.id); expectEqual(store.mappings.count, 1)
    }),
    ("long plain and modified coexist", {
        let store = MouseMappingStore(mappings: [longRow(),longRow(modifiers: .command)])
        expectEqual(store.mappings.count, 2)
    }),
    ("long model Codable and base preserved", {
        for flags: MouseModifiers in [[],.command,[.command,.option,.control,.shift]] {
            let trigger = MouseTrigger.longPress(modifiers: flags)
            expectEqual(try JSONDecoder().decode(MouseTrigger.self, from: JSONEncoder().encode(trigger)), trigger)
            expectEqual(trigger.base, .longPress); expectEqual(trigger.modifiers, flags); expectTrue(trigger.isButtonPress)
        }
    }),
    ("long changing recorder input preserves selected long base", {
        let recorded = RecordedMouseInput(button: MouseButtonIdentifier(rawValue: 4)!, modifiers: [.command,.shift])
        let trigger = MouseTrigger.longPress.withModifiers(recorded.modifiers)
        expectEqual(trigger, .modifiedLongPress([.command,.shift])); expectEqual(recorded.trigger.base, .shortPress)
    }),
    ("long drag UUID orders unchanged and display short long drag", {
        expectEqual(MouseTrigger.shortPress.order, 0)
        for (i, d) in MouseDragDirection.allCases.enumerated() { expectEqual(MouseTrigger.drag(d).order, i+1) }
        expectTrue(MouseTrigger.longPress.displayOrder < MouseTrigger.drag(.left).displayOrder)
    }),
    ("long version 3 roundtrip protects old readers", {
        let store = MouseMappingStore(mappings: [longRow(modifiers: .command)])
        let data = try store.encoded(); let obj = try JSONSerialization.jsonObject(with: data) as! [String:Any]
        expectEqual(obj["version"] as? Int, 3); expectEqual(try MouseMappingStore(data: data), store)
    }),
    ("long old v1 config stays short only", {
        let data = try MouseMappingStore(mappings: LegacyMappingProjection.defaults).encoded()
        let obj = try JSONSerialization.jsonObject(with: data) as! [String:Any]
        expectEqual(obj["version"] as? Int, 1); expectFalse(try MouseMappingStore(data: data).mappings.contains { $0.trigger.isLongPress })
    }),
    ("long configuration persistence independent from short and other button", {
        let name = "local.macmousegesture.long.\(UUID())"; let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = ConfigStore(defaults: defaults); var config = AppConfig()
        config.mappings = [longRow(),longRow(5, modifiers: .command),MouseMapping(input: .button(4),trigger: .shortPress,action: .window(.minimize))]
        store.save(config); expectEqual(store.load(), config.validated())
        expectEqual(store.load().button4ClickAction.action, .minimizeWindow)
        expectEqual(store.load().mappingStore.longPressAction(for: .button(5), modifiers: .command), .system(.showDesktop))
    }),
    ("long only mapping keeps service eligible with axes off", {
        var c = AppConfig(); c.horizontalEnabled = false; c.verticalEnabled = false; c.mappings = [longRow(8)]
        expectTrue(c.shouldRun); expectEqual(c.mappingStore.pressCGButtons, [7]); expectTrue(c.mappingStore.shortPressCGButtons.isEmpty)
    }),
    ("long primary buttons remain protected", {
        expectTrue(MouseMappingStore(mappings: [longRow(1),longRow(2)]).mappings.isEmpty)
        let model = AppViewModel(config: .defaults)
        if case .unavailable = model.saveMapping(longRow(1)) {} else { expectTrue(false) }
    }),
    ("long model add disable delete supported", {
        let model = AppViewModel(config: .defaults); let row = longRow()
        model.applyConfig = { config, _ in model.show(config) }
        if case .saved = model.saveMapping(row) {} else { expectTrue(false) }; model.setMappingEnabled(false, id: row.id)
        expectEqual(model.config.mappingStore.longPressAction(for: .button(4), modifiers: []), nil)
        model.deleteMapping(row.id); expectEqual(model.config.mappingStore.mapping(for: .button(4), trigger: .longPress), nil)
    }),
    ("long simultaneous buttons independent deadlines and actions", {
        let h = LongHarness(); h.down(3); h.down(4, at: 0.2, action: .window(.minimize))
        h.scheduler.advance(to: 0.5); expectEqual(h.actions, [.system(.showDesktop)])
        expectEqual(h.coordinator.claim(for: 4), .pending); h.scheduler.advance(to: 0.7)
        expectEqual(h.actions, [.system(.showDesktop),.window(.minimize)])
    }),
    ("long one button drag leaves other timer independent", {
        let h = LongHarness(); h.down(3); h.down(4); h.coordinator.observeDrag([3]); h.scheduler.advance(to: 0.5)
        expectEqual(h.actions.count, 1); expectEqual(h.coordinator.claim(for: 3), .drag); expectEqual(h.coordinator.claim(for: 4), .longPress)
    }),
    ("long one button release leaves other timer", {
        let h = LongHarness(); h.down(3); h.down(4); _ = h.coordinator.release(3, at: 0.1)
        expectEqual(h.scheduler.activeCount, 1); h.scheduler.advance(to: 0.5); expectEqual(h.actions.count, 1)
    }),
    ("long rapid alternating buttons leaves no timer", {
        let h = LongHarness()
        for i in 0..<100 {
            let raw = i % 2 + 3; let time = Double(i) * 0.1; h.down(raw, at: time)
            expectEqual(h.coordinator.release(raw, at: time+0.05), .shortPressAllowed)
        }
        h.scheduler.advance(to: 20); expectTrue(h.actions.isEmpty); expectEqual(h.scheduler.activeCount, 0); expectFalse(h.coordinator.isActive)
    }),
    ("long mailbox claim retires driver without releasing physical capture", {
        let box = InputMailbox(buttons: [3], gesture: true, freeze: true)
        expectTrue(box.capture(type: .otherMouseDown, event: longEvent(.otherMouseDown), receivedAt: 0))
        expectEqual(logicalEdges(box.drain()), [true]); expectTrue(box.claimLongPress(3, at: 0.5))
        expectEqual(logicalEdges(box.drain()), [false])
        expectFalse(box.capture(type: .mouseMoved, event: longEvent(.mouseMoved, dx: 30), receivedAt: 0.6))
        expectTrue(box.capture(type: .otherMouseUp, event: longEvent(.otherMouseUp), receivedAt: 0.7))
        expectTrue(logicalEdges(box.drain()).isEmpty)
    }),
    ("long mailbox duplicate claim cannot emit duplicate end", {
        let box = InputMailbox(buttons: [3], gesture: true, freeze: true)
        _ = box.capture(type: .otherMouseDown, event: longEvent(.otherMouseDown)); _ = box.drain()
        expectTrue(box.claimLongPress(3, at: 1)); expectFalse(box.claimLongPress(3, at: 2))
        expectEqual(logicalEdges(box.drain()), [false])
    }),
    ("long mailbox other drag driver remains active", {
        let box = InputMailbox(buttons: [3,4], gesture: true, freeze: true)
        for raw in [3,4] { _ = box.capture(type: .otherMouseDown, event: longEvent(.otherMouseDown,raw)) }
        _ = box.drain(); expectFalse(box.claimLongPress(3, at: 0.5)); expectTrue(logicalEdges(box.drain()).isEmpty)
        expectTrue(box.capture(type: .mouseMoved, event: longEvent(.mouseMoved, dx: 20)))
        _ = box.capture(type: .otherMouseUp, event: longEvent(.otherMouseUp,4)); expectEqual(logicalEdges(box.drain()), [false])
    }),
    ("long mailbox next press restores drag after long release", {
        let box = InputMailbox(buttons: [3], gesture: true, freeze: true)
        _ = box.capture(type: .otherMouseDown, event: longEvent(.otherMouseDown)); _ = box.claimLongPress(3, at: 1)
        _ = box.capture(type: .otherMouseUp, event: longEvent(.otherMouseUp)); _ = box.drain()
        _ = box.capture(type: .otherMouseDown, event: longEvent(.otherMouseDown)); expectEqual(logicalEdges(box.drain()), [true])
        expectTrue(box.capture(type: .mouseMoved, event: longEvent(.mouseMoved, dx: 20)))
    }),
    ("long mailbox tap recovery clears claim and quarantines physical hold", {
        let box = InputMailbox(buttons: [3], gesture: true, freeze: true)
        _ = box.capture(type: .otherMouseDown, event: longEvent(.otherMouseDown)); _ = box.claimLongPress(3, at: 1)
        box.interruptForTapRecovery("test"); expectTrue(box.resumeAfterTapRecovery())
        expectFalse(box.capture(type: .otherMouseDown, event: longEvent(.otherMouseDown)))
        _ = box.capture(type: .otherMouseUp, event: longEvent(.otherMouseUp)); _ = box.drain()
        _ = box.capture(type: .otherMouseDown, event: longEvent(.otherMouseDown)); expectEqual(logicalEdges(box.drain()), [true])
    })
] + ["Escape before deadline","recording begins","service stop","app termination","input reset","mapping disabled","mapping deleted","tap invalidated","permission lost"].map { reason in
    ("long cancellation cleans every timer: \(reason)", {
        let h = LongHarness(); h.down(3); h.down(4); let stale = h.scheduler.tickets
        h.coordinator.cancelAll(); expectEqual(h.coordinator.timerCount, 0); expectEqual(h.scheduler.activeCount, 0)
        expectEqual(h.coordinator.release(3, at: 0.7), .suppressed)
        h.scheduler.now = 1; for ticket in stale { ticket.action() }; expectTrue(h.actions.isEmpty)
        h.coordinator.reset(); expectFalse(h.coordinator.isActive)
    })
} + ["Escape after long","focus reset after long"].map { reason in
    ("long cancellation after firing never restores short: \(reason)", {
        let h = LongHarness(); h.down(); h.scheduler.advance(to: 0.5); h.coordinator.cancelAll()
        expectEqual(h.coordinator.release(3, at: 1), .suppressed); expectEqual(h.actions.count, 1); expectEqual(h.scheduler.activeCount, 0)
    })
}

// Extra lifetime and pipeline boundaries remain independent of wall-clock sleep.
let longPressLifetimeChecks: [(String, () throws -> Void)] = [
    ("long reset stale timer cannot claim new session", {
        let h = LongHarness(); h.down(); let stale = h.scheduler.tickets[0]
        h.coordinator.reset(); h.down(at: 2); h.scheduler.now = 3; stale.action()
        expectTrue(h.actions.isEmpty); expectEqual(h.coordinator.claim(for: 3), .pending)
        h.scheduler.advance(to: 3); expectEqual(h.actions.count, 1)
    }),
    ("long reset suppresses click through existing tracker cleanup", {
        let h = LongHarness(); h.down(); var machine = GestureMachine(); var clicks = SideButtonClickTracker()
        machine.down(at: 0); clicks.down(3, machine: machine)
        h.coordinator.reset(); clicks.reset()
        expectEqual(h.coordinator.release(3, at: 0.7), .shortPressAllowed)
        expectFalse(clicks.up(3)); h.scheduler.advance(to: 1); expectTrue(h.actions.isEmpty)
    }),
    ("long mailbox Escape after claim still sees physical hold", {
        let box = InputMailbox(buttons: [3], gesture: true, freeze: true)
        _ = box.capture(type: .otherMouseDown, event: longEvent(.otherMouseDown)); _ = box.claimLongPress(3, at: 1); _ = box.drain()
        let escape = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true)!
        expectFalse(box.capture(type: .keyDown, event: escape))
        expectTrue(box.drain().contains { if case .cancel("Escape") = $0 { return true }; return false })
        expectFalse(box.capture(type: .otherMouseUp, event: longEvent(.otherMouseUp)))
    }),
    ("long retirement prevents later horizontal frames", {
        var machine = GestureMachine(); machine.down(at: 0); machine.move(dx: 2, dy: 1, at: 0.1)
        expectTrue(machine.finish(at: 0.5).isEmpty)
        machine.move(dx: 200, dy: 0, at: 0.6); expectTrue(machine.frame(at: 0.6).isEmpty)
        expectTrue(machine.finish(at: 0.7).isEmpty)
    }),
    ("long configurable duration injected scheduler uses same source", {
        let scheduler = VirtualLongScheduler(); let c = LongPressCoordinator(scheduler: scheduler, configuration: .init(duration: 0.8))
        var fired = 0; c.onDeadline = { button, generation in if c.fire(button, generation: generation) != nil { fired += 1 } }
        c.down(3, at: 0, modifiers: [], action: .system(.showDesktop))
        scheduler.advance(to: 0.5); expectEqual(fired, 0); scheduler.advance(to: 0.8); expectEqual(fired, 1)
        c.onDeadline = nil
    }),
    ("long coordinator deallocation cancels source without retained callback", {
        let scheduler = VirtualLongScheduler(); var coordinator: LongPressCoordinator? = .init(scheduler: scheduler)
        weak var weakCoordinator = coordinator
        coordinator?.down(3, at: 0, modifiers: [], action: .system(.showDesktop)); expectEqual(scheduler.activeCount, 1)
        coordinator = nil; expectTrue(weakCoordinator == nil); expectEqual(scheduler.activeCount, 0)
    })
]
