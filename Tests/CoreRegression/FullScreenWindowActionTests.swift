import Foundation
import ApplicationServices

private final class FullScreenTestButton: FullScreenButtonHandle {
    var capability: WindowAXValue<Bool> = .value(true)
    var error = AXError.success
    var presses = 0
    var onPress: (() -> Void)?
    func canPress() -> WindowAXValue<Bool> { capability }
    func press() -> AXError { presses += 1; if error == .success { onPress?() }; return error }
}
private final class FullScreenTestWindow: FullScreenWindowHandle {
    let id: Int
    var minimizedState: WindowAXValue<Bool> = .value(false)
    var state: WindowAXValue<Bool> = .value(false)
    var writable: WindowAXValue<Bool> = .value(true)
    var buttonResult: WindowAXValue<any FullScreenButtonHandle> = .failure(.noValue)
    var setError = AXError.success
    var writes: [Bool] = []
    var buttonReads = 0
    var stateReads = 0
    var changedStateOnRecheck: WindowAXValue<Bool>?
    var asynchronous = false
    var postMutationReadback: WindowAXValue<Bool>?
    init(id: Int = 1) { self.id = id }
    func minimized() -> WindowAXValue<Bool> { minimizedState }
    func fullScreen() -> WindowAXValue<Bool> {
        stateReads += 1
        if !writes.isEmpty, let postMutationReadback { return postMutationReadback }
        if stateReads > 1, let changedStateOnRecheck { return changedStateOnRecheck }
        return state
    }
    func fullScreenWritable() -> WindowAXValue<Bool> { writable }
    func setFullScreen(_ value: Bool) -> AXError {
        writes.append(value)
        if setError == .success && !asynchronous { state = .value(value) }
        return setError
    }
    func fullScreenButton() -> WindowAXValue<any FullScreenButtonHandle> { buttonReads += 1; return buttonResult }
    func isSameWindow(as other: any FullScreenWindowHandle) -> Bool { (other as? FullScreenTestWindow)?.id == id }
}
private final class FullScreenFixture: FullScreenWindowAccessibility {
    let identity = WindowApplicationIdentity(pid: 42, identifier: "test.frontmost")
    let focused = FullScreenTestWindow()
    let main = FullScreenTestWindow(id: 2)
    let button = FullScreenTestButton()
    var permission = true
    var permissionReads = 0
    var losePermission = false
    var permissionGranted: Bool { permissionReads += 1; return permission && !(losePermission && permissionReads > 1) }
    var applicationExists = true
    var applicationReads = 0
    var changeApplication = false
    var focusedError: AXError?
    var mainError: AXError? = .noValue
    var changedWindow: FullScreenTestWindow?
    var recheckError: AXError?
    var selections: [WindowSelection] = []
    var messages: [String] = []
    lazy var action = FullScreenWindowAction(accessibility: self, diagnostic: { [unowned self] in self.messages.append($0) })
    func frontmostApplication() -> WindowApplicationIdentity? {
        applicationReads += 1
        if !applicationExists { return nil }
        return changeApplication && applicationReads > 1 ? WindowApplicationIdentity(pid: 99, identifier: "other.app") : identity
    }
    func window(in application: WindowApplicationIdentity, selection: WindowSelection) -> WindowAXValue<any FullScreenWindowHandle> {
        expectEqual(application, identity); selections.append(selection)
        if applicationReads > 1 {
            if let recheckError { return .failure(recheckError) }
            if let changedWindow { return .value(changedWindow) }
        }
        if selection == .focused {
            if let focusedError { return .failure(focusedError) }
            return .value(focused)
        }
        if let mainError { return .failure(mainError) }
        return .value(main)
    }
    func enableButton() { focused.writable = .value(false); focused.buttonResult = .value(button) }
    var mutations: Int { focused.writes.count + main.writes.count + button.presses }
}

let fullScreenWindowActionChecks: [(String, () throws -> Void)] = [
    ("Fullscreen AX enters normal focused window once without pressing button", {
        let f = FullScreenFixture(); expectEqual(f.action.execute(button: 4), .success)
        expectEqual(f.focused.writes, [true]); expectEqual(f.button.presses, 0); expectEqual(f.focused.buttonReads, 0)
        expectEqual(f.selections, [.focused, .focused]); expectEqual(f.action.lastResult, .success)
    }),
    ("Fullscreen AX exits fullscreen window by setting false exactly once", {
        let f = FullScreenFixture(); f.focused.state = .value(true)
        expectEqual(f.action.execute(), .success); expectEqual(f.focused.writes, [false])
        expectTrue(f.messages.contains { $0.contains("originalFullScreen=true target=false") })
    }),
    ("Fullscreen AX repeated completed requests alternate true and false", {
        let f = FullScreenFixture()
        for _ in 0..<4 { expectEqual(f.action.execute(), .success) }
        expectEqual(f.focused.writes, [true, false, true, false]); expectEqual(f.button.presses, 0)
    }),
    ("Fullscreen AX main fallback is used only for missing focused window", {
        let f = FullScreenFixture(); f.focusedError = .noValue; f.mainError = nil
        expectEqual(f.action.execute(), .success); expectEqual(f.main.writes, [true]); expectTrue(f.focused.writes.isEmpty)
        expectEqual(f.selections, [.focused, .main, .focused, .main])
    }),
    ("Fullscreen AX no windows or unsupported window lookup posts nothing", {
        for (focused, main, expected) in [(AXError.noValue, AXError.noValue, ActionExecutionResult.noFocusedWindow),
                                          (.attributeUnsupported, .notImplemented, .unsupported)] {
            let f = FullScreenFixture(); f.focusedError = focused; f.mainError = main
            expectEqual(f.action.execute(), expected); expectEqual(f.mutations, 0)
        }
    }),
    ("Fullscreen AX permission denial and missing application are distinguished", {
        let denied = FullScreenFixture(); denied.permission = false
        expectEqual(denied.action.execute(), .permissionDenied); expectTrue(denied.selections.isEmpty)
        let absent = FullScreenFixture(); absent.applicationExists = false
        expectEqual(absent.action.execute(), .noFrontmostApplication); expectTrue(absent.selections.isEmpty)
    }),
    ("Fullscreen AX lookup communication failures never select unrelated main window", {
        for (error, result) in [(AXError.cannotComplete, ActionExecutionResult.unknownFailure), (.apiDisabled, .permissionDenied)] {
            let f = FullScreenFixture(); f.focusedError = error; f.mainError = nil
            expectEqual(f.action.execute(), result); expectEqual(f.selections, [.focused]); expectEqual(f.mutations, 0)
        }
    }),
    ("Fullscreen AX minimized window is unsupported without mutation", {
        let f = FullScreenFixture(); f.focused.minimizedState = .value(true)
        expectEqual(f.action.execute(), .unsupported); expectEqual(f.mutations, 0)
    }),
    ("Fullscreen AX missing minimized capability does not reject fullscreen-only windows", {
        let f = FullScreenFixture(); f.focused.minimizedState = .failure(.attributeUnsupported)
        expectEqual(f.action.execute(), .success); expectEqual(f.focused.writes, [true])
    }),
    ("Fullscreen AX broken state or permission failures do not silently fall back", {
        for (error, expected) in [(AXError.illegalArgument, ActionExecutionResult.unknownFailure), (.apiDisabled, .permissionDenied), (.cannotComplete, .unknownFailure)] {
            let f = FullScreenFixture(); f.enableButton(); f.focused.state = .failure(error)
            expectEqual(f.action.execute(), expected); expectEqual(f.mutations, 0); expectEqual(f.focused.buttonReads, 0)
        }
    }),
    ("Fullscreen AX readonly state uses documented full screen button once", {
        let f = FullScreenFixture(); f.enableButton()
        expectEqual(f.action.execute(), .success); expectEqual(f.button.presses, 1); expectTrue(f.focused.writes.isEmpty)
        expectTrue(f.messages.contains { $0.contains("executor=nativeAX-fullScreenButton") && $0.contains("result=success") })
    }),
    ("Fullscreen AX unsupported state can toggle documented button without guessing bool", {
        let f = FullScreenFixture(); f.enableButton(); f.focused.state = .failure(.attributeUnsupported)
        expectEqual(f.action.execute(), .success); expectEqual(f.button.presses, 1)
        expectTrue(f.messages.contains { $0.contains("originalFullScreen=unavailable target=toggle") })
    }),
    ("Fullscreen AX writability inspection errors do not silently fall back", {
        let f = FullScreenFixture(); f.enableButton(); f.focused.writable = .failure(.cannotComplete)
        expectEqual(f.action.execute(), .unknownFailure); expectEqual(f.mutations, 0)
    }),
    ("Fullscreen AX no writable attribute or button reports unsupported", {
        let f = FullScreenFixture(); f.focused.writable = .value(false)
        expectEqual(f.action.execute(), .unsupported); expectEqual(f.mutations, 0)
        expectTrue(f.messages.contains { $0.contains("neither writable AXFullScreen nor a full screen button") })
    }),
    ("Fullscreen AX disabled button missing press or unavailable button API never mutates", {
        for capability in [WindowAXValue<Bool>.value(false), .failure(.notImplemented)] {
            let f = FullScreenFixture(); f.enableButton(); f.button.capability = capability
            expectEqual(f.action.execute(), .unsupported); expectEqual(f.mutations, 0)
        }
    }),
    ("Fullscreen AX foreground or focused window change cancels before mutation", {
        let app = FullScreenFixture(); app.changeApplication = true
        expectEqual(app.action.execute(), .cancelled); expectEqual(app.mutations, 0)
        let window = FullScreenFixture(); window.changedWindow = FullScreenTestWindow(id: 9)
        expectEqual(window.action.execute(), .cancelled); expectEqual(window.mutations, 0)
    }),
    ("Fullscreen AX permission loss or window recheck failure stops mutation", {
        let permission = FullScreenFixture(); permission.losePermission = true
        expectEqual(permission.action.execute(), .permissionDenied); expectEqual(permission.mutations, 0)
        let window = FullScreenFixture(); window.recheckError = .cannotComplete
        expectEqual(window.action.execute(), .unknownFailure); expectEqual(window.mutations, 0)
    }),
    ("Fullscreen AX state changed during preflight cancels attribute and button paths", {
        for useButton in [false, true] {
            let f = FullScreenFixture(); if useButton { f.enableButton() }
            f.focused.changedStateOnRecheck = .value(true)
            expectEqual(f.action.execute(), .cancelled); expectEqual(f.mutations, 0)
        }
    }),
    ("Fullscreen AX state recheck failure cannot mutate", {
        let f = FullScreenFixture(); f.focused.changedStateOnRecheck = .failure(.apiDisabled)
        expectEqual(f.action.execute(), .permissionDenied); expectEqual(f.mutations, 0)
    }),
    ("Fullscreen AX rejected setter does not press button or retry", {
        for (error, result) in [(AXError.attributeUnsupported, ActionExecutionResult.unsupported),
                                (.apiDisabled, .permissionDenied), (.cannotComplete, .unknownFailure)] {
            let f = FullScreenFixture(); f.focused.buttonResult = .value(f.button); f.focused.setError = error
            expectEqual(f.action.execute(), result); expectEqual(f.focused.writes, [true]); expectEqual(f.button.presses, 0)
        }
    }),
    ("Fullscreen AX rejected button press returns failure without keyboard retry", {
        let f = FullScreenFixture(); f.enableButton(); f.button.error = .cannotComplete
        expectEqual(f.action.execute(), .unknownFailure); expectEqual(f.button.presses, 1); expectTrue(f.focused.writes.isEmpty)
    }),
    ("Fullscreen AX asynchronous animation and unavailable readback are explicit", {
        for unavailable in [false, true] {
            let f = FullScreenFixture(); f.focused.asynchronous = true
            if unavailable { f.focused.postMutationReadback = .failure(.cannotComplete) }
            expectEqual(f.action.execute(), .success); expectEqual(f.focused.writes, [true])
            expectTrue(f.messages.contains { $0.contains("AX request accepted; observedFullScreen=") && $0.contains("animation requires real-device acceptance") })
        }
    }),
    ("Fullscreen AX diagnostics identify native path target direction button app and result", {
        let f = FullScreenFixture(); _ = f.action.execute(button: 5)
        expectTrue(f.messages.contains { $0.contains("button=5 action=toggleFullScreen frontmost=test.frontmost") })
        expectTrue(f.messages.contains { $0.contains("executor=nativeAX-attribute stage=complete result=success") })
        expectFalse(f.messages.contains { $0.contains("title=") || $0.contains("shortcut") })
    }),
    ("Fullscreen executor routes AX result and never sends keyboard fallback", {
        let f = FullScreenFixture(); var keys = 0
        let executor = MouseButtonActionExecutor(verticalAvailable: { true }, postVertical: { _ in true },
            postKeyboard: { _, _ in keys += 1; return true }, fullScreenWindow: f.action)
        expectTrue(executor.execute(ButtonClickConfiguration(action: .toggleFullScreen), button: 4))
        expectEqual(f.focused.writes, [true]); expectEqual(keys, 0)
        f.focused.setError = .cannotComplete
        expectFalse(executor.execute(ButtonClickConfiguration(action: .toggleFullScreen), button: 5)); expectEqual(keys, 0)
    })
]
