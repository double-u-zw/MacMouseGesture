import SwiftUI

enum SettingsTab: Hashable, CaseIterable {
    case mappings, gestures, general, diagnostics, about
    var title: String {
        switch self { case .mappings: "鼠标映射"; case .gestures: "手势"; case .general: "通用"; case .diagnostics: "帮助"; case .about: "关于" }
    }
}

final class AppViewModel: ObservableObject {
    @Published private(set) var config: AppConfig
    @Published var selectedTab: SettingsTab = .mappings
    @Published var status: UserStatus = .recovering
    @Published var accessibilityGranted = false
    @Published var inputMonitoringGranted = false
    @Published var loginState: LoginItemState = .off
    @Published var snapshot = EngineUISnapshot()
    @Published var advancedReport = ""
    @Published var message: String?
    @Published var mappingNotice: String?
    @Published var deletedMappingRows: [MouseMapping]?
    // Session-only undo of an explicit group stop; no preference keys or schema additions.
    private var gestureEnableHistory: [MouseInput: [UUID: Bool]] = [:]

    @Published var onboarding = OnboardingState()
    @Published var onboardingVisible = OnboardingState.needsWelcome()
    @Published var sideButtonCount = 0
    @Published var waitingForButton = false
    @Published var lastSideButton = ""
    var finishOnboarding: (() -> Void)?
    var reopenOnboarding: (() -> Void)?

    var applyConfig: ((AppConfig, Bool) -> Void)?
    var setLoginEnabled: ((Bool) -> Void)?
    var openAccessibility: (() -> Void)?
    var openInputMonitoring: (() -> Void)?
    var openLoginItems: (() -> Void)?
    var copyDiagnostics: (() -> Void)?
    var saveDiagnostics: (() -> Void)?
    var restartEngine: (() -> Void)?
    @Published var mouseRecording: MouseRecordingStatus = .idle
    var beginMouseRecording: (() -> Void)?
    var endMouseRecording: ((MouseRecordingEndReason) -> Void)?

    init(config: AppConfig = .defaults) { self.config = config }

    func show(_ config: AppConfig) { self.config = config }

    func resetGestureSettings() {
        applyConfig?(GestureSettings.restoringDefaults(config), false)
    }

    enum MappingEditResult { case saved, existing(MouseMapping), unavailable }
    // Arbitrary drag actions remain unsupported by the established runtime.
    // The unified editor uses the direction action supplied by its adapter.
    func saveMapping(_ row: MouseMapping) -> MappingEditResult {
        guard row.input.isSupported else { return .unavailable }
        if case .drag(let direction) = row.trigger,
           row.action != LegacyDragSettingsAdapter.action(for: direction, inverted: config.horizontalInvert) { return .unavailable }
        var store = config.mappingStore
        if let conflict = store.mapping(for: row.input, trigger: row.trigger), conflict.id != row.id {
            return .existing(conflict)
        }
        let previous = store.mappings.first { $0.id == row.id }
        if previous != nil {
            guard store.update(row) else { return .unavailable }
        } else { guard store.add(row) == row.id else { return .unavailable } }
        if LegacyMappingProjection.isEmptyPlaceholder(row) {
            // Explicitly saving no-op is a real user row, no longer a migration placeholder.
            var explicit = row; explicit.id = UUID()
            store.delete(row.id); store.add(explicit)
        }
        let next = LegacyDragSettingsAdapter.writing(store, to: config, editingDrag: !row.trigger.isButtonPress || previous?.trigger.isButtonPress == false)
        applyConfig?(next, false)
        return .saved
    }
    func setMappingEnabled(_ enabled: Bool, id: UUID) {
        var store = config.mappingStore
        guard let row = store.mappings.first(where: { $0.id == id }) else { return }
        store.setEnabled(enabled, id: id)
        let next = LegacyDragSettingsAdapter.writing(store, to: config, editingDrag: !row.trigger.isButtonPress)
        applyConfig?(next, false)
    }
    func deleteMapping(_ id: UUID) {
        var store = config.mappingStore
        guard let row = store.mappings.first(where: { $0.id == id }) else { return }
        store.delete(id)
        let next = LegacyDragSettingsAdapter.writing(store, to: config, editingDrag: !row.trigger.isButtonPress)
        applyConfig?(next, false)
    }

    func binding<Value>(_ keyPath: WritableKeyPath<AppConfig, Value>, debounce: Bool = false) -> Binding<Value> {
        Binding(get: { self.config[keyPath: keyPath] }, set: { value in
            var next = self.config
            next[keyPath: keyPath] = value
            self.applyConfig?(next, debounce)
        })
    }

    var sensitivityBinding: Binding<Double> {
        Binding(get: { GestureSettings.sensitivityPosition(for: self.config.sensitivity) }, set: { value in
            var next = self.config
            next.sensitivity = GestureSettings.sensitivityValue(at: value)
            self.applyConfig?(next, true)
        })
    }

    static var preview: AppViewModel {
        let model = AppViewModel()
        model.status = .running
        model.accessibilityGranted = true
        model.inputMonitoringGranted = true
        model.snapshot = EngineUISnapshot(eventTap: "enabled", hidActive: true)
        return model
    }

    enum MappingDraftResult { case saved, existing(MappingTableRow), unavailable }
    func mappingConflict(_ draft: MappingUIDraft) -> MappingTableRow? {
        guard draft.hasInput else { return nil }
        let store = config.mappingStore
        if draft.operation == .drag {
            if let group = MappingPresentation.gestureGroup(draft.input, in: store), group.rows.contains(where: { !draft.originalIDs.contains($0.id) }) { return .gestures(group) }
        } else if let row = store.mapping(for: draft.input, trigger: draft.operation.trigger(modifiers: draft.modifiers)), !draft.originalIDs.contains(row.id) {
            return .mapping(row)
        }
        return nil
    }
    func saveMappingDraft(_ draft: MappingUIDraft) -> MappingDraftResult {
        guard draft.hasInput, draft.input.isSupported, !(draft.operation == .drag && !draft.modifiers.isEmpty),
              !(draft.isGestureGroup && draft.operation != .drag) else { return .unavailable }
        if let conflict = mappingConflict(draft) { return .existing(conflict) }
        if draft.operation != .drag {
            let row = MouseMapping(id: draft.originalIDs.first ?? draft.id, input: draft.input,
                trigger: draft.operation.trigger(modifiers: draft.modifiers), action: draft.action, isEnabled: draft.enabled)
            switch saveMapping(row) {
            case .saved: mappingNotice = draft.isNew ? "已添加映射" : "已保存修改"; deletedMappingRows = nil; return .saved
            case .existing(let existing): return .existing(.mapping(existing))
            case .unavailable: return .unavailable
            }
        }
        var store = config.mappingStore
        switch draft.source {
        case .gestures(let original):
            guard original.rows.allSatisfy({ previous in store.mappings.contains { $0.id == previous.id && $0.input == original.input } }) else { return .unavailable }
            for previous in original.rows {
                var row = store.mappings.first { $0.id == previous.id }!
                row.input = draft.input
                if draft.enabled != original.isEnabled { row.isEnabled = draft.enabled }
                guard store.update(row) else { return .unavailable }
            }
            gestureEnableHistory.removeValue(forKey: original.input)
        case .new, .mapping:
            for id in draft.originalIDs { store.delete(id) }
            for direction in MouseDragDirection.allCases {
                let row = MouseMapping(input: draft.input, trigger: .drag(direction),
                    action: LegacyDragSettingsAdapter.action(for: direction, inverted: config.horizontalInvert), isEnabled: draft.enabled)
                guard store.add(row) == row.id else { return .unavailable }
            }
        }
        applyConfig?(LegacyDragSettingsAdapter.writing(store, to: config, editingDrag: true), false)
        mappingNotice = draft.isNew ? "已添加映射" : "已保存修改"; deletedMappingRows = nil
        return .saved
    }
    func deleteMappingRow(_ item: MappingTableRow) {
        let ids: Set<UUID>
        switch item { case .mapping(let row): ids = [row.id]; case .gestures(let group): ids = Set(group.rows.map(\.id)); gestureEnableHistory.removeValue(forKey: group.input) }
        var store = config.mappingStore
        let removed = store.mappings.filter { ids.contains($0.id) }
        guard !removed.isEmpty else { return }
        for row in removed { store.delete(row.id) }
        applyConfig?(LegacyDragSettingsAdapter.writing(store, to: config, editingDrag: removed.contains { !$0.trigger.isButtonPress }), false)
        deletedMappingRows = removed; mappingNotice = "已删除映射"
    }
    @discardableResult func undoMappingDeletion() -> Bool {
        guard let rows = deletedMappingRows else { return false }
        var store = config.mappingStore
        guard rows.allSatisfy({ row in store.mapping(for: row.input, trigger: row.trigger) == nil && !store.mappings.contains { $0.id == row.id } }) else {
            mappingNotice = "已有映射使用相同输入，暂时无法撤销删除。"; return false
        }
        for row in rows { guard store.add(row) == row.id else { return false } }
        applyConfig?(LegacyDragSettingsAdapter.writing(store, to: config, editingDrag: rows.contains { !$0.trigger.isButtonPress }), false)
        deletedMappingRows = nil; mappingNotice = "已恢复映射"; return true
    }
    // A restart preserves stopped directions. Without session history, choose directions
    // in the detail sheet rather than silently enabling a previously disabled direction.
    @discardableResult func toggleGestureGroup(_ input: MouseInput) -> Bool {
        var store = config.mappingStore
        guard let group = MappingPresentation.gestureGroup(input, in: store) else { return false }
        if group.isEnabled {
            gestureEnableHistory[input] = Dictionary(uniqueKeysWithValues: group.rows.map { ($0.id, $0.isEnabled) })
            for row in group.rows { store.setEnabled(false, id: row.id) }
        } else {
            guard let previous = gestureEnableHistory[input], Set(previous.keys) == Set(group.rows.map(\.id)) else { return false }
            for row in group.rows { store.setEnabled(previous[row.id] == true, id: row.id) }
            gestureEnableHistory.removeValue(forKey: input)
        }
        applyConfig?(LegacyDragSettingsAdapter.writing(store, to: config, editingDrag: true), false)
        mappingNotice = group.isEnabled ? "已停用映射" : "已启用映射"; deletedMappingRows = nil
        return true
    }
    func saveGestureDetails(input: MouseInput, enabled: [MouseDragDirection: Bool], parameters: MappingGestureParameters) {
        guard input.isSupported, MappingPresentation.gestureGroup(input, in: config.mappingStore) != nil else { return }
        var store = config.mappingStore
        for direction in MouseDragDirection.allCases {
            if let row = store.mapping(for: input, trigger: .drag(direction)) {
                store.setEnabled(enabled[direction] == true, id: row.id)
            } else if enabled[direction] == true {
                store.add(MouseMapping(input: input, trigger: .drag(direction), action: LegacyDragSettingsAdapter.action(for: direction, inverted: parameters.inverted)))
            }
        }
        let changedDirections = store != config.mappingStore
        var next = config
        next.horizontalInvert = parameters.inverted; next.sensitivity = parameters.sensitivity
        next.deadZone = parameters.distance; next.freezePointer = parameters.freeze
        applyConfig?(LegacyDragSettingsAdapter.writing(store, to: next, editingDrag: changedDirections), false)
        gestureEnableHistory.removeValue(forKey: input)
        mappingNotice = "已保存手势设置"; deletedMappingRows = nil
    }
}
