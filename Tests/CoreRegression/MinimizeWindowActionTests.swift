import Foundation
import ApplicationServices

private final class MinimizeTestWindow: MinimizeWindowHandle {
    let id: Int
    var state: WindowAXValue<Bool> = .value(false)
    var writable: WindowAXValue<Bool> = .value(true)
    var setError = AXError.success
    var observedAfterSet: WindowAXValue<Bool> = .value(true)
    var sets = 0
    var writabilityReads = 0
    init(id: Int = 1) { self.id = id }
    func minimized() -> WindowAXValue<Bool> { sets > 0 && setError == .success ? observedAfterSet : state }
    func minimizable() -> WindowAXValue<Bool> { writabilityReads += 1; return writable }
    func setMinimized() -> AXError { sets += 1; return setError }
    func isSameWindow(as other: any MinimizeWindowHandle) -> Bool { (other as? MinimizeTestWindow)?.id == id }
}

private final class MinimizeFixture: MinimizeWindowAccessibility {
    let original = WindowApplicationIdentity(pid: 42, identifier: "test.frontmost")
    let focused = MinimizeTestWindow()
    let main = MinimizeTestWindow(id: 2)
    var permission = true
    var losePermissionOnRecheck = false
    var permissionReads = 0
    var permissionGranted: Bool {
        permissionReads += 1
        return permission && !(losePermissionOnRecheck && permissionReads > 1)
    }
    var applicationExists = true
    var switchApplicationOnRecheck = false
    var applicationReads = 0
    var focusedError: AXError?
    var mainError: AXError? = .noValue
    var changedWindow: MinimizeTestWindow?
    var recheckError: AXError?
    var selections: [WindowSelection] = []
    var messages: [String] = []
    lazy var action = MinimizeWindowAction(accessibility: self, diagnostic: { [unowned self] in self.messages.append($0) })
    func frontmostApplication() -> WindowApplicationIdentity? {
        applicationReads += 1
        guard applicationExists else { return nil }
        if switchApplicationOnRecheck && applicationReads > 1 {
            return WindowApplicationIdentity(pid: 99, identifier: "different.app")
        }
        return original
    }
    func window(in application: WindowApplicationIdentity, selection: WindowSelection) -> WindowAXValue<any MinimizeWindowHandle> {
        expectEqual(application, original)
        selections.append(selection)
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
    var mutations: Int { focused.sets + main.sets + (changedWindow?.sets ?? 0) }
}

let minimizeWindowActionChecks: [(String, () throws -> Void)] = [
    ("Minimize AX acts on focused window exactly once", {
        let f = MinimizeFixture(); expectEqual(f.action.execute(button: 4), .success)
        expectEqual(f.focused.sets, 1); expectEqual(f.main.sets, 0); expectEqual(f.selections, [.focused, .focused])
        expectEqual(f.action.lastResult, .success)
        expectTrue(f.messages.contains { $0.contains("observedMinimized=true") })
    }),
    ("Minimize AX falls back to main when focused window has no value", {
        let f = MinimizeFixture(); f.focusedError = .noValue; f.mainError = nil
        expectEqual(f.action.execute(), .success); expectEqual(f.main.sets, 1); expectEqual(f.focused.sets, 0)
        expectEqual(f.selections, [.focused, .main, .focused, .main])
    }),
    ("Minimize AX main fallback supports unavailable focused attribute", {
        let f = MinimizeFixture(); f.focusedError = .attributeUnsupported; f.mainError = nil
        expectEqual(f.action.execute(), .success); expectEqual(f.main.sets, 1)
    }),
    ("Minimize AX missing both windows safely reports noFocusedWindow", {
        let f = MinimizeFixture(); f.focusedError = .noValue
        expectEqual(f.action.execute(), .noFocusedWindow); expectEqual(f.mutations, 0)
        expectTrue(f.messages.contains { $0.contains("windowFound=false") && $0.contains("result=noFocusedWindow") })
    }),
    ("Minimize AX unsupported window attributes report unsupported", {
        let f = MinimizeFixture(); f.focusedError = .attributeUnsupported; f.mainError = .notImplemented
        expectEqual(f.action.execute(), .unsupported); expectEqual(f.mutations, 0)
    }),
    ("Minimize AX missing foreground application never inspects windows", {
        let f = MinimizeFixture(); f.applicationExists = false
        expectEqual(f.action.execute(), .noFrontmostApplication); expectTrue(f.selections.isEmpty); expectEqual(f.mutations, 0)
    }),
    ("Minimize AX permission denial never queries or mutates windows", {
        let f = MinimizeFixture(); f.permission = false
        expectEqual(f.action.execute(), .permissionDenied); expectTrue(f.selections.isEmpty); expectEqual(f.mutations, 0)
    }),
    ("Minimize AX focused lookup errors do not target an unrelated main window", {
        for error in [AXError.cannotComplete, .invalidUIElement, .illegalArgument, .apiDisabled] {
            let f = MinimizeFixture(); f.focusedError = error; f.mainError = nil
            expectEqual(f.action.execute(), error == .apiDisabled ? .permissionDenied : .unknownFailure)
            expectEqual(f.selections, [.focused]); expectEqual(f.mutations, 0)
        }
    }),
    ("Minimize AX missing minimized attribute does not blindly write", {
        let f = MinimizeFixture(); f.focused.state = .failure(.attributeUnsupported)
        expectEqual(f.action.execute(), .unsupported); expectEqual(f.mutations, 0); expectEqual(f.focused.writabilityReads, 0)
    }),
    ("Minimize AX nonwritable window safely reports unsupported", {
        let f = MinimizeFixture(); f.focused.writable = .value(false)
        expectEqual(f.action.execute(), .unsupported); expectEqual(f.mutations, 0)
    }),
    ("Minimize AX writability failures preserve distinct results", {
        for (error, result) in [(AXError.apiDisabled, ActionExecutionResult.permissionDenied),
                                (.notImplemented, .unsupported), (.cannotComplete, .unknownFailure)] {
            let f = MinimizeFixture(); f.focused.writable = .failure(error)
            expectEqual(f.action.execute(), result); expectEqual(f.mutations, 0)
        }
    }),
    ("Minimize AX rejected setter cannot report success or retry", {
        for (error, result) in [(AXError.apiDisabled, ActionExecutionResult.permissionDenied),
                                (.attributeUnsupported, .unsupported), (.cannotComplete, .unknownFailure), (.invalidUIElement, .unknownFailure)] {
            let f = MinimizeFixture(); f.focused.setError = error
            expectEqual(f.action.execute(), result); expectEqual(f.focused.sets, 1); expectEqual(f.action.lastResult, result)
            expectTrue(f.messages.contains { $0.contains("set AXMinimized=true AXError=\(error.rawValue)") })
        }
    }),
    ("Minimize AX already minimized is idempotent and never restores window", {
        let f = MinimizeFixture(); f.focused.state = .value(true)
        for _ in 0..<3 { expectEqual(f.action.execute(), .success) }
        expectEqual(f.mutations, 0); expectEqual(f.focused.writabilityReads, 0)
    }),
    ("Minimize AX foreground changes before mutation cancel safely", {
        let f = MinimizeFixture(); f.switchApplicationOnRecheck = true
        expectEqual(f.action.execute(), .cancelled); expectEqual(f.mutations, 0)
        expectTrue(f.messages.contains { $0.contains("foreground changed before mutation") })
    }),
    ("Minimize AX current window changes before mutation cancel safely", {
        let f = MinimizeFixture(); f.changedWindow = MinimizeTestWindow(id: 3)
        expectEqual(f.action.execute(), .cancelled); expectEqual(f.mutations, 0)
    }),
    ("Minimize AX permission lost before mutation stops execution", {
        let f = MinimizeFixture(); f.losePermissionOnRecheck = true
        expectEqual(f.action.execute(), .permissionDenied); expectEqual(f.mutations, 0); expectEqual(f.selections, [.focused])
    }),
    ("Minimize AX recheck failure stops before setter", {
        let f = MinimizeFixture(); f.recheckError = .cannotComplete
        expectEqual(f.action.execute(), .unknownFailure); expectEqual(f.mutations, 0)
    }),
    ("Minimize AX asynchronous or unavailable readback is diagnosed as accepted request", {
        for observed in [WindowAXValue<Bool>.value(false), .failure(.cannotComplete)] {
            let f = MinimizeFixture(); f.focused.observedAfterSet = observed
            expectEqual(f.action.execute(), .success); expectEqual(f.focused.sets, 1)
            expectTrue(f.messages.contains { $0.contains("AXMinimized=true accepted; observedMinimized=") && $0.contains("animation requires real-device acceptance") })
        }
    }),
    ("Minimize AX diagnostics identify path button app and result without titles", {
        let f = MinimizeFixture(); _ = f.action.execute(button: 5)
        expectTrue(f.messages.contains { $0.contains("button=5 action=minimizeWindow executor=nativeAX frontmost=test.frontmost stage=request") })
        expectTrue(f.messages.contains { $0.contains("stage=complete result=success") })
        expectFalse(f.messages.contains { $0.contains("title=") || $0.contains("keyboard") })
    }),
    ("Minimize executor routes to AX and never sends keyboard fallback", {
        let f = MinimizeFixture(); var keyboardPosts = 0
        let executor = MouseButtonActionExecutor(verticalAvailable: { true }, postVertical: { _ in true },
            postKeyboard: { _, _ in keyboardPosts += 1; return true }, minimizeWindow: f.action)
        expectTrue(executor.execute(ButtonClickConfiguration(action: .minimizeWindow), button: 4))
        expectEqual(f.focused.sets, 1); expectEqual(keyboardPosts, 0)
        f.focused.setError = .cannotComplete
        expectFalse(executor.execute(ButtonClickConfiguration(action: .minimizeWindow), button: 5))
        expectEqual(keyboardPosts, 0)
        expectTrue(f.messages.contains { $0.contains("button=5 action=minimizeWindow") && $0.contains("result=unknownFailure") })
    })
]
