import AppKit
import SwiftUI
import ApplicationServices
import GestureCore
import Darwin

if CommandLine.arguments.contains("--probe") {
    let backend = MacOS27GestureBackend()
    let vertical = backend.probeVertical()
    print("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString); arch: arm64")
    print("Accessibility: \(AXIsProcessTrusted()); Input Monitoring: \(CGPreflightListenEventAccess())")
    print(DiagnosticRedactor.redact(backend.status))
    print(DiagnosticRedactor.redact(vertical.status))
    print("No events posted. Hardware input and interactive Dock response remain unverified.")
    exit(backend.available && vertical.available ? 0 : 1)
}

final class MacMouseGestureApp: NSObject, NSApplicationDelegate {
    // Explicit development entry point; normal launch follows persisted gesture settings.
    private let verticalPOC = CommandLine.arguments.contains("--vertical-poc")
    private let diagnostics = Diagnostics()
    private lazy var engine = GestureEngine(log: diagnostics)
    private let store = ConfigStore()
    private let loginItem = LoginItemController()
    private lazy var model = AppViewModel()
    private var automatic = AutoStartState()
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?
    private var enableMenuItem: NSMenuItem?
    private var refresh: Timer?
    private var settingDebounce: Timer?
    private var observers: [NSObjectProtocol] = []
    private var signalSources: [DispatchSourceSignal] = []
    private let instance = SingleInstance()
    private var hadAccessibility = false
    private var ownsInstance = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Older builds used a directory-local lock. Do not run beside a live legacy copy.
        let legacy = NSRunningApplication.runningApplications(withBundleIdentifier: ProductIdentity.legacy)
            .first { other in
                guard other.processIdentifier != getpid(), let url = other.bundleURL,
                      let bundle = Bundle(url: url) else { return false }
                return (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String).flatMap(Int.init).map { $0 < 13 } ?? true
            }
        let result = legacy == nil ? instance.acquire() : .alreadyRunning
        guard result == .acquired else {
            if result == .alreadyRunning {
                (legacy ?? [ProductIdentity.current, ProductIdentity.legacy]
                    .flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0) }
                    .first { $0.processIdentifier != getpid() })?.activate(options: [])
                NSLog("MacMouseGesture 已在运行；此副本退出。")
            } else {
                let alert = NSAlert()
                alert.messageText = "无法启动 MacMouseGesture"
                alert.informativeText = "无法访问用户级运行锁。请确认当前用户的资源库可写后重新打开。"
                alert.runModal()
            }
            NSApp.terminate(nil)
            return
        }
        ownsInstance = true
        ProductIdentity.migrateSettings()
        model.show(store.load())
        if !model.config.shouldRun { automatic.stop() }
        NSApp.setActivationPolicy(.accessory)
        installApplicationMenu()
        installStatusMenu()
        installModelActions()
        installLifecycleObservers()
        engine.onStatus = { [weak self] in self?.update() }
        engine.onInputDeviceRemoved = { [weak self] in
            guard let self, self.model.config.shouldRun else { return }
            if self.automatic.inputDeviceRemoved(at: monotonicTime()) {
                self.diagnostics.log("INFO", "Mouse removed; scheduling bounded input recovery")
                self.update()
            } else {
                self.model.message = "鼠标连接频繁变化，自动恢复已暂停。连接稳定后请点击“重新启动手势引擎”。"
            }
        }
        refresh = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.update() }
        diagnostics.log("INFO", "macOS \(ProcessInfo.processInfo.operatingSystemVersionString); arm64; Beta Preview")
        update()
        if DiagnosticRedactor.installation() != "Applications" {
            model.message = "建议将 MacMouseGesture 移动到“应用程序”文件夹。"
        }
        if model.onboardingVisible || !AXIsProcessTrusted() || model.message != nil { showSettings(.general) }
    }

    private func installApplicationMenu() {
        let root = NSMenu()
        let app = NSMenuItem()
        root.addItem(app)
        let appMenu = NSMenu(title: "MacMouseGesture")
        app.submenu = appMenu
        appMenu.addItem(withTitle: "设置…", action: #selector(openSettingsFromMenu), keyEquivalent: ",").target = self
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "退出 MacMouseGesture", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let edit = NSMenuItem()
        root.addItem(edit)
        let editMenu = NSMenu(title: "编辑")
        edit.submenu = editMenu
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = root
    }

    private func installStatusMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        if let button = item.button {
            let icon = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "MacMouseGesture")
            icon?.isTemplate = true
            button.image = icon
            button.toolTip = "MacMouseGesture"
        }
        let menu = NSMenu(title: "MacMouseGesture")
        let title = NSMenuItem(title: "MacMouseGesture", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        let state = NSMenuItem(title: "○ 已停用", action: nil, keyEquivalent: "")
        state.isEnabled = false
        menu.addItem(state)
        statusMenuItem = state
        menu.addItem(NSMenuItem.separator())
        let enable = NSMenuItem(title: "启用鼠标手势", action: #selector(toggleEnabledFromMenu), keyEquivalent: "")
        enable.target = self
        menu.addItem(enable)
        enableMenuItem = enable
        let settings = NSMenuItem(title: "设置…", action: #selector(openSettingsFromMenu), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(NSMenuItem.separator())
        let about = NSMenuItem(title: "关于 MacMouseGesture", action: #selector(openAboutFromMenu), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(withTitle: "退出 MacMouseGesture", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
    }

    private func installModelActions() {
        model.finishOnboarding = { [weak self] in
            guard let self, self.model.onboarding.step == .complete else { return }
            self.model.onboarding.persistCompletion()
            self.model.onboardingVisible = false
        }
        model.reopenOnboarding = { [weak self] in
            self?.model.onboarding = OnboardingState()
            self?.model.onboardingVisible = true
        }
        model.applyConfig = { [weak self] config, debounce in self?.apply(config, debounce: debounce) }
        model.setLoginEnabled = { [weak self] enabled in self?.setLogin(enabled) }
        model.openAccessibility = { [weak self] in self?.openSystemSettings("Privacy_Accessibility") }
        model.openInputMonitoring = { [weak self] in self?.openSystemSettings("Privacy_ListenEvent") }
        model.openLoginItems = { [weak self] in self?.loginItem.openSettings() }
        model.copyDiagnostics = { [weak self] in self?.copyDiagnostics() }
        model.saveDiagnostics = { [weak self] in self?.saveDiagnostics() }
        model.restartEngine = { [weak self] in self?.restartEngine() }
    }

    private func installLifecycleObservers() {
        let center = NSWorkspace.shared.notificationCenter
        let suspensions: [(Notification.Name, AutoStartState.Suspension)] = [
            (NSWorkspace.willSleepNotification, .sleep),
            (NSWorkspace.sessionDidResignActiveNotification, .inactiveSession),
            (NSWorkspace.screensDidSleepNotification, .screenSleep)
        ]
        for (name, reason) in suspensions {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                self.automatic.suspend(reason)
                self.engine.stop("sleep / session inactive")
                self.update()
            })
        }
        let resumptions: [(Notification.Name, AutoStartState.Suspension)] = [
            (NSWorkspace.didWakeNotification, .sleep),
            (NSWorkspace.sessionDidBecomeActiveNotification, .inactiveSession),
            (NSWorkspace.screensDidWakeNotification, .screenSleep)
        ]
        for (name, reason) in resumptions {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                self.automatic.resume(reason)
                self.update()
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                self.engine.stop("display configuration changed")
                self.automatic.requestRestartIfEnabled()
                self.update()
            })
        for number in [SIGINT, SIGTERM] {
            Darwin.signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }
            source.resume()
            signalSources.append(source)
        }
    }

    private func makeWindow() -> NSWindow {
        if let window { return window }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 550, height: 620),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "MacMouseGesture 设置"
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.contentView = NSHostingView(rootView: SettingsView(model: model))
        window.center()
        self.window = window
        return window
    }

    private func showSettings(_ tab: SettingsTab) {
        model.selectedTab = tab
        let window = makeWindow()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        update()
    }

    private func apply(_ config: AppConfig, debounce: Bool = false) {
        let next = config.validated()
        guard next != model.config else { return }
        settingDebounce?.invalidate()
        model.show(next)
        store.save(next)
        model.message = nil
        if !next.shouldRun {
            automatic.stop()
            engine.stop("disabled in settings")
        } else if debounce {
            settingDebounce = Timer.scheduledTimer(withTimeInterval: 0.22, repeats: false) { [weak self] _ in
                guard let self, self.model.config.shouldRun else { return }
                self.automatic.requestStart()
                self.update()
            }
        } else {
            automatic.requestStart()
        }
        update()
    }

    private func start(_ experiment: Experiment) {
        engine.start(experiment, buttons: model.config.gestureButtons,
                     freeze: model.config.freezePointer, config: model.config.gestureConfig,
                     horizontalEnabled: model.config.horizontalEnabled)
    }

    private func restartEngine() {
        guard model.config.shouldRun else {
            model.message = "请先启用 MacMouseGesture 和至少一种手势。"
            return
        }
        settingDebounce?.invalidate()
        automatic.requestStart()
        update()
    }

    private func setLogin(_ enabled: Bool) {
        do {
            try loginItem.setEnabled(enabled)
            model.message = nil
        } catch {
            model.message = DiagnosticRedactor.redact("无法更改登录启动设置：\(error.localizedDescription)")
            diagnostics.log("WARN", model.message ?? "Launch at Login failed")
        }
        model.loginState = loginItem.state
        updateMenu()
    }

    private func openSystemSettings(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func report() -> String {
        DiagnosticRedactor.redact("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\nArchitecture: arm64\n" +
        "Version: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")\n" +
        "Build: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown")\n" +
        "Git Commit: \(Bundle.main.object(forInfoDictionaryKey: "GitCommit") as? String ?? "unknown")\n" +
        "安装位置：\(DiagnosticRedactor.installation())\n" +
        "Accessibility: \(AXIsProcessTrusted())\nInput Monitoring: \(CGPreflightListenEventAccess())\n" +
        "Input: CGEventTap / optional IOHIDManager\nBackend: \(engine.backend.status)\n" +
        "Config: enabled=\(model.config.enabled); horizontalEnabled=\(model.config.horizontalEnabled); verticalEnabled=\(model.config.verticalEnabled); " +
        "buttons=\(model.config.buttonText); invert=\(model.config.horizontalInvert); " +
        "pixels/progress=\(model.config.sensitivity); deadZone=\(model.config.deadZone); " +
        "freeze=\(model.config.freezePointer)\n" +
        "\(engine.diagnosticsSnapshot())\n\(engine.status)\n\n\(diagnostics.snapshot())")
    }

    private func copyDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report(), forType: .string)
        model.message = "诊断信息已复制。"
    }

    private func saveDiagnostics() {
        let text = report()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MacMouseGesture-诊断.txt"
        panel.allowedContentTypes = [.plainText]
        panel.begin { [weak self] result in
            guard result == .OK, let url = panel.url else { return }
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                self?.model.message = "诊断快照已保存。"
            } catch {
                self?.model.message = DiagnosticRedactor.redact("无法保存诊断快照：\(error.localizedDescription)")
            }
        }
    }

    private func updateMenu() {
        let prefix = model.status == .disabled ? "○" : "●"
        statusMenuItem?.title = "\(prefix) \(model.status.displayLabel)"
        enableMenuItem?.state = model.config.enabled ? .on : .off
    }

    private func update() {
        let authorized = AXIsProcessTrusted()
        if hadAccessibility && !authorized {
            engine.stop("Accessibility revoked")
            automatic.requestRestartIfEnabled()
            if !model.onboardingVisible { model.message = "需要重新授权：请前往系统设置 → 隐私与安全性 → 辅助功能。" }
        }
        hadAccessibility = authorized
        if automatic.takeStartIfReady(permissionGranted: authorized) {
            start(verticalPOC ? .missionControlPOC : .horizontal)
        }
        model.accessibilityGranted = authorized
        model.inputMonitoringGranted = CGPreflightListenEventAccess()
        model.loginState = loginItem.state
        model.status = UserStatus.resolve(config: model.config, accessibility: authorized,
                                          pendingStart: automatic.pendingStart, engineStatus: engine.status)
        model.snapshot = engine.uiSnapshot()
        let input = engine.onboardingInput()
        model.sideButtonCount = input.count
        model.lastSideButton = input.label
        model.onboarding.observe(buttons: input.count)
        model.waitingForButton = model.onboarding.waitingHint(at: monotonicTime())
        if window?.isVisible == true && model.selectedTab == .diagnostics { model.advancedReport = report() }
        updateMenu()
    }

    @objc private func toggleEnabledFromMenu() {
        var next = model.config
        next.enabled.toggle()
        apply(next)
    }
    @objc private func toggleLoginFromMenu() { setLogin(!model.loginState.isSelected) }
    @objc private func openSettingsFromMenu() { showSettings(.general) }
    @objc private func openDiagnosticsFromMenu() { showSettings(.diagnostics) }
    @objc private func openAboutFromMenu() { showSettings(.about) }
    @objc private func restartFromMenu() { restartEngine() }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings(.general)
        return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        settingDebounce?.invalidate()
        automatic.stop()
        refresh?.invalidate()
        if ownsInstance { engine.shutdown() }
    }
}

let app = NSApplication.shared
let controller = MacMouseGestureApp()
app.delegate = controller
app.run()
