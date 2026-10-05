import Foundation

private func v2Fixture() -> AppConfig {
    var config = AppConfig(); config.dragMappingsManaged = true; config.sensitivity = 713.25
    config.mappings = [
        MouseMapping(input: .button(7), trigger: .modifiedShortPress([.command, .shift]), action: .system(.showDesktop), isEnabled: false),
        MouseMapping(input: .button(8), trigger: .longPress, action: .window(.minimize))
    ] + [MouseDragDirection.left, .right, .down].map {
        MouseMapping(input: .button(4), trigger: .drag($0), action: LegacyDragSettingsAdapter.action(for: $0, inverted: true), isEnabled: $0 != .down)
    } + MouseDragDirection.allCases.map {
        MouseMapping(input: .button(5), trigger: .drag($0), action: LegacyDragSettingsAdapter.action(for: $0, inverted: true))
    }
    return config.validated()
}
private func v2Model(_ config: AppConfig = v2Fixture()) -> AppViewModel {
    let model = AppViewModel(config: config)
    model.applyConfig = { [weak model] next, _ in model?.show(next.validated()) }
    return model
}
private func v2Group(_ model: AppViewModel, _ input: MouseInput = .button(4)) -> GestureMappingGroup {
    MappingPresentation.gestureGroup(input, in: model.config.mappingStore)!
}
private func v2States(_ group: GestureMappingGroup) -> [MouseDragDirection: Bool] {
    Dictionary(uniqueKeysWithValues: group.rows.compactMap { row in
        if case .drag(let direction) = row.trigger { return (direction, row.isEnabled) }; return nil
    })
}
private func v2RoundTrip(_ config: AppConfig) throws {
    let suite = "local.macmousegesture.ui-v2.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = ConfigStore(defaults: defaults); store.save(config)
    expectEqual(store.load(), config)
    let data = defaults.dictionary(forKey: ConfigStore.key)![ConfigStore.mappingsKey] as! Data
    expectEqual(try MouseMappingStore(data: data), config.mappingStore)
}

let uiV2Checks: [(String, () throws -> Void)] = [
    ("v2 grouping does not mutate direction IDs missing rows or disabled states", {
        let config = v2Fixture(); let before = config.mappingStore
        let rows = MappingPresentation.tableRows(in: before)
        expectEqual(rows.count, 4)
        let group = MappingPresentation.gestureGroup(.button(4), in: before)!
        expectEqual(group.rows.count, 3); expectEqual(group.enabledCount, 2)
        expectEqual(config.mappingStore, before); expectTrue(config.mappingStore.mapping(for: .button(4), trigger: .drag(.up)) == nil)
        expectEqual(MappingPresentation.inputLabel(before.mapping(for: .button(7), trigger: .modifiedShortPress([.command, .shift]))!), "⇧⌘ + 鼠标按钮 7")
        expectEqual(MappingActionOption.none.action, MouseAction.none)
    }),
    ("v2 disabled duplicate and edit conflicts leave configuration untouched", {
        let model = v2Model(); let before = model.config
        var draft = MappingUIDraft(); draft.hasInput = true; draft.input = .button(7); draft.modifiers = [.command, .shift]
        if case .existing(.mapping(let row)) = model.saveMappingDraft(draft) { expectFalse(row.isEnabled) } else { expectTrue(false) }
        expectEqual(model.config, before)
        let original = model.config.mappingStore.mapping(for: .button(8), trigger: .longPress)!
        draft = MappingUIDraft(.mapping(original)); draft.input = .button(7); draft.modifiers = [.command, .shift]; draft.operation = .short
        if case .existing = model.saveMappingDraft(draft) {} else { expectTrue(false) }
        expectEqual(model.config, before)
    }),
    ("v2 retarget grouped input preserves IDs partial enablement and parameters", {
        let model = v2Model(); let before = model.config; let group = v2Group(model)
        var draft = MappingUIDraft(.gestures(group)); draft.input = .button(19)
        if case .saved = model.saveMappingDraft(draft) {} else { expectTrue(false) }
        let moved = v2Group(model, .button(19))
        expectEqual(moved.rows.map(\.id), group.rows.map(\.id)); expectEqual(v2States(moved), v2States(group))
        expectEqual(model.config.mappingStore.mappings.filter { $0.input != .button(19) }, before.mappingStore.mappings.filter { $0.input != .button(4) })
        expectEqual(model.config.sensitivity, before.sensitivity); expectEqual(model.config.deadZone, before.deadZone)
        try v2RoundTrip(model.config)
    }),
    ("v2 grouped conflict is atomic and never merges direction records", {
        let model = v2Model(); let before = model.config
        var writes = 0; model.applyConfig = { _, _ in writes += 1 }
        var draft = MappingUIDraft(.gestures(v2Group(model))); draft.input = .button(5)
        if case .existing(.gestures(let group)) = model.saveMappingDraft(draft) { expectEqual(group.input, .button(5)) } else { expectTrue(false) }
        expectEqual(writes, 0); expectEqual(model.config, before)
        draft.input = .button(19); draft.modifiers = .command
        if case .unavailable = model.saveMappingDraft(draft) {} else { expectTrue(false) }
        expectEqual(writes, 0); expectEqual(model.config, before)
    }),
    ("v2 detail saves once without resurrecting an absent direction or changing IDs", {
        let model = v2Model(); let before = model.config; let group = v2Group(model)
        var writes = 0; model.applyConfig = { [weak model] next, _ in writes += 1; model?.show(next.validated()) }
        var parameters = MappingGestureParameters(before); parameters.inverted = false
        model.saveGestureDetails(input: group.input, enabled: v2States(group), parameters: parameters)
        expectEqual(writes, 1); expectEqual(v2States(v2Group(model)), v2States(group))
        expectEqual(model.config.mappingStore.mappings.map(\.id), before.mappingStore.mappings.map(\.id))
        expectTrue(model.config.mappingStore.mapping(for: .button(4), trigger: .drag(.up)) == nil)
        expectEqual(model.config.mappingStore.mapping(for: .button(4), trigger: .drag(.left))!.action, .system(.nextSpace))
        expectEqual(model.config.mappingStore.mapping(for: .button(5), trigger: .drag(.right))!.action, .system(.previousSpace))
        expectEqual(model.config.sensitivity, 713.25)
        try v2RoundTrip(model.config)
    }),
    ("v2 only an explicit missing direction selection creates its mapping", {
        let model = v2Model(); let group = v2Group(model); var states = v2States(group); states[.up] = true
        model.saveGestureDetails(input: group.input, enabled: states, parameters: MappingGestureParameters(model.config))
        expectEqual(v2Group(model).rows.count, 4)
        expectEqual(v2Group(model).rows.filter { group.rows.map(\.id).contains($0.id) }, group.rows)
        expectEqual(model.config.mappingStore.mapping(for: .button(4), trigger: .drag(.up))!.action, .system(.missionControl))
    }),
    ("v2 global-only save and default reset do not adopt or reset legacy directions", {
        let model = v2Model(AppConfig.defaults.validated()); let before = model.config
        var parameters = MappingGestureParameters(before); parameters.distance = 17
        model.saveGestureDetails(input: .button(4), enabled: v2States(v2Group(model)), parameters: parameters)
        expectFalse(model.config.dragMappingsManaged); expectEqual(model.config.mappingStore.mappings, before.mappingStore.mappings)
        model.saveGestureDetails(input: .button(4), enabled: v2States(v2Group(model)), parameters: MappingGestureParameters(.defaults))
        expectFalse(model.config.dragMappingsManaged); expectEqual(model.config, before)
    }),
    ("v2 group stop resume and restart preserve deliberate direction choices", {
        let model = v2Model(); let before = model.config; let group = v2Group(model)
        expectTrue(model.toggleGestureGroup(group.input)); expectEqual(v2Group(model).enabledCount, 0)
        let stopped = model.config; try v2RoundTrip(stopped)
        expectEqual(v2Group(model).rows.map(\.id), group.rows.map(\.id))
        expectTrue(model.toggleGestureGroup(group.input)); expectEqual(model.config, before)
        let restarted = v2Model(stopped)
        expectFalse(restarted.toggleGestureGroup(group.input)); expectEqual(restarted.config, stopped)
    }),
    ("v2 grouped delete undo restores original records and persists without a schema change", {
        let model = v2Model(); let before = model.config; let group = v2Group(model)
        model.deleteMappingRow(.gestures(group))
        expectTrue(MappingPresentation.gestureGroup(group.input, in: model.config.mappingStore) == nil)
        expectEqual(model.config.mappingStore.mappings, before.mappingStore.mappings.filter { $0.input != group.input })
        expectTrue(model.undoMappingDeletion()); expectEqual(Set(model.config.mappingStore.mappings.map(\.id)), Set(before.mappingStore.mappings.map(\.id)))
        expectEqual(v2States(v2Group(model)), v2States(group)); try v2RoundTrip(model.config)
    }),
    ("v2 conflicting undo fails without overwriting a newer mapping", {
        let model = v2Model(); let group = v2Group(model); model.deleteMappingRow(.gestures(group))
        let row = MouseMapping(input: group.input, trigger: .drag(.left), action: .system(.previousSpace))
        _ = model.saveMapping(row); let before = model.config
        expectFalse(model.undoMappingDeletion()); expectEqual(model.config, before)
    })
]
