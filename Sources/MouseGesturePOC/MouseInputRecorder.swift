import Foundation
import CoreGraphics

enum MouseRecordingStatus: Equatable {
    case idle, waiting, primaryUnsupported, captured(RecordedMouseInput), failed(String)
}
enum MouseRecordingEndReason: CaseIterable { case cancel, escape, sheetClosed, applicationInactive, captureFinished }

// Shared intercept in front of the normal mailbox, also used by the temporary
// recording tap when the normal service is disabled. No gesture math lives here.
final class MouseInputRecorder {
    enum Decision: Equatable { case pass, consume, primaryUnsupported, captured(RecordedMouseInput) }
    private let lock = NSLock()
    private var waiting = false
    private var swallowed: Set<Int> = []
    var isRecording: Bool { lock.lock(); defer { lock.unlock() }; return waiting }
    var hasPendingRelease: Bool { lock.lock(); defer { lock.unlock() }; return !swallowed.isEmpty }
    func begin() { lock.lock(); waiting = true; lock.unlock() }
    func cancel(_ reason: MouseRecordingEndReason = .cancel) {
        lock.lock(); waiting = false; lock.unlock()
        // A swallowed down must ALWAYS swallow its up, even after Cancel/close.
    }
    func shutdown() { lock.lock(); waiting = false; swallowed.removeAll(); lock.unlock() }
    func capture(type: CGEventType, event: CGEvent) -> Decision {
        if MouseActionEventOrigin.isOwnSideButton(type: type, event: event) { return .pass }
        return handle(type: type, raw: Int(event.getIntegerValueField(.mouseEventButtonNumber)), flags: event.flags)
    }
    func handle(type: CGEventType, raw: Int, flags: CGEventFlags = []) -> Decision {
        let down = [.otherMouseDown, .leftMouseDown, .rightMouseDown].contains(type)
        let up = [.otherMouseUp, .leftMouseUp, .rightMouseUp].contains(type)
        guard down || up else { return .pass }
        lock.lock(); defer { lock.unlock() }
        if swallowed.contains(raw) {
            if up { swallowed.remove(raw) }
            return .consume
        }
        guard waiting, down, let button = MouseButtonIdentifier(rawValue: raw) else { return .pass }
        guard button.canRemap else { return .primaryUnsupported }
        waiting = false; swallowed.insert(raw)
        return .captured(RecordedMouseInput(button: button, modifiers: MouseModifiers(flags: flags)))
    }
}

// Bind modifiers to the physical down, not to the possibly changed flags at up.
struct MousePressContexts {
    private(set) var values: [Int: MouseModifiers] = [:]
    mutating func down(_ raw: Int, modifiers: MouseModifiers = []) {
        if values[raw] == nil { values[raw] = modifiers }
    }
    mutating func up(_ raw: Int) -> MouseModifiers { values.removeValue(forKey: raw) ?? [] }
    mutating func reset() { values.removeAll() }
}
