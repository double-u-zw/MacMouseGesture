import CoreGraphics

enum MouseActionEventOrigin {
    // A process-local tag in the public 64-bit source user-data field. Do not
    // reject untagged or other applications' synthetic events.
    static let marker: Int64 = 0x4D4D470000000000 | Int64.random(in: 1...0xFFFFFFFF)
    static func mark(_ event: CGEvent) { event.setIntegerValueField(.eventSourceUserData, value: marker) }
    static func isOwnSideButton(type: CGEventType, event: CGEvent) -> Bool {
        (type == .otherMouseDown || type == .otherMouseUp) &&
            event.getIntegerValueField(.eventSourceUserData) == marker
    }
}

struct SyntheticSideButtonEvents {
    let down: CGEvent
    let up: CGEvent
    static func make(buttonNumber: Int, at point: CGPoint,
                     sourceFactory: () -> CGEventSource? = { CGEventSource(stateID: .privateState) },
                     eventFactory: (CGEventSource, CGEventType, CGPoint) -> CGEvent? = {
                         CGEvent(mouseEventSource: $0, mouseType: $1, mouseCursorPosition: $2, mouseButton: .center)
                     }) -> SyntheticSideButtonEvents? {
        guard (3...31).contains(buttonNumber), point.x.isFinite, point.y.isFinite,
              let source = sourceFactory(),
              let down = eventFactory(source, .otherMouseDown, point),
              let up = eventFactory(source, .otherMouseUp, point) else { return nil }
        // CGMouseButton's named constants stop at center. Its public integer
        // button-number field supports the remaining USB-order buttons.
        for (event, type) in [(down, CGEventType.otherMouseDown), (up, .otherMouseUp)] {
            event.type = type
            event.flags = []
            event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(buttonNumber))
            event.setIntegerValueField(.mouseEventClickState, value: 1)
            event.setIntegerValueField(.mouseEventDeltaX, value: 0)
            event.setIntegerValueField(.mouseEventDeltaY, value: 0)
            MouseActionEventOrigin.mark(event)
        }
        return SyntheticSideButtonEvents(down: down, up: up)
    }
}
