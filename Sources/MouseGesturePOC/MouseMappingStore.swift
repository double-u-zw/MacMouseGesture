import Foundation

// A value snapshot: main-thread edits and engine-queue resolution never share mutable state.
// ConfigStore commits this document with the gesture preferences in one defaults value.
struct MouseMappingStore: Equatable {
    private(set) var mappings: [MouseMapping]
    init(mappings: [MouseMapping] = []) {
        var inputs: Set<MappingKey> = []; var ids: Set<UUID> = []
        self.mappings = mappings.filter {
            $0.input.isSupported && inputs.insert(MappingKey($0)).inserted && ids.insert($0.id).inserted
        }
    }
    func mapping(for input: MouseInput, trigger: MouseTrigger) -> MouseMapping? {
        mappings.first { $0.input == input && $0.trigger == trigger }
    }
    func action(for input: MouseInput, trigger: MouseTrigger) -> MouseAction? {
        guard let row = mapping(for: input, trigger: trigger), row.isEnabled else { return nil }
        return row.action
    }
    func shortPressAction(for input: MouseInput, modifiers: MouseModifiers) -> MouseAction? {
        pressAction(for: input, trigger: .shortPress, modifiers: modifiers)
    }
    func longPressAction(for input: MouseInput, modifiers: MouseModifiers) -> MouseAction? {
        pressAction(for: input, trigger: .longPress, modifiers: modifiers)
    }
    func wheelActions(for input: MouseInput, modifiers: MouseModifiers) -> [MouseWheelDirection: MouseAction] {
        // Wheel chords match the frozen modifier set exactly, without subset/fallback matches.
        var actions: [MouseWheelDirection: MouseAction] = [:]
        for direction in MouseWheelDirection.allCases {
            if let action = action(for: input, trigger: .wheel(direction, modifiers: modifiers)), action != .none {
                actions[direction] = action
            }
        }
        return actions
    }
    private func pressAction(for input: MouseInput, trigger: MouseTrigger, modifiers: MouseModifiers) -> MouseAction? {
        // A disabled exact row intentionally suppresses fallback too, for either press type.
        if let exact = mapping(for: input, trigger: trigger.withModifiers(modifiers)) {
            return exact.isEnabled ? exact.action : nil
        }
        return modifiers.isEmpty ? nil : action(for: input, trigger: trigger)
    }
    // Duplicates enter the existing editor; never create a second effective action.
    @discardableResult mutating func add(_ mapping: MouseMapping) -> UUID? {
        guard mapping.input.isSupported else { return nil }
        if let existing = self.mapping(for: mapping.input, trigger: mapping.trigger) { return existing.id }
        guard !mappings.contains(where: { $0.id == mapping.id }) else { return nil }
        mappings.append(mapping); return mapping.id
    }
    @discardableResult mutating func update(_ mapping: MouseMapping) -> Bool {
        guard mapping.input.isSupported, let index = mappings.firstIndex(where: { $0.id == mapping.id }),
              !mappings.contains(where: { $0.id != mapping.id && $0.input == mapping.input && $0.trigger == mapping.trigger }) else { return false }
        mappings[index] = mapping; return true
    }
    mutating func delete(_ id: UUID) { mappings.removeAll { $0.id == id } }
    mutating func setEnabled(_ enabled: Bool, id: UUID) {
        guard let i = mappings.firstIndex(where: { $0.id == id }) else { return }
        mappings[i].isEnabled = enabled
    }
    var shortPressCGButtons: Set<Int> {
        Set(mappings.filter { $0.isEnabled && $0.trigger.isShortPress && $0.action != .none }.map { $0.input.cgNumber })
    }
    var pressCGButtons: Set<Int> {
        Set(mappings.filter { $0.isEnabled && $0.trigger.isButtonPress && $0.action != .none }.map { $0.input.cgNumber })
    }
    var wheelCGButtons: Set<Int> {
        Set(mappings.filter { $0.isEnabled && $0.trigger.isWheel && $0.action != .none }.map { $0.input.cgNumber })
    }
    func encoded() throws -> Data {
        // Older v1 readers must not reinterpret a modifier mapping as a plain click.
        try JSONEncoder().encode(Document(version: mappings.contains { $0.trigger.isWheel } ? 4 : mappings.contains { $0.trigger.isLongPress } ? 3 : mappings.contains { !$0.trigger.modifiers.isEmpty } ? 2 : 1, mappings: mappings))
    }
    init(data: Data) throws {
        let d = try JSONDecoder().decode(Document.self, from: data)
        guard (1...4).contains(d.version),
              !d.mappings.contains(where: { ($0.trigger.isWheel && d.version < 4) || ($0.trigger.isLongPress && d.version < 3) || (!$0.trigger.modifiers.isEmpty && d.version < 2) }) else { throw MappingError.unsupportedVersion }
        self.init(mappings: d.mappings)
    }
    private struct Document: Codable { var version: Int; var mappings: [MouseMapping] }
    enum MappingError: Error { case unsupportedVersion }
    private struct MappingKey: Hashable {
        let input: MouseInput; let trigger: MouseTrigger
        init(_ mapping: MouseMapping) { input = mapping.input; trigger = mapping.trigger }
    }
}

enum LegacyMappingProjection {
    // Stable IDs make migration/reprojection deterministic; no new rows on restart.
    static func id(button: Int, trigger: MouseTrigger) -> UUID {
        UUID(uuidString: String(format: "4D4D4700-0001-0000-%04X-%012X", button, trigger.order))!
    }
    static func shortPress(button: Int, action: MouseAction) -> MouseMapping {
        MouseMapping(id: id(button: button, trigger: .shortPress), input: .button(button), trigger: .shortPress, action: action)
    }
    static var defaults: [MouseMapping] {
        [shortPress(button: 4, action: .none), shortPress(button: 5, action: .none)]
    }
    static func isEmptyPlaceholder(_ row: MouseMapping) -> Bool {
        row.trigger == .shortPress && row.action == .none && defaults.contains { $0.id == row.id }
    }
    static func drags(config: AppConfig) -> [MouseMapping] {
        // Physical left/right depend on the already-confirmed inversion setting.
        let directions: [(MouseDragDirection, MouseAction, Bool)] = [
            (.left, .system(config.horizontalInvert ? .previousSpace : .nextSpace), config.horizontalEnabled),
            (.right, .system(config.horizontalInvert ? .nextSpace : .previousSpace), config.horizontalEnabled),
            (.up, .system(.missionControl), config.verticalEnabled), (.down, .system(.appExpose), config.verticalEnabled)]
        return Set([3, 4]).union(config.gestureButtons).sorted().flatMap { cg -> [MouseMapping] in
            guard let identifier = MouseButtonIdentifier(rawValue: cg) else { return [] }
            return directions.map { direction, action, enabled in
                let trigger = MouseTrigger.drag(direction)
                return MouseMapping(id: id(button: identifier.number, trigger: trigger), input: identifier.input, trigger: trigger,
                                    action: action, isEnabled: enabled && config.gestureButtons.contains(cg))
            }
        }
    }
}
