import Foundation

enum PressClaim: Equatable { case pending, drag, longPress, wheel, cancelled }
struct WheelPressResolution: Equatable {
    let consumed: Bool
    var button: Int? = nil
    var action: MouseAction? = nil
    var newlyClaimed = false
    static let pass = Self(consumed: false)
}
enum PressRelease: Equatable {
    case shortPressAllowed, suppressed, longPress(MouseAction)
}

// Presses with an effective long or wheel mapping enter this coordinator. Existing
// click/drag trackers remain the sole authority for recognizing the deadZone.
// All calls and timer callbacks are serialized on the engine queue.
final class LongPressCoordinator {
    private struct Press {
        let generation: UInt64
        let deadline: Double
        let modifiers: MouseModifiers
        let action: MouseAction?
        let wheelActions: [MouseWheelDirection: MouseAction]
        var wheelNormalizer: WheelStepNormalizer
        var claim: PressClaim
        var timer: LongPressCancellation?
    }
    private var presses: [Int: Press] = [:]
    private var generation: UInt64 = 0
    private let scheduler: LongPressScheduler
    private let configuration: LongPressConfiguration
    private let wheelConfiguration: WheelStepConfiguration
    private var wheelOwner: Int?
    var onDeadline: ((Int, UInt64) -> Void)?
    init(scheduler: LongPressScheduler, configuration: LongPressConfiguration = .init(), wheelConfiguration: WheelStepConfiguration = .init()) {
        self.scheduler = scheduler; self.configuration = configuration; self.wheelConfiguration = wheelConfiguration
    }
    var isActive: Bool { !presses.isEmpty }
    var timerCount: Int { presses.values.filter { $0.timer != nil }.count }
    func claim(for button: Int) -> PressClaim? { presses[button]?.claim }
    func modifiers(for button: Int) -> MouseModifiers? { presses[button]?.modifiers }
    func down(_ button: Int, at time: Double, modifiers: MouseModifiers, action: MouseAction?, dragClaimed: Bool = false,
              wheelActions: [MouseWheelDirection: MouseAction] = [:]) {
        let action = action == MouseAction.none ? nil : action
        let wheelActions = wheelActions.filter { $0.value != .none }
        guard presses[button] == nil, action != nil || !wheelActions.isEmpty else { return }
        generation &+= 1
        let id = generation
        presses[button] = Press(generation: id, deadline: time + configuration.duration, modifiers: modifiers,
                                action: action, wheelActions: wheelActions, wheelNormalizer: .init(configuration: wheelConfiguration),
                                claim: dragClaimed ? .drag : .pending)
        if !dragClaimed && action != nil { arm(button, generation: id) }
    }
    private func arm(_ button: Int, generation: UInt64) {
        guard let press = presses[button], press.action != nil else { return }
        presses[button]?.timer = scheduler.schedule(at: press.deadline) { [weak self] in
            self?.onDeadline?(button, generation)
        }
    }
    func observeDrag(_ buttons: Set<Int>) {
        guard !presses.isEmpty else { return }
        for button in buttons where presses[button]?.claim == .pending {
            presses[button]?.timer?.cancel(); presses[button]?.timer = nil
            presses[button]?.claim = .drag
        }
    }
    func fire(_ button: Int, generation: UInt64) -> MouseAction? {
        guard let press = presses[button], press.generation == generation, press.claim == .pending, let action = press.action else { return nil }
        presses[button]?.timer?.cancel(); presses[button]?.timer = nil
        guard scheduler.now >= press.deadline else { arm(button, generation: generation); return nil }
        presses[button]?.claim = .longPress
        return action
    }
    func wheel(_ sample: WheelScrollSample, at time: Double) -> WheelPressResolution {
        guard let direction = sample.direction else { return .pass } // horizontal/zero/invalid input
        let button = wheelOwner ?? presses.filter { $0.value.claim == .pending && !$0.value.wheelActions.isEmpty }
            .max(by: { $0.value.generation < $1.value.generation })?.key
        guard let button, var press = presses[button], press.claim == .pending || press.claim == .wheel else { return .pass }
        guard let action = press.wheelActions[direction] else {
            press.wheelNormalizer.resetAccumulation(); presses[button] = press
            return press.claim == .wheel ? .init(consumed: true, button: button) : .pass
        }
        // Momentum never starts/repeats a chord; once owned it is still consumed.
        if sample.isMomentum { return press.claim == .wheel ? .init(consumed: true, button: button) : .pass }
        guard press.wheelNormalizer.step(sample, at: time) != nil else {
            presses[button] = press
            // Mapped sub-step samples are consumed while accumulating, but do not
            // claim wheel until the first logical step actually emits an action.
            return .init(consumed: true, button: button)
        }
        let newlyClaimed = press.claim == .pending
        if newlyClaimed { press.timer?.cancel(); press.timer = nil; press.claim = .wheel; wheelOwner = button }
        presses[button] = press
        return .init(consumed: true, button: button, action: action, newlyClaimed: newlyClaimed)
    }
    func release(_ button: Int, at time: Double) -> PressRelease {
        guard let press = presses.removeValue(forKey: button) else { return .shortPressAllowed }
        if wheelOwner == button { wheelOwner = nil }
        press.timer?.cancel()
        switch press.claim {
        case .pending:
            if time >= press.deadline, let action = press.action { return .longPress(action) }
            return .shortPressAllowed
        case .drag, .longPress, .wheel, .cancelled: return .suppressed
        }
    }
    func cancelAll() {
        wheelOwner = nil
        for press in presses.values { press.timer?.cancel() }
        // Retain ownership until release: cancellation can never resurrect a short press.
        for button in Array(presses.keys) { presses[button]?.claim = .cancelled; presses[button]?.timer = nil }
    }
    func reset() { cancelAll(); presses.removeAll() }
    deinit { for press in presses.values { press.timer?.cancel() } }
}
