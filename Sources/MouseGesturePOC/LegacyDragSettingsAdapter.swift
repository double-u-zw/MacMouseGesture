import Foundation
import GestureCore

// Legacy compatibility only. The UI edits MappingStore; the established drag
// machines still receive their original buttons/axes/inversion configuration.
enum LegacyDragSettingsAdapter {
    static func action(for direction: MouseDragDirection, inverted: Bool) -> MouseAction {
        switch direction {
        case .left: .system(inverted ? .previousSpace : .nextSpace)
        case .right: .system(inverted ? .nextSpace : .previousSpace)
        case .up: .system(.missionControl)
        case .down: .system(.appExpose)
        }
    }
    static func rows(config: AppConfig) -> [MouseMapping] {
        guard config.dragMappingsManaged else { return LegacyMappingProjection.drags(config: config) }
        return config.mappings.map { original in
            var row = original
            if case .drag(let direction) = row.trigger { row.action = action(for: direction, inverted: config.horizontalInvert) }
            return row
        }
    }
    static func writing(_ store: MouseMappingStore, to config: AppConfig, editingDrag: Bool) -> AppConfig {
        var next = config
        // Adopt the existing projection only upon a user edit, without a startup migration.
        next.dragMappingsManaged = config.dragMappingsManaged || editingDrag
        next.mappings = store.mappings
        return next.validated()
    }
    static func synchronize(_ config: inout AppConfig) {
        guard config.dragMappingsManaged else { return }
        let enabled = config.mappingStore.mappings.filter { $0.isEnabled && !$0.trigger.isButtonPress }
        let buttons = Set(enabled.map { $0.input.cgNumber })
        if !buttons.isEmpty { config.gestureButtons = buttons }
        config.horizontalEnabled = enabled.contains { $0.trigger == .drag(.left) || $0.trigger == .drag(.right) }
        config.verticalEnabled = enabled.contains { $0.trigger == .drag(.up) || $0.trigger == .drag(.down) }
    }
}

// A posting boundary, not a gesture recognizer. Direction is selected only when
// the unchanged machines emit began. Subsequent reversal belongs to that same
// sequence. No thresholds, timing, progress or frame contents are changed.
struct LegacyDragDelivery {
    private let masks: [Int: Set<MouseDragDirection>]?
    private var held: Set<Int> = []
    private var candidates: Set<Int> = []
    private var horizontalAllowed: Bool?
    private var verticalAllowed: Bool?
    init(config: AppConfig) {
        guard config.dragMappingsManaged else { masks = nil; return }
        var result: [Int: Set<MouseDragDirection>] = [:]
        for row in config.mappingStore.mappings where row.isEnabled {
            if case .drag(let direction) = row.trigger { result[row.input.cgNumber, default: []].insert(direction) }
        }
        masks = result
    }
    mutating func down(_ button: Int) { held.insert(button); candidates.insert(button) }
    mutating func up(_ button: Int) { held.remove(button) } // Keep release-time flush eligible.
    mutating func retire(_ button: Int) { held.remove(button); candidates.remove(button) }
    mutating func begin() { candidates = held; horizontalAllowed = nil; verticalAllowed = nil }
    mutating func reset() { held = []; end() }
    mutating func end() { candidates = held; horizontalAllowed = nil; verticalAllowed = nil }
    mutating func filter(_ frames: [GestureFrame], vertical: Bool, direction: MouseDragDirection) -> [GestureFrame] {
        guard let masks else { return frames }
        var output: [GestureFrame] = []
        for frame in frames {
            var allowed = vertical ? verticalAllowed : horizontalAllowed
            if frame.phase == .began {
                allowed = candidates.contains { masks[$0]?.contains(direction) == true }
            }
            if allowed == true { output.append(frame) }
            if frame.phase == .ended || frame.phase == .cancelled { allowed = nil }
            if vertical { verticalAllowed = allowed } else { horizontalAllowed = allowed }
        }
        return output
    }
}
