import Foundation
import CoreFoundation
import GestureCore

// UI and persistence share the Build 4 defaults and limits. GestureCore's math is
// deliberately unchanged. Sensitivity is stored in existing pixels/progress units.
struct AppConfig: Equatable {
    var enabled = true
    var gestureButtons: Set<Int> = [3, 4]
    var horizontalEnabled = true
    var verticalEnabled = true
    var horizontalInvert = true
    var sensitivity = 600.0
    var deadZone = 8.0
    var freezePointer = true
    static let defaults = AppConfig()

    var shouldRun: Bool { enabled && (horizontalEnabled || verticalEnabled) }
    var buttonText: String { gestureButtons.sorted().map(String.init).joined(separator: ",") }
    var gestureConfig: GestureConfig {
        let c = validated()
        var gesture = GestureConfig()
        gesture.pixelsPerProgress = c.sensitivity
        gesture.deadZone = c.deadZone
        gesture.invert = c.horizontalInvert
        gesture.verticalEnabled = c.verticalEnabled
        return gesture
    }
    func validated() -> AppConfig {
        var c = self
        if c.gestureButtons.isEmpty || !c.gestureButtons.allSatisfy({ (2...31).contains($0) }) {
            c.gestureButtons = Self.defaults.gestureButtons
        }
        c.sensitivity = sensitivity.isFinite ? min(5000, max(100, sensitivity)) : Self.defaults.sensitivity
        c.deadZone = deadZone.isFinite ? min(80, max(1, deadZone)) : Self.defaults.deadZone
        return c
    }
    static func parseButtons(_ text: String) -> Set<Int>? {
        let parts = text.split(separator: ",", omittingEmptySubsequences: false)
        let numbers = parts.compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        guard !numbers.isEmpty, numbers.count == parts.count, numbers.allSatisfy({ (2...31).contains($0) }) else { return nil }
        return Set(numbers)
    }
}

final class ConfigStore {
    static let key = "gesture.configuration.v1"
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() -> AppConfig {
        guard let values = defaults.dictionary(forKey: Self.key) else { return .defaults }
        var c = AppConfig.defaults
        func bool(_ key: String, fallback: Bool) -> Bool {
            guard let n = values[key] as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() else { return fallback }
            return n.boolValue
        }
        func number(_ key: String, fallback: Double) -> Double {
            guard let n = values[key] as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return fallback }
            return n.doubleValue
        }
        c.enabled = bool("enabled", fallback: c.enabled)
        c.horizontalEnabled = bool("horizontalEnabled", fallback: c.horizontalEnabled)
        // Existing users who disabled the only gesture stay stopped on upgrade.
        c.verticalEnabled = bool("verticalEnabled", fallback: c.horizontalEnabled)
        c.horizontalInvert = bool("horizontalInvert", fallback: c.horizontalInvert)
        c.freezePointer = bool("freezePointer", fallback: c.freezePointer)
        c.sensitivity = number("sensitivity", fallback: c.sensitivity)
        c.deadZone = number("deadZone", fallback: c.deadZone)
        if let buttons = values["gestureButtons"] as? [NSNumber], !buttons.isEmpty,
           buttons.allSatisfy({ CFGetTypeID($0) != CFBooleanGetTypeID() && $0.doubleValue.isFinite &&
               (2...31).contains($0.doubleValue) && $0.doubleValue.rounded() == $0.doubleValue }) {
            c.gestureButtons = Set(buttons.map(\.intValue))
        }
        return c.validated()
    }
    func save(_ config: AppConfig) {
        let c = config.validated()
        defaults.set([
            "enabled": c.enabled, "gestureButtons": c.gestureButtons.sorted(),
            "horizontalEnabled": c.horizontalEnabled, "verticalEnabled": c.verticalEnabled,
            "horizontalInvert": c.horizontalInvert,
            "sensitivity": c.sensitivity, "deadZone": c.deadZone, "freezePointer": c.freezePointer
        ], forKey: Self.key)
    }
}
