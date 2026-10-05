import Foundation
import CoreGraphics

enum InputRecord {
    case button(Int, Bool, Double)
    case buttonContext(Int, MouseModifiers)
    // One logical modifier: first configured button down → last configured button up.
    case modifier(Bool, Double)
    case motion(Double, Double, Double, Int)
    case scroll(Double, Double, Int)
    case cancel(String)
    case tapDisabled(String)
}

// CG events may have no timestamp (CGEventCreate itself produces zero), or a
// timestamp supplied by another producer. Never use it to drive our safety lease.
struct InputTiming {
    private(set) var maxEventAgeMS: Double?
    private(set) var rejectedTimestamps = 0
    private(set) var validTimestamps = 0
    mutating func observe(timestamp: UInt64, receivedAt: Double) {
        let age = receivedAt - Double(timestamp) / 1_000_000_000
        guard timestamp != 0, age >= 0, age <= 1 else {
            rejectedTimestamps += 1; return
        }
        validTimestamps += 1
        maxEventAgeMS = max(maxEventAgeMS ?? 0, age * 1000)
    }
    var summary: String {
        let age = maxEventAgeMS.map { String(format: "%.3f ms", $0) } ?? "unavailable"
        return "CG timestamp age max=\(age); valid=\(validTimestamps) rejected=\(rejectedTimestamps) (not hardware latency)"
    }
}

// Bounded accumulator. Motion merges only with adjacent motion, preserving button boundaries.
// No async block is allocated per mouse report; only edges wake the engine queue.
final class InputMailbox {
    private let lock = NSLock()
    private var records: [InputRecord] = []
    private var accepting = true
    private var heldButtons: Set<Int> = []
    private var retiredPressButtons: Set<Int> = []
    private var dragHeld: Bool { !heldButtons.subtracting(retiredPressButtons).isDisjoint(with: gestureButtons) }
    private var overflow = false
    private var timing = InputTiming()
    private var counters = InputCounters()
    private var recoveryPending = false
    private var blockedUntilRelease: Set<Int> = []
    let buttons: Set<Int>
    let gestureButtons: Set<Int>
    let gesture: Bool
    let freeze: Bool
    let wheelButtons: Set<Int>
    var wheelCapture: ((WheelScrollSample, Double) -> Bool)?
    var wake: (() -> Void)?
    private let recorder: MouseInputRecorder?
    init(buttons: Set<Int>, gesture: Bool, freeze: Bool, gestureButtons: Set<Int>? = nil, recorder: MouseInputRecorder? = nil, wheelButtons: Set<Int> = []) {
        self.buttons = buttons; self.gesture = gesture; self.freeze = freeze
        self.wheelButtons = wheelButtons
        self.recorder = recorder
        self.gestureButtons = gestureButtons ?? buttons
        records.reserveCapacity(256)
    }
    func capture(type: CGEventType, event: CGEvent, receivedAt time: Double = monotonicTime()) -> Bool {
        // Pass our paired navigation events through, before counters/held-state
        // handling. They must reach the app without recursively becoming gestures.
        if MouseActionEventOrigin.isOwnSideButton(type: type, event: event) { return false }
        if let recorder {
            switch recorder.capture(type: type, event: event) {
            case .consume, .captured: return true
            case .pass, .primaryUnsupported: break
            }
        }
        lock.lock()
        guard accepting || recoveryPending else { lock.unlock(); return false }
        if type != .keyDown {
            counters.rawMouseEvents += 1; counters.lastMouseAt = time
        }
        if type == .otherMouseDown || type == .otherMouseUp {
            let number = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            if buttons.contains(number) { counters.lastSideButtonAt = time }
            if type == .otherMouseDown {
                if number == 3 { counters.button4Downs += 1 }
                if number == 4 { counters.button5Downs += 1 }
            }
            if blockedUntilRelease.contains(number) {
                if type == .otherMouseUp { blockedUntilRelease.remove(number) }
                lock.unlock(); return false
            }
        }
        guard accepting else { lock.unlock(); return false }
        timing.observe(timestamp: event.timestamp, receivedAt: time)
        var consume = false
        var edge = false
        var resolveWheel = false
        switch type {
        case .otherMouseDown, .otherMouseUp, .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp:
            let number = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            let down = type == .otherMouseDown || type == .leftMouseDown || type == .rightMouseDown
            if down && gesture && buttons.contains(number) {
                let modifiers = MouseModifiers(flags: event.flags)
                if !modifiers.isEmpty { records.append(.buttonContext(number, modifiers)) }
            }
            records.append(.button(number, down, time)); edge = true
            if gesture && buttons.contains(number) {
                let wasHeld = dragHeld
                if down { heldButtons.insert(number) } else { heldButtons.remove(number); retiredPressButtons.remove(number) }
                let isHeld = dragHeld
                consume = true
                if wasHeld != isHeld { records.append(.modifier(isHeld, time)) }
            }
        case .mouseMoved, .otherMouseDragged, .leftMouseDragged, .rightMouseDragged:
            let held = !heldButtons.isEmpty
            consume = gesture && dragHeld && freeze && (type == .mouseMoved || type == .otherMouseDragged)
            if !gesture || held {
                let dx = Double(event.getIntegerValueField(.mouseEventDeltaX))
                let dy = Double(event.getIntegerValueField(.mouseEventDeltaY))
                if case .motion(let x, let y, _, let count) = records.last {
                    records[records.count - 1] = .motion(x + dx, y + dy, time, count + 1)
                } else { records.append(.motion(dx, dy, time, 1)) }
            }
        case .scrollWheel:
            if gesture {
                resolveWheel = !heldButtons.isDisjoint(with: wheelButtons)
            } else {
                let x = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
                let y = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
                if case .scroll(let px, let py, let count) = records.last {
                    records[records.count - 1] = .scroll(px + x, py + y, count + 1)
                } else { records.append(.scroll(x, y, 1)) }
            }
        case .keyDown:
            // Only the Escape keycode is inspected, never stored. Always pass keyboard input through.
            if !heldButtons.isEmpty && event.getIntegerValueField(.keyboardEventKeycode) == 53 {
                heldButtons.removeAll(); retiredPressButtons.removeAll(); accepting = false
                records.append(.cancel("Escape")); edge = true
            }
        default: break
        }
        if records.count > 256 {
            records.removeAll(keepingCapacity: true); records.append(.cancel("mailbox overflow"))
            overflow = true; accepting = false; heldButtons.removeAll(); retiredPressButtons.removeAll(); consume = false; edge = true
        }
        lock.unlock()
        if edge { wake?() }
        // Never hold the mailbox lock while the engine drains preceding input.
        if resolveWheel, let sample = WheelScrollSample(event: event) { return wheelCapture?(sample, time) ?? false }
        return consume
    }
    // Preserve physical capture through mouseUp, but retire this button as a drag
    // driver. The existing logical modifier-up finishes the pending pipeline.
    @discardableResult func claimLongPress(_ number: Int, at time: Double) -> Bool {
        retirePressDriver(number, at: time)
    }
    @discardableResult func retirePressDriver(_ number: Int, at time: Double) -> Bool {
        lock.lock()
        guard accepting, heldButtons.contains(number) else { lock.unlock(); return false }
        let wasHeld = dragHeld
        retiredPressButtons.insert(number)
        let isHeld = dragHeld
        if wasHeld != isHeld { records.append(.modifier(isHeld, time)) }
        lock.unlock()
        if wasHeld != isHeld { wake?() }
        return wasHeld != isHeld
    }
    func cancel(_ reason: String) {
        lock.lock(); heldButtons.removeAll(); retiredPressButtons.removeAll()
        if accepting { records.append(.cancel(reason)) }
        accepting = false
        recoveryPending = false
        lock.unlock(); wake?()
    }
    func interruptForTapRecovery(_ reason: String) {
        lock.lock()
        guard accepting else { lock.unlock(); return }
        blockedUntilRelease.formUnion(heldButtons)
        heldButtons.removeAll(); retiredPressButtons.removeAll(); accepting = false; recoveryPending = true
        records.append(.tapDisabled(reason))
        lock.unlock(); wake?()
    }
    @discardableResult func resumeAfterTapRecovery() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard recoveryPending else { return false }
        recoveryPending = false; accepting = true
        return true
    }
    func drain() -> [InputRecord] {
        lock.lock(); defer { lock.unlock() }
        let result = records; records.removeAll(keepingCapacity: true); return result
    }
    func stop() { lock.lock(); accepting = false; recoveryPending = false; heldButtons.removeAll(); retiredPressButtons.removeAll(); lock.unlock() }
    func counts() -> InputCounters { lock.lock(); defer { lock.unlock() }; return counters }
    func stats() -> String {
        lock.lock(); defer { lock.unlock() }
        return "\(timing.summary); overflow=\(overflow ? "YES" : "no")"
    }
}

final class CGEventTapBackend {
    let mailbox: InputMailbox
    private var tap: CFMachPort?
    private var runLoop: CFRunLoop?
    private let lock = NSLock()
    private var stopping = false
    init(mailbox: InputMailbox) { self.mailbox = mailbox }

    func start() -> Bool {
        let started = DispatchSemaphore(value: 0)
        let thread = Thread { [self] in
            autoreleasepool {
                let types: [CGEventType] = [.otherMouseDown, .otherMouseUp, .leftMouseDown, .leftMouseUp,
                    .rightMouseDown, .rightMouseUp, .mouseMoved, .otherMouseDragged,
                    .leftMouseDragged, .rightMouseDragged, .scrollWheel] + (mailbox.gesture ? [.keyDown] : [])
                let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
                let created = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap,
                    options: mailbox.gesture ? .defaultTap : .listenOnly, eventsOfInterest: mask,
                    callback: { _, type, event, context in
                        guard let context else { return Unmanaged.passUnretained(event) }
                        let owner = Unmanaged<CGEventTapBackend>.fromOpaque(context).takeUnretainedValue()
                        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                            owner.mailbox.interruptForTapRecovery("event tap disabled (\(type.rawValue))")
                            // Fail open immediately; bounded recovery runs on the engine queue.
                            return Unmanaged.passUnretained(event)
                        }
                        return owner.mailbox.capture(type: type, event: event) ? nil : Unmanaged.passUnretained(event)
                    }, userInfo: Unmanaged.passUnretained(self).toOpaque())
                lock.lock()
                tap = created; runLoop = CFRunLoopGetCurrent()
                let shouldStop = stopping
                lock.unlock()
                guard let created, !shouldStop else {
                    if let created { CFMachPortInvalidate(created) }
                    started.signal(); return
                }
                let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
                CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
                CGEvent.tapEnable(tap: created, enable: true)
                started.signal()
                CFRunLoopRun()
                CFMachPortInvalidate(created)
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
                lock.lock(); tap = nil; runLoop = nil; lock.unlock()
            }
        }
        thread.name = "MouseGesture.InputTap"; thread.qualityOfService = .userInteractive; thread.start()
        guard started.wait(timeout: .now() + 3) == .success else { stop(); return false }
        lock.lock(); defer { lock.unlock() }
        return tap != nil && !stopping
    }
    var health: String {
        lock.lock(); defer { lock.unlock() }
        guard let tap, !stopping, CFMachPortIsValid(tap) else { return "unavailable" }
        return CGEvent.tapIsEnabled(tap: tap) ? "enabled" : "disabled"
    }
    func reenable() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let tap, !stopping, CFMachPortIsValid(tap) else { return false }
        CGEvent.tapEnable(tap: tap, enable: true)
        return CGEvent.tapIsEnabled(tap: tap)
    }
    func stop() {
        mailbox.stop()
        lock.lock(); stopping = true
        if let loop = runLoop {
            CFRunLoopPerformBlock(loop, CFRunLoopMode.commonModes.rawValue) { CFRunLoopStop(loop) }
            CFRunLoopWakeUp(loop)
        }
        lock.unlock()
    }
}
