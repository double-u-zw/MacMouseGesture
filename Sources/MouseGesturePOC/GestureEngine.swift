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
    private var clicks = SideButtonClickTracker()
    private var pressContexts = MousePressContexts()
    private let inputRecorder: MouseInputRecorder?
    private var mappings = MouseMappingStore()
    private var standaloneClicks = StandaloneShortPressTracker()
    private lazy var longPresses: LongPressCoordinator = {
        let value = LongPressCoordinator(scheduler: DispatchLongPressScheduler(queue: queue, clock: monotonicTime))
        value.onDeadline = { [weak self] number, generation in self?.longPressDeadline(number, generation: generation) }
        return value
    }()
    private var configuredButtons: Set<Int> = []
    private var dragButtons: Set<Int> = []
    private var dragDelivery = LegacyDragDelivery(config: .defaults)
    private lazy var actionExecutor = MouseButtonActionExecutor(
        verticalAvailable: { [unowned self] in self.backend.probeVertical().available },
        postVertical: { [unowned self] in self.backend.sendVertical($0) },
        diagnostic: { [unowned self] in self.log.log("DEBUG", $0) }, gestureQueue: queue)
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
    private var pressEpoch: UInt64 = 0
    private let statusLock = NSLock()
    private var statusText = "Stopped — no mouse events consumed"
    var onStatus: (() -> Void)?
    var onInputDeviceRemoved: (() -> Void)?
    init(log: Diagnostics, inputRecorder: MouseInputRecorder? = nil) {
        self.log = log; self.inputRecorder = inputRecorder; log.log("INFO", backend.status)
    }
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
               config: GestureConfig, horizontalEnabled: Bool = true, clickConfig: AppConfig = .defaults) {
        queue.async { [self] in
            stopOnQueue("restart")
            guard !buttons.isEmpty, buttons.allSatisfy({ (2...31).contains($0) }) else {
                setStatus("CG buttons must be comma-separated numbers in 2…31"); return
            }
            let buttonList = buttons.sorted().map(String.init).joined(separator: ",")
            let requestedHorizontal = mode.usesGestures && horizontalEnabled
            let requestedVertical = mode == .missionControlPOC || (mode == .horizontal && config.verticalEnabled)
            let mappingSnapshot = clickConfig.mappingStore
            guard !mode.usesGestures || requestedHorizontal || requestedVertical || !mappingSnapshot.pressCGButtons.isEmpty else {
                setStatus("请至少启用一种手势。"); return
            }
            var allowVertical = requestedVertical
            if mode.usesGestures {
                guard !(requestedHorizontal || requestedVertical) || backend.available else {
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
            mappings = mappingSnapshot
            dragDelivery = LegacyDragDelivery(config: clickConfig)
            dragButtons = requestedHorizontal || requestedVertical ? buttons : []
            configuredButtons = mode.usesGestures ? dragButtons.union(mappingSnapshot.pressCGButtons) : buttons
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
                let box = InputMailbox(buttons: configuredButtons, gesture: mode.usesGestures, freeze: freeze, gestureButtons: dragButtons, recorder: inputRecorder,
                                       wheelButtons: mappingSnapshot.wheelCGButtons)
                let wheelHandoff = WheelInputHandoff(queue: queue, prepare: { [weak self] in self?.drainInput() },
                    resolve: { [weak self] sample, time in self?.resolveWheel(sample, at: time) ?? false })
                box.wheelCapture = { sample, time in wheelHandoff.capture(sample, at: time) }
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
                    observer.disconnected = { [weak self] in
                        guard let self else { return }
                        self.queue.async { [weak self] in
                            guard let self, self.sessionID == generation, self.experiment != nil else { return }
                            // Finish/cancel the old sequence and release held input first.
                            // Ignore duplicate removals and callbacks from a retired observer.
                            self.stopOnQueue("mouse removed")
                            DispatchQueue.main.async { [weak self] in self?.onInputDeviceRemoved?() }
                        }
                    }
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
    func cancelPendingClicks() {
        queue.async { [weak self] in
            guard let self else { return }
            self.pressEpoch &+= 1
            self.longPresses.cancelAll()
            self.clicks.reset(); self.standaloneClicks.reset(); self.pressContexts.reset()
            if self.experiment?.usesGestures == true && !self.machine.active { self.timer?.cancel(); self.timer = nil }
        }
    }
    func shutdown() { queue.sync { stopOnQueue("application exit") } }
    func pauseForInputRecording() { queue.sync { stopOnQueue("mouse input recording") } }

    private func startTimer(interval: Double) {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + interval, repeating: interval, leeway: .microseconds(300))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume(); timer = t
    }
    private func drainInput() {
        guard let mailbox else { return }
        let generation = sessionID
        let pressGeneration = pressEpoch
        var releasedLongActions: [(Int, MouseAction)] = []
        for record in mailbox.drain() {
            guard experiment != nil else { return }
            switch record {
            case .buttonContext(let number, let modifiers):
                pressContexts.down(number, modifiers: modifiers)
            case .button(let number, let down, let time):
                if experiment?.usesGestures == true && configuredButtons.contains(number) {
                    if down {
                        if [.longPress, .wheel, .cancelled].contains(longPresses.claim(for: number)) { continue }
                        pressContexts.down(number)
                        actionExecutor.cancelMissionControl(reason: "new physical side-button press")
                        actionExecutor.cancelAppExpose(reason: "new physical side-button press")
                        if dragButtons.contains(number) {
                            dragDelivery.down(number)
                            clicks.down(number, machine: machine)
                        }
                        else {
                            standaloneClicks.down(number, at: time, config: machine.config, sharedMachine: machine)
                            startTimer(interval: 1.0 / 120)
                        }
                        if let identifier = MouseButtonIdentifier(rawValue: number) {
                            let modifiers = pressContexts.values[number] ?? []
                            longPresses.down(number, at: time, modifiers: modifiers,
                                action: mappings.longPressAction(for: identifier.input, modifiers: modifiers),
                                dragClaimed: clicks.states[number] == .gestureStarted || standaloneClicks.dragStartedButtons.contains(number),
                                wheelActions: mappings.wheelActions(for: identifier.input, modifiers: modifiers))
                        }
                    }
                    else {
                        dragDelivery.up(number)
                        let modifiers = pressContexts.up(number)
                        clicks.observe(machine)
                        standaloneClicks.observeShared(machine)
                        observeLongPressDrag()
                        let resolution = longPresses.release(number, at: time)
                        if case .longPress(let action) = resolution { releasedLongActions.append((number, action)) }
                        let state = clicks.states[number]
                        let accepted = dragButtons.contains(number) ? clicks.up(number) : standaloneClicks.up(number)
                        if accepted && resolution == .shortPressAllowed {
                            if let identifier = MouseButtonIdentifier(rawValue: number),
                               let action = mappings.shortPressAction(for: identifier.input, modifiers: modifiers) {
                                log.log("DEBUG", "[Mapping] button=\(identifier.number) modifiers=\(modifiers.rawValue) trigger=shortPress action=\(action.title)")
                                if !actionExecutor.execute(action, button: identifier.number) {
                                    log.log("WARN", "Short-click action failed for CG button \(number)")
                                }
                            }
                        } else {
                            log.log("DEBUG", "Short-click suppressed cg=\(number) reason=\(state == .gestureStarted ? "gesture" : "cancelled/unmatched")")
                        }
                        if !dragButtons.contains(number) && !standaloneClicks.isActive && !machine.active { timer?.cancel(); timer = nil }
                    }
                }
                log.log("DEBUG", "\(MouseButtonIdentifier(rawValue: number)?.title ?? "invalid button") \(down ? "DOWN" : "UP") cg=\(number)")
            case .modifier(let down, let time):
                if experiment?.usesGestures == true {
                    if down {
                        dragDelivery.begin()
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
                        dragDelivery.end()
                        reportGesture(at: time)
                        if !standaloneClicks.isActive { timer?.cancel(); timer = nil }
                    }
                }
            case .motion(let x, let y, let time, let count):
                if experiment?.usesGestures == true {
                    // A long owner has retired its click tracker. Buffered motion
                    // must not start a drag while its physical-up edge is in flight.
                    // With no long lifecycle, this is exactly the original path.
                    if !longPresses.isActive || !clicks.states.isEmpty {
                        machine.move(dx: x, dy: y, at: time, count: count)
                    }
                    standaloneClicks.move(dx: x, dy: y, at: time, count: count)
                    standaloneClicks.observeShared(machine)
                    clicks.observe(machine)
                    observeLongPressDrag()
                    if clicks.states.values.contains(.gestureStarted) {
                        actionExecutor.cancelMissionControl(reason: "physical drag takes priority")
                        actionExecutor.cancelAppExpose(reason: "physical drag takes priority")
                    }
                    if verticalEnabled { verticalGesture.move(totalY: machine.totalY, at: time) }
                }
                else { log.log("TRACE", String(format: "CG moved/dragged dx=%.1f dy=%.1f rawEvents=%d", x, y, count)) }
            case .scroll(let x, let y, let count):
                log.log("TRACE", "CG scroll dx=\(x) dy=\(y) rawEvents=\(count)")
            case .cancel(let reason):
                stopOnQueue(reason); return
            case .tapDisabled(let reason):
                releasedLongActions.removeAll()
                recoverTap(reason)
            }
        }
        // On a delayed dispatch callback, a release at/after the deadline still
        // claims long press. Finish queued gesture-up edges before executing it.
        if experiment?.usesGestures == true && sessionID == generation && pressEpoch == pressGeneration {
            for (number, action) in releasedLongActions { executeLongPress(action, number: number) }
        }
    }
    private func observeLongPressDrag() {
        guard longPresses.isActive else { return }
        let dragged: Set<Int> = Set(clicks.states.filter { $0.value == .gestureStarted }.keys)
        longPresses.observeDrag(dragged.union(standaloneClicks.dragStartedButtons))
    }
    private func resolveWheel(_ sample: WheelScrollSample, at time: Double) -> Bool {
        guard experiment?.usesGestures == true else { return false }
        observeLongPressDrag()
        let resolution = longPresses.wheel(sample, at: time)
        guard resolution.consumed else { return false }
        if resolution.newlyClaimed, let number = resolution.button {
            dragDelivery.retire(number)
            _ = clicks.up(number); _ = standaloneClicks.up(number)
            if mailbox?.retirePressDriver(number, at: time) == true {
                // Finish only the unclaimed detecting pipeline. No core drag math changes.
                if verticalEnabled { _ = verticalGesture.finish(verticalLocked: false, at: time) }
                _ = machine.finish(at: time)
            }
            if !machine.active && !standaloneClicks.isActive { timer?.cancel(); timer = nil }
        }
        if let action = resolution.action, let number = resolution.button {
            let generation = sessionID, epoch = pressEpoch
            // Posting is asynchronous and outside the tap's decision handoff.
            queue.async { [weak self] in
                guard let self, self.experiment?.usesGestures == true, self.sessionID == generation, self.pressEpoch == epoch,
                      let identifier = MouseButtonIdentifier(rawValue: number) else { return }
                self.log.log("DEBUG", "[Mapping] button=\(identifier.number) trigger=wheel direction=\(sample.direction?.rawValue ?? "unknown") action=\(action.title)")
                if !self.actionExecutor.execute(action, button: identifier.number) {
                    self.log.log("WARN", "Wheel action failed for CG button \(number)")
                }
            }
        }
        return true
    }
    private func longPressDeadline(_ number: Int, generation: UInt64) {
        // Edges/motion received before this callback get the first opportunity
        // to claim/cancel. A stale callback cannot act on a newer press.
        drainInput()
        guard experiment?.usesGestures == true else { return }
        observeLongPressDrag()
        guard let action = longPresses.fire(number, generation: generation) else { return }
        let pressGeneration = pressEpoch
        dragDelivery.retire(number)
        _ = clicks.up(number); _ = standaloneClicks.up(number)
        let now = monotonicTime()
        if mailbox?.claimLongPress(number, at: now) == true {
            // The tap can buffer new motion while this callback runs. Retire the
            // detecting pipeline now, so such motion cannot enter drag afterward.
            if verticalEnabled { _ = verticalGesture.finish(verticalLocked: false, at: now) }
            _ = machine.finish(at: now)
        }
        drainInput() // retire the existing logical drag driver before the action
        guard experiment?.usesGestures == true, pressEpoch == pressGeneration else { return }
        if !machine.active && !standaloneClicks.isActive { timer?.cancel(); timer = nil }
        executeLongPress(action, number: number)
    }
    private func executeLongPress(_ action: MouseAction, number: Int) {
        guard let identifier = MouseButtonIdentifier(rawValue: number) else { return }
        log.log("DEBUG", "[Mapping] button=\(identifier.number) trigger=longPress action=\(action.title)")
        if !actionExecutor.execute(action, button: identifier.number) {
            log.log("WARN", "Long-press action failed for CG button \(number)")
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
        actionExecutor.cancelMissionControl(reason: reason)
        actionExecutor.cancelAppExpose(reason: reason)
        pressEpoch &+= 1
        longPresses.reset()
        clicks.reset()
        standaloneClicks.reset()
        pressContexts.reset()
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
        dragDelivery.reset()
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
        if (machine.active && now - machine.startTime > 20) || standaloneClicks.oldestStart.map({ now - $0 > 20 }) == true {
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
    private func deliverable(_ frames: [GestureFrame], axis: PostingAxis) -> [GestureFrame] {
        let direction: MouseDragDirection = axis == .vertical ?
            (verticalGesture.action == .missionControl ? .up : .down) : (machine.totalX < 0 ? .left : .right)
        return dragDelivery.filter(frames, vertical: axis == .vertical, direction: direction)
    }
    private func send(_ frames: [GestureFrame], axis: PostingAxis = .horizontal) {
        for frame in deliverable(frames, axis: axis) {
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
        actionExecutor.cancelMissionControl(reason: reason)
        actionExecutor.cancelAppExpose(reason: reason)
        pressEpoch &+= 1
        longPresses.reset()
        clicks.reset()
        standaloneClicks.reset()
        pressContexts.reset()
        mailbox?.stop() // Fail open immediately, before doing any more work.
        let now = monotonicTime()
        let verticalTerminal = verticalEnabled
            ? verticalGesture.finish(verticalLocked: verticalAxisLocked(), at: now, cancel: true) : []
        let terminal = machine.finish(at: now, cancel: true)
        if sendCancel {
            for frame in deliverable(verticalTerminal, axis: .vertical) {
                if backend.sendVertical(frame) { counters.record(frame) } else { counters.postFailures += 1 }
            }
            if horizontalEnabled {
                for frame in deliverable(terminal, axis: .horizontal) {
                    if backend.send(frame) { counters.record(frame) } else { counters.postFailures += 1 }
                }
            }
        }
        dragDelivery.reset()
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
