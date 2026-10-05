import AppKit
import ApplicationServices

protocol FullScreenButtonHandle {
    func canPress() -> WindowAXValue<Bool>
    func press() -> AXError
}
protocol FullScreenWindowHandle {
    func minimized() -> WindowAXValue<Bool>
    func fullScreen() -> WindowAXValue<Bool>
    func fullScreenWritable() -> WindowAXValue<Bool>
    func setFullScreen(_ value: Bool) -> AXError
    func fullScreenButton() -> WindowAXValue<any FullScreenButtonHandle>
    func isSameWindow(as other: any FullScreenWindowHandle) -> Bool
}
protocol FullScreenWindowAccessibility {
    var permissionGranted: Bool { get }
    func frontmostApplication() -> WindowApplicationIdentity?
    func window(in application: WindowApplicationIdentity, selection: WindowSelection) -> WindowAXValue<any FullScreenWindowHandle>
}

struct NativeFullScreenWindowAccessibility: FullScreenWindowAccessibility {
    var permissionGranted: Bool { AXIsProcessTrusted() }
    func frontmostApplication() -> WindowApplicationIdentity? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return WindowApplicationIdentity(pid: app.processIdentifier, identifier: app.bundleIdentifier ?? "pid:\(app.processIdentifier)")
    }
    func window(in application: WindowApplicationIdentity, selection: WindowSelection) -> WindowAXValue<any FullScreenWindowHandle> {
        let app = AXUIElementCreateApplication(application.pid)
        AXUIElementSetMessagingTimeout(app, 0.2)
        let attribute = selection == .focused ? kAXFocusedWindowAttribute : kAXMainWindowAttribute
        switch FullScreenAX.element(app, attribute: attribute as CFString) {
        case .value(let element): return .value(NativeFullScreenWindowHandle(element: element))
        case .failure(let error): return .failure(error)
        }
    }
}

private enum FullScreenAX {
    // This is not a documented SDK constant. Use only if the target application
    // advertises this attribute and reports it writable, never assume support.
    static let stateAttribute = "AXFullScreen" as CFString
    static func boolean(_ element: AXUIElement, attribute: CFString) -> WindowAXValue<Bool> {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard error == .success else { return .failure(error) }
        guard let value else { return .failure(.noValue) }
        guard CFGetTypeID(value) == CFBooleanGetTypeID(), let boolean = value as? Bool else { return .failure(.illegalArgument) }
        return .value(boolean)
    }
    static func element(_ element: AXUIElement, attribute: CFString) -> WindowAXValue<AXUIElement> {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard error == .success else { return .failure(error) }
        guard let value else { return .failure(.noValue) }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return .failure(.illegalArgument) }
        let child = value as! AXUIElement
        AXUIElementSetMessagingTimeout(child, 0.2)
        return .value(child)
    }
}

private struct NativeFullScreenWindowHandle: FullScreenWindowHandle {
    let element: AXUIElement
    func minimized() -> WindowAXValue<Bool> { FullScreenAX.boolean(element, attribute: kAXMinimizedAttribute as CFString) }
    func fullScreen() -> WindowAXValue<Bool> {
        var names: CFArray?
        let error = AXUIElementCopyAttributeNames(element, &names)
        guard error == .success else { return .failure(error) }
        guard let names = names as? [String] else { return .failure(.illegalArgument) }
        guard names.contains(FullScreenAX.stateAttribute as String) else { return .failure(.attributeUnsupported) }
        return FullScreenAX.boolean(element, attribute: FullScreenAX.stateAttribute)
    }
    func fullScreenWritable() -> WindowAXValue<Bool> {
        var settable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(element, FullScreenAX.stateAttribute, &settable)
        return error == .success ? .value(settable.boolValue) : .failure(error)
    }
    func setFullScreen(_ value: Bool) -> AXError {
        AXUIElementSetAttributeValue(element, FullScreenAX.stateAttribute, value ? kCFBooleanTrue : kCFBooleanFalse)
    }
    func fullScreenButton() -> WindowAXValue<any FullScreenButtonHandle> {
        switch FullScreenAX.element(element, attribute: kAXFullScreenButtonAttribute as CFString) {
        case .value(let button): return .value(NativeFullScreenButtonHandle(element: button))
        case .failure(let error): return .failure(error)
        }
    }
    func isSameWindow(as other: any FullScreenWindowHandle) -> Bool {
        guard let other = other as? NativeFullScreenWindowHandle else { return false }
        return CFEqual(element, other.element)
    }
}

private struct NativeFullScreenButtonHandle: FullScreenButtonHandle {
    let element: AXUIElement
    func canPress() -> WindowAXValue<Bool> {
        switch FullScreenAX.boolean(element, attribute: kAXEnabledAttribute as CFString) {
        case .value(false): return .value(false)
        case .failure(let error): return .failure(error)
        case .value(true): break
        }
        var actions: CFArray?
        let error = AXUIElementCopyActionNames(element, &actions)
        guard error == .success else { return .failure(error) }
        guard let actions = actions as? [String] else { return .failure(.illegalArgument) }
        return .value(actions.contains(kAXPressAction as String))
    }
    func press() -> AXError { AXUIElementPerformAction(element, kAXPressAction as CFString) }
}

final class FullScreenWindowAction {
    private let accessibility: any FullScreenWindowAccessibility
    private let diagnostic: (String) -> Void
    private(set) var lastResult: ActionExecutionResult?
    init(accessibility: any FullScreenWindowAccessibility = NativeFullScreenWindowAccessibility(),
         diagnostic: @escaping (String) -> Void = { _ in }) {
        self.accessibility = accessibility; self.diagnostic = diagnostic
    }
    @discardableResult func execute(button: Int? = nil) -> ActionExecutionResult {
        let application = accessibility.frontmostApplication()
        let prefix = "[ShortClick] button=\(button.map(String.init) ?? "unspecified") action=toggleFullScreen frontmost=\(application?.identifier ?? "none")"
        var path = "nativeAX-preflight"
        diagnostic("\(prefix) executor=\(path) stage=request")
        func finish(_ result: ActionExecutionResult, _ reason: String) -> ActionExecutionResult {
            lastResult = result
            diagnostic("\(prefix) executor=\(path) stage=complete result=\(result.rawValue) reason=\(reason)")
            return result
        }
        func failure(_ error: AXError, _ stage: String) -> ActionExecutionResult {
            finish(Self.result(for: error), "\(stage) AXError=\(error.rawValue)")
        }
        guard accessibility.permissionGranted else { return finish(.permissionDenied, "Accessibility unavailable") }
        guard let application else { return finish(.noFrontmostApplication, "windowFound=false; no active application") }
        let window: any FullScreenWindowHandle
        switch resolveWindow(in: application) {
        case .value(let current): window = current
        case .failure(let error): return failure(error, "windowFound=false; focused/main window lookup")
        }
        switch window.minimized() {
        case .value(true): return finish(.unsupported, "window is minimized")
        case .value(false): break
        case .failure(let error):
            guard Self.capabilityAbsent(error) else { return failure(error, "inspect minimized state") }
        }
        var originalState: Bool?
        switch window.fullScreen() {
        case .value(let state): originalState = state
        case .failure(let error):
            guard Self.capabilityAbsent(error) else { return failure(error, "inspect AXFullScreen") }
        }
        var attributeWritable = false
        if originalState != nil {
            switch window.fullScreenWritable() {
            case .value(let writable): attributeWritable = writable
            case .failure(let error):
                guard Self.capabilityAbsent(error) else { return failure(error, "inspect AXFullScreen writability") }
            }
        }
        var control: (any FullScreenButtonHandle)?
        if attributeWritable { path = "nativeAX-attribute" }
        else {
            path = "nativeAX-fullScreenButton"
            switch window.fullScreenButton() {
            case .value(let button): control = button
            case .failure(let error):
                if Self.capabilityAbsent(error) { return finish(.unsupported, "neither writable AXFullScreen nor a full screen button is available") }
                return failure(error, "inspect full screen button")
            }
            switch control!.canPress() {
            case .value(true): break
            case .value(false): return finish(.unsupported, "full screen button disabled or lacks AXPress")
            case .failure(let error):
                return failure(error, "inspect full screen button capability")
            }
        }
        diagnostic("\(prefix) executor=\(path) stage=preflight windowFound=true originalFullScreen=\(originalState.map(String.init) ?? "unavailable") target=\(originalState.map { String(!$0) } ?? "toggle")")
        guard accessibility.permissionGranted else { return finish(.permissionDenied, "Accessibility lost before mutation") }
        guard accessibility.frontmostApplication() == application else { return finish(.cancelled, "foreground changed before mutation") }
        switch resolveWindow(in: application) {
        case .value(let current):
            guard window.isSameWindow(as: current) else { return finish(.cancelled, "focused/main window changed before mutation") }
        case .failure(let error): return failure(error, "recheck focused/main window")
        }
        if let originalState {
            switch window.fullScreen() {
            case .value(let current):
                guard current == originalState else { return finish(.cancelled, "full screen state changed before mutation") }
            case .failure(let error): return failure(error, "recheck AXFullScreen state")
            }
        }
        let error: AXError
        if attributeWritable, let originalState { error = window.setFullScreen(!originalState) }
        else { error = control!.press() }
        guard error == .success else { return failure(error, "full screen mutation; no fallback retry") }
        let observed: String
        switch window.fullScreen() {
        case .value(let state): observed = String(state)
        case .failure(let error): observed = "unavailable(AXError=\(error.rawValue))"
        }
        return finish(.success, "AX request accepted; observedFullScreen=\(observed); animation requires real-device acceptance")
    }
    private func resolveWindow(in application: WindowApplicationIdentity) -> WindowAXValue<any FullScreenWindowHandle> {
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
    private static func capabilityAbsent(_ error: AXError) -> Bool {
        error == .attributeUnsupported || error == .notImplemented || error == .noValue
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
