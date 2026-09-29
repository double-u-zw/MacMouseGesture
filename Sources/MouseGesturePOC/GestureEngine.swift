import Foundation
import ApplicationServices
import GestureCore
import SystemGestureBridge

protocol SystemGestureBackend {
    var status: String { get }
    var available: Bool { get }
    func send(_ frame: GestureFrame) -> Bool
}

final class MacOS27GestureBackend: SystemGestureBackend {
    let available: Bool
    let status: String
    init() {
        var buffer = [CChar](repeating: 0, count: 512)
        available = MGBackendProbe(&buffer, UInt(buffer.count))
        status = String(cString: buffer)
    }
    func send(_ frame: GestureFrame) -> Bool {
        MGPostHorizontal(frame.progress, frame.velocity, frame.phase.rawValue)
    }
    func probeVertical() -> (available: Bool, status: String) {
        var buffer = [CChar](repeating: 0, count: 512)
        let available = MGVerticalProbe(&buffer, UInt(buffer.count))
        return (available, String(cString: buffer))
    }
    func sendVertical(_ frame: GestureFrame) -> Bool {
        MGPostVertical(frame.progress, frame.velocity, frame.phase.rawValue)
    }
}

enum Experiment: String {
    case cgInput = "CG input observation", hidInput = "HID input observation"
    case horizontal = "Horizontal / vertical system gestures"
    case missionControlPOC = "Mission Control / App Exposé vertical HID POC + horizontal Spaces"
    var usesGestures: Bool { self == .horizontal || self == .missionControlPOC }
}

private enum PostingAxis { case horizontal, vertical }

final class GestureEngine {
    let log: Diagnostics
    let backend = MacOS27GestureBackend()
    private let queue = DispatchQueue(label: "MouseGesture.Engine", qos: .userInteractive)
    private var hook: CGEventTapBackend?
    private var hid: HIDInputBackend?
    private var mailbox: InputMailbox?
    private var signal: DispatchSourceUserDataAdd?
    private var timer: DispatchSourceTimer?
    private var lease: DispatchSourceTimer?
    private var healthTimer: DispatchSourceTimer?
    private var counters = GestureCounters()
    private var previousInput = InputCounters()
    private var recoveryBudget = TapRecoveryBudget()
    private let performance = PerformanceSampler()
    private var machine = GestureMachine()
    private var verticalGesture = VerticalGestureTracker()
    private var horizontalEnabled = false
    private var verticalEnabled = false
    private var lastGestureAxis = "none"
    private var lastVerticalAction = "none"
    private var verticalBegins = 0
    private var missionControlGestures = 0
    private var appExposeGestures = 0
    private var experiment: Experiment?
    private var lastPermissionCheck = 0.0
    private var lastTrace = 0.0
    private var sessionID = 0
    private let statusLock = NSLock()
    private var statusText = "Stopped — no mouse events consumed"
    var onStatus: (() -> Void)?
    init(log: Diagnostics) { self.log = log; log.log("INFO", backend.status) }
    var status: String { statusLock.lock(); defer { statusLock.unlock() }; return statusText }
    func uiSnapshot() -> EngineUISnapshot {
        queue.sync {
            EngineUISnapshot(eventTap: hook?.health ?? "stopped", hidActive: hid != nil,
                             gestureState: machine.state.rawValue, started: counters.gestureBegins, completed: counters.gestureEnds,
                             cancelled: counters.gestureCancels, open: counters.openGestures,
                             eventTapRestarts: counters.eventTapRestarts, postFailures: counters.postFailures,
                             sequenceErrors: counters.sequenceErrors)
        }
    }
    // Read-only UI feedback; no input handling or gesture parameter changes.
    func onboardingInput() -> (count: Int, label: String) {
        queue.sync {
            var input = previousInput
            if let mailbox { input.add(mailbox.counts()) }
            let label = "侧键 1：\(input.button4Downs) 次 · 侧键 2：\(input.button5Downs) 次"
            return (input.button4Downs + input.button5Downs, label)
        }
    }
    func diagnosticsSnapshot() -> String {
        queue.sync {
            var input = previousInput
            if let mailbox { input.add(mailbox.counts()) }
            let vertical = "Last Gesture Axis: \(lastGestureAxis); Last Vertical Action: \(lastVerticalAction)\n" +
                "verticalBegins=\(verticalBegins); missionControlGestures=\(missionControlGestures); appExposeGestures=\(appExposeGestures)\n" +
                (verticalEnabled ? "Vertical gesture: action=\(verticalGesture.action.rawValue); rawDy=\(verticalGesture.rawY); progress=\(verticalGesture.progress); emitted=\(verticalGesture.emittedEvents)\n" : "")
            return "Event tap: \(hook?.health ?? "stopped"); gestureState=\(machine.state.rawValue)\n" + vertical +
                input.summary(at: monotonicTime()) + "\n" + counters.summary + "\n" +
                performance.sample(completed: counters.gestureEnds + counters.gestureCancels)
        }
    }
    private func setStatus(_ text: String) {
        statusLock.lock(); statusText = text; statusLock.unlock()
        DispatchQueue.main.async { [weak self] in self?.onStatus?() }
    }
    func start(_ mode: Experiment, buttons: Set<Int>, freeze: Bool,
               config: GestureConfig, horizontalEnabled: Bool = true) {
        queue.async { [self] in
            stopOnQueue("restart")
            guard !buttons.isEmpty, buttons.allSatisfy({ (2...31).contains($0) }) else {
                setStatus("CG buttons must be comma-separated numbers in 2…31"); return
            }
            let buttonList = buttons.sorted().map(String.init).joined(separator: ",")
            let requestedHorizontal = mode.usesGestures && horizontalEnabled
            let requestedVertical = mode == .missionControlPOC || (mode == .horizontal && config.verticalEnabled)
            guard !mode.usesGestures || requestedHorizontal || requestedVertical else {
                setStatus("请至少启用一种手势。"); return
            }
            var allowVertical = requestedVertical
            if mode.usesGestures {
                guard backend.available else {
                    log.log("ERROR", "Interactive backend unavailable: \(backend.status)")
                    setStatus("无法启动：交互式后端不可用。\(backend.status)")
                    return
                }
                guard AXIsProcessTrusted() else {
                    log.log("ERROR", "Accessibility denied. Check the permission for this exact bundle. Signing and migration details: docs/signing.md.")
                    setStatus("辅助功能未获系统认可：若开关已开启，请退出后移除旧条目、重新添加当前 .app，再打开。")
                    return
                }
                if requestedVertical {
                    let vertical = backend.probeVertical()
                    log.log(vertical.available ? "INFO" : "ERROR", vertical.status)
                    if !vertical.available {
                        guard requestedHorizontal else {
                            setStatus("纵向手势后端不可用：\(vertical.status)"); return
                        }
                        allowVertical = false
                    }
                }
            }
            experiment = mode; sessionID += 1
            self.horizontalEnabled = requestedHorizontal
            self.verticalEnabled = allowVertical
            var effectiveConfig = config
            effectiveConfig.verticalEnabled = allowVertical
            machine = GestureMachine(config: effectiveConfig)
            verticalGesture = VerticalGestureTracker()
            log.log("INFO", "Start \(mode.rawValue); CG buttons=\(buttonList); horizontal=\(requestedHorizontal); vertical=\(allowVertical); invert=\(config.invert); freeze=\(freeze); sensitivity=1/\(config.pixelsPerProgress)")
            if mode == .hidInput {
                let observer = HIDInputBackend(log: log)
                hid = observer
                if observer.start() != kIOReturnSuccess {
                    stopOnQueue("HID open failed; check Input Monitoring"); return
                }
            } else {
                let box = InputMailbox(buttons: buttons, gesture: mode.usesGestures, freeze: freeze)
                let source = DispatchSource.makeUserDataAddSource(queue: queue)
                let generation = sessionID
                source.setEventHandler { [weak self] in
                    guard let self, self.sessionID == generation else { return }
                    self.drainInput()
                }
                box.wake = { source.add(data: 1) }
                source.resume(); signal = source; mailbox = box
                let input = CGEventTapBackend(mailbox: box)
                hook = input
                guard input.start() else { stopOnQueue("CGEventTap creation failed; check permissions"); return }
                startHealthMonitor()
                if mode == .cgInput { startTimer(interval: 0.1) }
                // Optional read-only HID observer for removal notification and device identity.
                if mode.usesGestures && CGPreflightListenEventAccess() {
                    let observer = HIDInputBackend(log: log)
                    observer.disconnected = { [weak self] in self?.stop("mouse removed") }
                    hid = observer
                    if observer.start() != kIOReturnSuccess { observer.stop(); hid = nil }
                }
            }
            // Continuous gestures stay enabled. Only diagnostic observation expires.
            if !mode.usesGestures {
                let deadline = DispatchSource.makeTimerSource(queue: queue)
                deadline.schedule(deadline: .now() + 120)
                deadline.setEventHandler { [weak self] in self?.stopOnQueue("120-second input observation ended") }
                deadline.resume(); lease = deadline
            }
            let lifetime = mode.usesGestures ? "Continuous — no session timeout." : "Observation auto-stops in 120 s."
            let verticalDetail = allowVertical ? " Vertical backend: interactive HID; keyboard fallback inactive." : ""
            setStatus("Running: \(mode.rawValue); CG buttons=\(buttonList); invert=\(config.invert). \(lifetime) Escape stops gestures.\(verticalDetail)")
        }
    }
    func stop(_ reason: String = "user stop") { queue.async { [weak self] in self?.stopOnQueue(reason) } }
    func shutdown() { queue.sync { stopOnQueue("application exit") } }

    private func startTimer(interval: Double) {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + interval, repeating: interval, leeway: .microseconds(300))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume(); timer = t
    }
    private func drainInput() {
        guard let mailbox else { return }
        for record in mailbox.drain() {
            guard experiment != nil else { return }
            switch record {
            case .button(let number, let down, _):
                log.log("DEBUG", "\(MouseButton(cgNumber: number).name) \(down ? "DOWN" : "UP") cg=\(number)")
            case .modifier(let down, let time):
                if experiment?.usesGestures == true {
                    if down {
                        machine.down(at: time)
                        if verticalEnabled { verticalGesture.down(at: time) }
                        startTimer(interval: 1.0 / 120)
                    } else {
                        if verticalEnabled {
                            let previous = verticalGesture.action
                            let frames = verticalGesture.finish(verticalLocked: verticalAxisLocked(), at: time)
                            logVerticalSelection(after: previous)
                            send(frames, axis: .vertical)
                            guard experiment != nil else { return }
                        }
                        let horizontalFrames = machine.finish(at: time)
                        if horizontalEnabled { send(horizontalFrames) }
                        reportGesture(at: time)
                        timer?.cancel(); timer = nil
                    }
                }
            case .motion(let x, let y, let time, let count):
                if experiment?.usesGestures == true {
                    machine.move(dx: x, dy: y, at: time, count: count)
                    if verticalEnabled { verticalGesture.move(totalY: machine.totalY, at: time) }
                }
                else { log.log("TRACE", String(format: "CG moved/dragged dx=%.1f dy=%.1f rawEvents=%d", x, y, count)) }
            case .scroll(let x, let y, let count):
                log.log("TRACE", "CG scroll dx=\(x) dy=\(y) rawEvents=\(count)")
            case .cancel(let reason):
                stopOnQueue(reason); return
            case .tapDisabled(let reason):
                recoverTap(reason)
            }
        }
    }
    private func startHealthMonitor() {
        let monitor = DispatchSource.makeTimerSource(queue: queue)
        monitor.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(200))
        monitor.setEventHandler { [weak self] in
            guard let self, let hook = self.hook else { return }
            _ = self.performance.sample(completed: self.counters.gestureEnds + self.counters.gestureCancels)
            if self.experiment?.usesGestures == true && !AXIsProcessTrusted() {
                self.stopOnQueue("Accessibility permission lost"); return
            }
            if hook.health != "enabled" {
                self.mailbox?.interruptForTapRecovery("health check: tap \(hook.health)")
                self.drainInput()
            }
        }
        monitor.resume(); healthTimer = monitor
    }
    private func recoverTap(_ reason: String) {
        log.log("WARN", reason)
        // Terminate the old gesture once. A held key is quarantined by the mailbox
        // until its release; resuming the tap never resumes its old accumulator.
        let now = monotonicTime()
        if verticalEnabled {
            send(verticalGesture.finish(verticalLocked: verticalAxisLocked(), at: now, cancel: true), axis: .vertical)
            guard experiment != nil else { return }
        }
        let horizontalFrames = machine.finish(at: now, cancel: true)
        if horizontalEnabled { send(horizontalFrames) }
        timer?.cancel(); timer = nil
        guard experiment != nil else { return }
        guard (experiment?.usesGestures != true || AXIsProcessTrusted()), recoveryBudget.take(at: monotonicTime()) else {
            stopOnQueue("tap recovery denied: permission missing or 3 attempts/60s exhausted"); return
        }
        counters.eventTapRecoveryAttempts += 1
        guard hook?.reenable() == true, mailbox?.resumeAfterTapRecovery() == true else {
            stopOnQueue("tap recovery failed; restart manually"); return
        }
        counters.eventTapRestarts += 1
        log.log("INFO", "Event tap re-enabled; release held side buttons before the next gesture. Restarts=\(counters.eventTapRestarts)")
        if experiment == .cgInput { startTimer(interval: 0.1) }
    }
    private func tick() {
        drainInput()
        guard experiment?.usesGestures == true else { return }
        let now = monotonicTime()
        if machine.active && now - machine.startTime > 20 {
            stopOnQueue("20-second held-button safety limit"); return
        }
        if now - lastPermissionCheck > 1 {
            lastPermissionCheck = now
            if !AXIsProcessTrusted() { stopOnQueue("Accessibility permission lost"); return }
        }
        // Dispatch timer already coalesces missed firings. A second elapsed-time gate
        // here would skip alternate frames whenever timer delivery jitters slightly.
        let horizontalFrames = machine.frame(at: now)
        if horizontalEnabled { send(horizontalFrames) }
        if verticalEnabled {
            let previous = verticalGesture.action
            let frames = verticalGesture.frame(verticalLocked: machine.state == .vertical, at: now)
            logVerticalSelection(after: previous)
            send(frames, axis: .vertical)
        }
    }
    private func verticalAxisLocked() -> Bool {
        if machine.state == .vertical { return true }
        // A release may arrive before the next 120 Hz frame. Mirror the same
        // dead-zone and axis decision without changing the locked action.
        return machine.config.verticalEnabled && machine.state == .detectingAxis &&
            hypot(machine.totalX, machine.totalY) >= max(0, machine.config.deadZone) &&
            abs(machine.totalY) >= abs(machine.totalX)
    }
    private func logVerticalSelection(after previous: VerticalGestureAction) {
        guard verticalGesture.action != previous else { return }
        log.log("DEBUG", String(format: "axis locked: vertical; rawDy=%.1f; action=%@",
                                verticalGesture.rawY, verticalGesture.action.rawValue))
    }
    private func send(_ frames: [GestureFrame], axis: PostingAxis = .horizontal) {
        for frame in frames {
            let posted = axis == .horizontal ? backend.send(frame) : backend.sendVertical(frame)
            guard posted else {
                counters.postFailures += 1
                log.log("ERROR", "Gesture allocation/post request failed; cancelling and stopping")
                // One best-effort terminal event; no recursive retry loop.
                let terminal = GestureFrame(.cancelled, frame.progress)
                let cancelled = axis == .horizontal ? backend.send(terminal) : backend.sendVertical(terminal)
                if cancelled {
                    if counters.openGestures > 0 { counters.record(terminal) }
                } else { counters.postFailures += 1 }
                stopOnQueue("backend failure", sendCancel: false); return
            }
            counters.record(frame)
            if frame.phase == .began {
                if axis == .vertical {
                    lastGestureAxis = "vertical"
                    lastVerticalAction = verticalGesture.action.rawValue
                    verticalBegins += 1
                    switch verticalGesture.action {
                    case .missionControl: missionControlGestures += 1
                    case .appExpose: appExposeGestures += 1
                    case .undecided: break
                    }
                } else { lastGestureAxis = "horizontal" }
            }
            if frame.phase != .changed || monotonicTime() - lastTrace > 0.1 {
                lastTrace = monotonicTime()
                let label = axis == .vertical ? verticalGesture.action.rawValue : "horizontal"
                let emitted = axis == .vertical ? verticalGesture.emittedEvents : machine.emittedEvents
                log.log("DEBUG", String(format: "%@ gesture %@ progress=%.4f velocity=%.3f raw=%d emitted=%d",
                                        label, String(describing: frame.phase), frame.progress, frame.velocity,
                                        machine.rawEvents, emitted))
            }
        }
    }
    private func reportGesture(at time: Double) {
        let duration = max(0.001, time - machine.startTime)
        let axis: String
        if verticalEnabled && verticalGesture.action != .undecided {
            axis = "vertical \(verticalGesture.action.rawValue)"
        } else { axis = "horizontal/none" }
        let emitted = axis.hasPrefix("vertical") ? verticalGesture.emittedEvents : machine.emittedEvents
        log.log("INFO", String(format: "Last gesture (%@): dx=%.1f dy=%.1f duration=%.3fs raw=%d emitted=%d CG observed=%.0f events/s",
                                axis,
                                machine.totalX, machine.totalY, duration, machine.rawEvents,
                                emitted, Double(machine.rawEvents) / duration))
    }
    private func stopOnQueue(_ reason: String, sendCancel: Bool = true) {
        mailbox?.stop() // Fail open immediately, before doing any more work.
        let now = monotonicTime()
        let verticalTerminal = verticalEnabled
            ? verticalGesture.finish(verticalLocked: verticalAxisLocked(), at: now, cancel: true) : []
        let terminal = machine.finish(at: now, cancel: true)
        if sendCancel {
            for frame in verticalTerminal {
                if backend.sendVertical(frame) { counters.record(frame) } else { counters.postFailures += 1 }
            }
            if horizontalEnabled {
                for frame in terminal {
                    if backend.send(frame) { counters.record(frame) } else { counters.postFailures += 1 }
                }
            }
        }
        timer?.cancel(); timer = nil
        lease?.cancel(); lease = nil
        healthTimer?.cancel(); healthTimer = nil
        signal?.cancel(); signal = nil
        hook?.stop(); hook = nil
        if let mailbox { previousInput.add(mailbox.counts()); log.log("INFO", mailbox.stats()) }
        if let hid { log.log("INFO", hid.snapshot()); hid.stop() }
        hid = nil; mailbox = nil
        if experiment != nil { log.log("INFO", "Stopped: \(reason)") }
        experiment = nil
        horizontalEnabled = false; verticalEnabled = false
        setStatus("Stopped: \(reason). No mouse events consumed.")
    }
}
