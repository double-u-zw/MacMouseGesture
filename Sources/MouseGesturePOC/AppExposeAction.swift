import AppKit
import ApplicationServices
import GestureCore

struct AppExposeTarget {
    let application: String?
    let result: ActionExecutionResult
    let reason: String

    // Read only public AX attributes, never window titles or application content.
    static func current() -> AppExposeTarget {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return AppExposeTarget(application: nil, result: .noFrontmostApplication, reason: "no active application")
        }
        let identifier = app.bundleIdentifier ?? "pid:\(app.processIdentifier)"
        func target(_ result: ActionExecutionResult, _ reason: String) -> AppExposeTarget {
            AppExposeTarget(application: identifier, result: result, reason: reason)
        }
        guard AXIsProcessTrusted() else { return target(.permissionDenied, "Accessibility unavailable") }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.2)
        var errors: [AXError] = []
        var found = false
        for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute, kAXWindowsAttribute] {
            var value: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
            errors.append(error)
            guard error == .success, let value else { continue }
            if attribute == kAXWindowsAttribute {
                // Minimized windows can still be exposed, even without a focused window.
                found = (value as? [AXUIElement])?.isEmpty == false
            } else {
                found = CFGetTypeID(value) == AXUIElementGetTypeID()
            }
            if found { break }
        }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else {
            return target(.cancelled, "foreground changed during window inspection")
        }
        if found { return target(.success, "foreground application has an AX window") }
        if errors.contains(.apiDisabled) { return target(.permissionDenied, "AX API disabled") }
        if errors.contains(.cannotComplete) { return target(.unknownFailure, "AX window inspection did not complete") }
        if errors.allSatisfy({ $0 == .attributeUnsupported || $0 == .notImplemented }) {
            return target(.unsupported, "application does not expose AX window attributes")
        }
        return target(.noFocusedWindow, "no focused, main or listed AX window")
    }
}

// Reuse the frozen, real-device-accepted one-shot timer and cancellation path.
// Mirroring BOTH progress and velocity sends the existing down-drag HID action;
// the Mission Control implementation and all physical gesture code stay intact.
final class AppExposeAction {
    private let permissionGranted: () -> Bool
    private let inspectTarget: () -> AppExposeTarget
    private let systemEnabled: () -> Bool?
    private let diagnostic: (String) -> Void
    private var target: AppExposeTarget?
    private var rejectedResult: ActionExecutionResult?
    private var driver: MissionControlAction!
    var isRunning: Bool { driver.isRunning }
    var lastResult: ActionExecutionResult? { rejectedResult ?? driver.lastResult }

    init(queue: DispatchQueue, clock: @escaping () -> Double = monotonicTime,
         permissionGranted: @escaping () -> Bool = { AXIsProcessTrusted() },
         inspectTarget: @escaping () -> AppExposeTarget = AppExposeTarget.current,
         systemEnabled: @escaping () -> Bool? = {
             UserDefaults.standard.persistentDomain(forName: "com.apple.dock")?["showAppExposeGestureEnabled"] as? Bool
         }, verticalAvailable: @escaping () -> Bool,
         postVertical: @escaping (GestureFrame) -> Bool,
         diagnostic: @escaping (String) -> Void = { _ in }, automaticScheduling: Bool = true) {
        self.permissionGranted = permissionGranted; self.inspectTarget = inspectTarget
        self.systemEnabled = systemEnabled; self.diagnostic = diagnostic
        driver = MissionControlAction(queue: queue, clock: clock, permissionGranted: permissionGranted,
            verticalAvailable: verticalAvailable, frontmostApplication: { [weak self] in self?.target?.application },
            postVertical: { postVertical(GestureFrame($0.phase, -$0.progress, -$0.velocity)) },
            // The shared driver identifies its original action in diagnostics.
            // This adapter owns only App Exposé instances of that driver.
            diagnostic: { diagnostic($0.replacingOccurrences(of: "action=missionControl", with: "action=appExpose")) },
            automaticScheduling: automaticScheduling)
    }

    @discardableResult func start(button: Int? = nil) -> ActionExecutionResult {
        let prefix = "[ShortClick] button=\(button.map(String.init) ?? "unspecified") action=appExpose executor=nativeHID-oneShot"
        func reject(_ result: ActionExecutionResult, _ reason: String, application: String? = nil) -> ActionExecutionResult {
            if !isRunning { rejectedResult = result }
            diagnostic("\(prefix) frontmost=\(application ?? "none") stage=rejected result=\(result.rawValue) reason=\(reason)")
            return result
        }
        guard !isRunning else { return reject(.unsupported, "one-shot already running", application: target?.application) }
        guard permissionGranted() else { return reject(.permissionDenied, "Accessibility unavailable") }
        let inspected = inspectTarget()
        guard inspected.result == .success else {
            return reject(inspected.result, inspected.reason, application: inspected.application)
        }
        guard inspected.application != nil else { return reject(.noFrontmostApplication, "no active application") }
        let enabled = systemEnabled()
        diagnostic("\(prefix) frontmost=\(inspected.application!) stage=preflight windowFound=true systemGestureEnabled=\(enabled.map(String.init) ?? "notOverridden")")
        guard enabled != false else {
            return reject(.systemFeatureUnavailable, "Dock App Exposé gesture disabled", application: inspected.application)
        }
        target = inspected; rejectedResult = nil
        return driver.start(button: button)
    }
    func advance() { driver.advance() }
    func cancel(reason: String) { driver.cancel(reason: reason) }
}
