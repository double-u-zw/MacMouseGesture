import Foundation
import CoreFoundation
import GestureCore

// UI and persistence share the Build 4 defaults and limits. GestureCore's math is
// deliberately unchanged. Sensitivity is stored in existing pixels/progress units.
struct AppConfig: Equatable {
    var enabled = true
    // Legacy compatibility only: adapter output for the existing drag runtime.
    var gestureButtons: Set<Int> = [3, 4]
    var horizontalEnabled = true
    var verticalEnabled = true
    var horizontalInvert = true
    var sensitivity = 600.0
    var deadZone = 8.0
    var freezePointer = true
    var mappings = LegacyMappingProjection.defaults
    var dragMappingsManaged = false // Lazy adoption when a drag mapping is edited.
    // Compatibility accessors for old callers/tests and downgrade serialization.
    // Runtime resolution uses mappingStore, never these button-specific names.
    var button4ClickAction: ButtonClickConfiguration {
        get { clickConfiguration(for: 3) }
        set { setLegacyClick(newValue, button: 4) }
    }
    var button5ClickAction: ButtonClickConfiguration {
        get { clickConfiguration(for: 4) }
        set { setLegacyClick(newValue, button: 5) }
    }
    func clickConfiguration(for button: Int) -> ButtonClickConfiguration {
        guard let identifier = MouseButtonIdentifier(rawValue: button) else { return ButtonClickConfiguration() }
        return mappingStore.action(for: identifier.input, trigger: .shortPress)?.legacyConfiguration ?? ButtonClickConfiguration()
    }
    private mutating func setLegacyClick(_ value: ButtonClickConfiguration, button: Int) {
        var store = MouseMappingStore(mappings: mappings)
        var row = store.mapping(for: .button(button), trigger: .shortPress) ?? LegacyMappingProjection.shortPress(button: button, action: .none)
        row.action = MouseAction(legacy: value); row.isEnabled = true
        if !store.update(row) { store.add(row) }
        mappings = store.mappings
    }
    var mappingStore: MouseMappingStore {
        MouseMappingStore(mappings: dragMappingsManaged ? LegacyDragSettingsAdapter.rows(config: self) :
            mappings.filter { $0.trigger.isButtonPress } + LegacyDragSettingsAdapter.rows(config: self))
    }
    static let defaults = AppConfig()

    var shouldRun: Bool { enabled && (horizontalEnabled || verticalEnabled || !mappingStore.pressCGButtons.isEmpty) }
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
        c.mappings = c.mappingStore.mappings
        LegacyDragSettingsAdapter.synchronize(&c)
        return c
    }
    static func == (lhs: AppConfig, rhs: AppConfig) -> Bool {
        lhs.dragMappingsManaged == rhs.dragMappingsManaged && lhs.enabled == rhs.enabled && lhs.gestureButtons == rhs.gestureButtons &&
        lhs.horizontalEnabled == rhs.horizontalEnabled && lhs.verticalEnabled == rhs.verticalEnabled &&
        lhs.horizontalInvert == rhs.horizontalInvert && lhs.sensitivity == rhs.sensitivity &&
        lhs.deadZone == rhs.deadZone && lhs.freezePointer == rhs.freezePointer && lhs.mappingStore == rhs.mappingStore
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
    static let mappingsKey = "mouseMappingsV1"
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() -> AppConfig {
        guard let values = defaults.dictionary(forKey: Self.key) else {
            let fresh = AppConfig.defaults.validated(); save(fresh); return fresh
        }
        var c = AppConfig.defaults
        func bool(_ key: String, fallback: Bool) -> Bool {
            guard let n = values[key] as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() else { return fallback }
            return n.boolValue
        }
        func number(_ key: String, fallback: Double) -> Double {
            guard let n = values[key] as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return fallback }
            return n.doubleValue
        }
        c.dragMappingsManaged = bool("dragMappingsManaged", fallback: false)
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
        if let stored = values[Self.mappingsKey] {
            // An existing empty document is authoritative: deletion must survive
            // restart. Corrupt/future formats fail closed, never resurrect legacy actions.
            c.mappings = (stored as? Data).flatMap { try? MouseMappingStore(data: $0) }?.mappings ?? []
            return c.validated()
        }
        c.button4ClickAction = ButtonClickConfiguration(values: values["button4ClickAction"])
        c.button5ClickAction = ButtonClickConfiguration(values: values["button5ClickAction"])
        c = c.validated()
        // One atomic preference write contains both the migrated document and
        // unchanged gesture settings. Presence is the migration-complete marker.
        save(c)
        return c
    }
    func save(_ config: AppConfig) {
        let c = config.validated()
        guard let mappings = try? c.mappingStore.encoded() else { return }
        var values = defaults.dictionary(forKey: Self.key) ?? [:]
        values.merge([
            "dragMappingsManaged": c.dragMappingsManaged, "enabled": c.enabled, "gestureButtons": c.gestureButtons.sorted(),
            "horizontalEnabled": c.horizontalEnabled, "verticalEnabled": c.verticalEnabled,
            "horizontalInvert": c.horizontalInvert,
            "sensitivity": c.sensitivity, "deadZone": c.deadZone, "freezePointer": c.freezePointer,
            "button4ClickAction": c.button4ClickAction.values, "button5ClickAction": c.button5ClickAction.values,
            Self.mappingsKey: mappings
        ]) { _, new in new }
        defaults.set(values, forKey: Self.key)
    }
}
