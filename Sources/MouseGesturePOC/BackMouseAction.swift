import AppKit
import ApplicationServices

final class BackMouseAction {
    private let permissionGranted: () -> Bool
    private let frontmostApplication: () -> WindowApplicationIdentity?
    private let pointerLocation: () -> CGPoint?
    private let makeEvents: (CGPoint) -> SyntheticSideButtonEvents?
    private let postEvent: (CGEvent) -> Bool
    private let diagnostic: (String) -> Void
    private(set) var lastResult: ActionExecutionResult?
    init(permissionGranted: @escaping () -> Bool = { AXIsProcessTrusted() },
         frontmostApplication: @escaping () -> WindowApplicationIdentity? = {
             guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
             return WindowApplicationIdentity(pid: app.processIdentifier, identifier: app.bundleIdentifier ?? "pid:\(app.processIdentifier)")
         }, pointerLocation: @escaping () -> CGPoint? = { CGEvent(source: nil)?.location },
         makeEvents: @escaping (CGPoint) -> SyntheticSideButtonEvents? = { SyntheticSideButtonEvents.make(buttonNumber: 3, at: $0) },
         postEvent: @escaping (CGEvent) -> Bool = { $0.post(tap: .cghidEventTap); return true },
         diagnostic: @escaping (String) -> Void = { _ in }) {
        self.permissionGranted = permissionGranted; self.frontmostApplication = frontmostApplication
        self.pointerLocation = pointerLocation; self.makeEvents = makeEvents
        self.postEvent = postEvent; self.diagnostic = diagnostic
    }
    @discardableResult func execute(button: Int? = nil) -> ActionExecutionResult {
        let application = frontmostApplication()
        let prefix = "[ShortClick] button=\(button.map(String.init) ?? "unspecified") action=back executor=nativeMouse-button3 frontmost=\(application?.identifier ?? "none")"
        diagnostic("\(prefix) stage=request")
        func finish(_ result: ActionExecutionResult, _ reason: String) -> ActionExecutionResult {
            lastResult = result
            diagnostic("\(prefix) stage=complete result=\(result.rawValue) reason=\(reason)")
            return result
        }
        guard permissionGranted() else { return finish(.permissionDenied, "Accessibility unavailable") }
        guard let application else { return finish(.noFrontmostApplication, "no active application") }
        guard let point = pointerLocation(), point.x.isFinite, point.y.isFinite else {
            return finish(.unknownFailure, "mouse location unavailable or invalid")
        }
        // Allocate the entire pair before posting either edge; no partial down
        // when source/up allocation fails. Physical cursor position stays intact.
        guard let events = makeEvents(point) else { return finish(.eventPostFailed, "paired mouse event allocation failed") }
        guard permissionGranted() else { return finish(.permissionDenied, "Accessibility lost before posting") }
        guard frontmostApplication() == application else { return finish(.cancelled, "foreground changed before posting") }
        guard postEvent(events.down) else {
            let released = postEvent(events.up)
            return finish(.eventPostFailed, "mouse down submission failed; bestEffortReleaseSubmitted=\(released)")
        }
        guard postEvent(events.up) else {
            // A failed acknowledgement may follow delivery. Do not replay a
            // release or a different backend, which could navigate twice.
            return finish(.eventPostFailed, "mouse up submission failed; no retry or keyboard fallback")
        }
        return finish(.success, "marked otherMouseDown/otherMouseUp pair submitted; application handling/history requires real-device acceptance")
    }
}
