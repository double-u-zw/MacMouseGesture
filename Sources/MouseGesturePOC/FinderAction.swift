import AppKit
import ApplicationServices

final class FinderAction {
    private let openHome: () -> Bool
    private let performOnMain: (@escaping () -> Void) -> Void
    private let permissionGranted: () -> Bool
    private let frontmostApplication: () -> WindowApplicationIdentity?
    private let postNewFolder: (pid_t) -> Bool
    private let diagnostic: (String) -> Void

    init(openHome: @escaping () -> Bool = {
             NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: NSHomeDirectory())
         }, performOnMain: @escaping (@escaping () -> Void) -> Void = { work in
             if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
         }, permissionGranted: @escaping () -> Bool = { AXIsProcessTrusted() },
         frontmostApplication: @escaping () -> WindowApplicationIdentity? = {
             guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
             return WindowApplicationIdentity(pid: app.processIdentifier, identifier: app.bundleIdentifier ?? "pid:\(app.processIdentifier)")
         }, postNewFolder: @escaping (pid_t) -> Bool = FinderAction.postNewFolder,
         diagnostic: @escaping (String) -> Void = { _ in }) {
        self.openHome = openHome; self.performOnMain = performOnMain
        self.permissionGranted = permissionGranted; self.frontmostApplication = frontmostApplication
        self.postNewFolder = postNewFolder; self.diagnostic = diagnostic
    }

    // Queue AppKit work without waiting on the main thread: the main-thread UI
    // snapshot can itself wait on the gesture queue. True means queued, and the
    // completion diagnostic records Finder's actual acknowledgement.
    @discardableResult func open(button: Int? = nil) -> Bool {
        let prefix = "[MappingAction] button=\(button.map(String.init) ?? "unspecified") action=openFinder executor=NSWorkspace"
        diagnostic("\(prefix) stage=request result=queued")
        performOnMain { [openHome, diagnostic] in
            let opened = openHome()
            diagnostic("\(prefix) stage=complete result=\(opened ? "success" : "failed")")
        }
        return true
    }

    @discardableResult func newFolder(button: Int? = nil) -> ActionExecutionResult {
        let application = frontmostApplication()
        let prefix = "[MappingAction] button=\(button.map(String.init) ?? "unspecified") action=newFolder executor=FinderKeyboard frontmost=\(application?.identifier ?? "none")"
        func finish(_ result: ActionExecutionResult, _ reason: String) -> ActionExecutionResult {
            diagnostic("\(prefix) result=\(result.rawValue) reason=\(reason)")
            return result
        }
        guard let application else { return finish(.noFrontmostApplication, "no active application") }
        guard application.identifier == "com.apple.finder", application.pid > 0 else {
            return finish(.unsupported, "Finder must be frontmost; no keyboard event sent")
        }
        guard permissionGranted() else { return finish(.permissionDenied, "Accessibility unavailable") }
        guard frontmostApplication() == application else { return finish(.cancelled, "foreground changed") }
        guard permissionGranted() else { return finish(.permissionDenied, "Accessibility lost before posting") }
        guard postNewFolder(application.pid) else { return finish(.eventPostFailed, "keyboard event pair unavailable") }
        return finish(.success, "Command-Shift-N pair submitted to Finder; creation and naming require Finder acceptance")
    }

    static func postNewFolder(_ pid: pid_t) -> Bool {
        guard pid > 0, let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 45, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 45, keyDown: false) else { return false }
        down.flags = [.maskCommand, .maskShift]; up.flags = down.flags
        // Target the captured Finder process, never the global keyboard stream.
        // A late foreground switch cannot send New Folder to another app.
        down.postToPid(pid); up.postToPid(pid)
        return true
    }
}
