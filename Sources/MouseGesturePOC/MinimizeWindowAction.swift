import AppKit
import ApplicationServices

enum WindowAXValue<Value> {
    case value(Value)
    case failure(AXError)
}

struct WindowApplicationIdentity: Equatable {
    let pid: pid_t
    let identifier: String
}

enum WindowSelection: String { case focused, main }

// The AX boundary is injected in regression tests; tests never mutate real windows.
protocol MinimizeWindowHandle {
    func minimized() -> WindowAXValue<Bool>
    func minimizable() -> WindowAXValue<Bool>
    func setMinimized() -> AXError
    func isSameWindow(as other: any MinimizeWindowHandle) -> Bool
}
protocol MinimizeWindowAccessibility {
    var permissionGranted: Bool { get }
    func frontmostApplication() -> WindowApplicationIdentity?
    func window(in application: WindowApplicationIdentity, selection: WindowSelection) -> WindowAXValue<any MinimizeWindowHandle>
}

struct NativeMinimizeWindowAccessibility: MinimizeWindowAccessibility {
    var permissionGranted: Bool { AXIsProcessTrusted() }
    func frontmostApplication() -> WindowApplicationIdentity? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return WindowApplicationIdentity(pid: app.processIdentifier,
            identifier: app.bundleIdentifier ?? "pid:\(app.processIdentifier)")
    }
    func window(in application: WindowApplicationIdentity, selection: WindowSelection) -> WindowAXValue<any MinimizeWindowHandle> {
        let app = AXUIElementCreateApplication(application.pid)
        AXUIElementSetMessagingTimeout(app, 0.2)
        let attribute = selection == .focused ? kAXFocusedWindowAttribute : kAXMainWindowAttribute
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(app, attribute as CFString, &value)
        guard error == .success else { return .failure(error) }
        guard let value else { return .failure(.noValue) }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return .failure(.illegalArgument) }
        return .value(NativeMinimizeWindowHandle(element: value as! AXUIElement))
    }
}

private struct NativeMinimizeWindowHandle: MinimizeWindowHandle {
    let element: AXUIElement
    init(element: AXUIElement) {
        self.element = element
        AXUIElementSetMessagingTimeout(element, 0.2)
    }
    func minimized() -> WindowAXValue<Bool> {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &value)
        guard error == .success else { return .failure(error) }
        guard let value else { return .failure(.noValue) }
        guard CFGetTypeID(value) == CFBooleanGetTypeID(), let boolean = value as? Bool else {
            return .failure(.illegalArgument)
        }
        return .value(boolean)
    }
    func minimizable() -> WindowAXValue<Bool> {
        var settable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(element, kAXMinimizedAttribute as CFString, &settable)
        return error == .success ? .value(settable.boolValue) : .failure(error)
    }
    func setMinimized() -> AXError {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    }
    func isSameWindow(as other: any MinimizeWindowHandle) -> Bool {
        guard let other = other as? NativeMinimizeWindowHandle else { return false }
        return CFEqual(element, other.element)
    }
}

final class MinimizeWindowAction {
    private let accessibility: any MinimizeWindowAccessibility
    private let diagnostic: (String) -> Void
    private(set) var lastResult: ActionExecutionResult?
    init(accessibility: any MinimizeWindowAccessibility = NativeMinimizeWindowAccessibility(),
         diagnostic: @escaping (String) -> Void = { _ in }) {
        self.accessibility = accessibility; self.diagnostic = diagnostic
    }

    @discardableResult func execute(button: Int? = nil) -> ActionExecutionResult {
        let application = accessibility.frontmostApplication()
        let prefix = "[ShortClick] button=\(button.map(String.init) ?? "unspecified") action=minimizeWindow executor=nativeAX frontmost=\(application?.identifier ?? "none")"
        diagnostic("\(prefix) stage=request")
        func finish(_ result: ActionExecutionResult, _ reason: String) -> ActionExecutionResult {
            lastResult = result
            diagnostic("\(prefix) stage=complete result=\(result.rawValue) reason=\(reason)")
            return result
        }
        func failure(_ error: AXError, _ stage: String) -> ActionExecutionResult {
            finish(Self.result(for: error), "\(stage) AXError=\(error.rawValue)")
        }
        guard accessibility.permissionGranted else { return finish(.permissionDenied, "Accessibility unavailable") }
        guard let application else { return finish(.noFrontmostApplication, "windowFound=false; no active application") }
        let window: any MinimizeWindowHandle
        switch resolveWindow(in: application) {
        case .value(let value): window = value
        case .failure(let error): return failure(error, "windowFound=false; focused/main window lookup")
        }
        diagnostic("\(prefix) stage=preflight windowFound=true")
        switch window.minimized() {
        case .value(true): return finish(.success, "window already minimized; no mutation")
        case .value(false): break
        case .failure(let error): return failure(error, "read AXMinimized")
        }
        switch window.minimizable() {
        case .value(true): break
        case .value(false): return finish(.unsupported, "AXMinimized is not writable")
        case .failure(let error): return failure(error, "inspect AXMinimized writability")
        }
        // Recheck immediately before mutation; never act on a stale foreground window.
        guard accessibility.permissionGranted else { return finish(.permissionDenied, "Accessibility lost before mutation") }
        guard accessibility.frontmostApplication() == application else { return finish(.cancelled, "foreground changed before mutation") }
        switch resolveWindow(in: application) {
        case .value(let current):
            guard window.isSameWindow(as: current) else { return finish(.cancelled, "focused/main window changed before mutation") }
        case .failure(let error): return failure(error, "recheck focused/main window")
        }
        let error = window.setMinimized()
        guard error == .success else { return failure(error, "set AXMinimized=true") }
        let observed: String
        switch window.minimized() {
        case .value(let value): observed = String(value)
        case .failure(let error): observed = "unavailable(AXError=\(error.rawValue))"
        }
        // Some apps animate asynchronously. Acceptance of the public AX setter
        // is recorded explicitly; the physical click still needs user acceptance.
        return finish(.success, "AXMinimized=true accepted; observedMinimized=\(observed); animation requires real-device acceptance")
    }

    private func resolveWindow(in application: WindowApplicationIdentity) -> WindowAXValue<any MinimizeWindowHandle> {
        var missingValue = false
        for selection in [WindowSelection.focused, .main] {
            switch accessibility.window(in: application, selection: selection) {
            case .value(let window): return .value(window)
            case .failure(let error):
                if error == .noValue { missingValue = true }
                else if error != .attributeUnsupported && error != .notImplemented { return .failure(error) }
            }
        }
        return .failure(missingValue ? .noValue : .attributeUnsupported)
    }
    private static func result(for error: AXError) -> ActionExecutionResult {
        switch error {
        case .apiDisabled: return .permissionDenied
        case .noValue: return .noFocusedWindow
        case .attributeUnsupported, .actionUnsupported, .notImplemented: return .unsupported
        default: return .unknownFailure
        }
    }
}
