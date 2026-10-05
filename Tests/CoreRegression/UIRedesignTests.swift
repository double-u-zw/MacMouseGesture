import Foundation
import GestureCore

private func uiRow(_ button: Int = 8, _ trigger: MouseTrigger = .shortPress, enabled: Bool = true) -> MouseMapping {
    MouseMapping(input: .button(button), trigger: trigger, action: .system(.showDesktop), isEnabled: enabled)
}
private func uiModel(_ config: AppConfig = .defaults) -> AppViewModel {
    let model = AppViewModel(config: config.validated())
    model.applyConfig = { [weak model] next, _ in model?.show(next.validated()) }
    return model
}
private func uiDefaults(_ body: (ConfigStore, UserDefaults) throws -> Void) rethrows {
    let name = "local.macmousegesture.ui.\(UUID())"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    try body(ConfigStore(defaults: defaults), defaults)
}
private func uiSource(_ file: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent("Sources/MouseGesturePOC/" + file), encoding: .utf8)
}

let uiRedesignChecks: [(String, () throws -> Void)] = [
    ("UI groups physical buttons, combining modifier rows", {
        let rows = [uiRow(4), uiRow(4, .modifiedLongPress(.command)), uiRow(4, .modifiedWheel(.up, .shift))]
        let groups = MappingPresentation.groups(in: MouseMappingStore(mappings: rows))
        expectEqual(groups.count, 1); expectEqual(groups[0].rows.count, 3); expectEqual(groups[0].title, "侧键 4")
    }),
    ("UI groups use physical number ordering including middle and extra buttons", {
        let groups = MappingPresentation.groups(in: MouseMappingStore(mappings: [32, 7, 5, 3, 4].map { uiRow($0) }))
        expectEqual(groups.map { $0.input.number }, [3, 4, 5, 7, 32])
        expectEqual(groups.map(\.title), ["中键", "侧键 4", "侧键 5", "鼠标按钮 7", "鼠标按钮 32"])
    }),
    ("UI empty store has no placeholder groups", {
        expectTrue(MappingPresentation.groups(in: MouseMappingStore()).isEmpty)
        expectTrue(MappingPresentation.groups(in: MouseMappingStore(mappings: LegacyMappingProjection.defaults)).isEmpty)
    }),
    ("UI explicit no-op user rows remain editable", {
        var row = uiRow(4); row.action = .none
        expectEqual(MappingPresentation.groups(in: MouseMappingStore(mappings: [row])).first?.rows, [row])
    }),
    ("UI explicitly saving a legacy no-op remains visible and editable", {
        let model = uiModel(); let row = model.config.mappingStore.mapping(for: .button(4), trigger: .shortPress)!
        if case .saved = model.saveMapping(row) {} else { expectTrue(false) }
        let saved = model.config.mappingStore.mapping(for: row.input, trigger: row.trigger)!
        expectEqual(saved.action, MouseAction.none)
        expectTrue(MappingPresentation.groups(in: model.config.mappingStore).flatMap(\.rows).contains(saved))
        model.setMappingEnabled(false, id: saved.id)
        expectFalse(model.config.mappingStore.mappings.first { $0.id == saved.id }!.isEnabled)
        uiDefaults { store, _ in store.save(model.config); expectEqual(store.load(), model.config) }
    }),
    ("UI trigger ordering is stable independent of storage order and UUID", {
        let triggers: [MouseTrigger] = [.drag(.down), .wheelDown, .drag(.up), .longPress, .drag(.right), .wheelUp, .drag(.left), .shortPress]
        let rows = MappingPresentation.groups(in: MouseMappingStore(mappings: triggers.map { uiRow(8, $0) }))[0].rows
        expectEqual(rows.map(\.trigger), [.shortPress, .longPress, .wheelUp, .wheelDown, .drag(.left), .drag(.right), .drag(.up), .drag(.down)])
    }),
    ("UI modifier variants sort within their trigger", {
        let triggers: [MouseTrigger] = [.modifiedShortPress(.command), .shortPress, .modifiedShortPress(.control)]
        expectEqual(MappingPresentation.groups(in: MouseMappingStore(mappings: triggers.map { uiRow(8, $0) }))[0].rows.map(\.trigger),
                    [.shortPress, .modifiedShortPress(.control), .modifiedShortPress(.command)])
    }),
    ("UI modifier labels use familiar symbols", {
        expectEqual(MappingPresentation.triggerLabel(.modifiedLongPress([.command, .shift])), "⇧⌘ + 长按")
        expectEqual(MappingPresentation.triggerLabel(.modifiedWheel(.down, .control)), "⌃ + 按住并向下滚动")
    }),
    ("UI keyboard actions show shortcut instead of a generic title", {
        expectEqual(MappingPresentation.actionLabel(.keyboardShortcut(KeyboardShortcut(keyCode: 48, modifierFlags: 262144)!)), "键盘快捷键 · ⌃⇥")
        expectEqual(MappingPresentation.actionLabel(.system(.showDesktop)), MouseAction.system(.showDesktop).title)
    }),
    ("UI disabled rows stay visible with their enabled state", {
        let row = uiRow(enabled: false)
        expectEqual(MappingPresentation.groups(in: MouseMappingStore(mappings: [row]))[0].rows, [row])
    }),
    ("UI add then edit then delete generic extra button mapping", {
        let model = uiModel(); var row = uiRow(17)
        if case .saved = model.saveMapping(row) {} else { expectTrue(false) }
        row.action = .none
        if case .saved = model.saveMapping(row) {} else { expectTrue(false) }
        expectEqual(model.config.mappingStore.mappings.first { $0.id == row.id }?.action, MouseAction.none)
        model.deleteMapping(row.id); expectFalse(model.config.mappingStore.mappings.contains { $0.id == row.id })
    }),
    ("UI independent short toggle preserves long wheel and drag", {
        var config = AppConfig(); config.mappings = [.shortPress, .longPress, .wheelUp, .wheelDown].map { uiRow(5, $0) }
        let model = uiModel(config); let before = model.config.mappingStore.mappings
        let short = before.first { $0.trigger == .shortPress }!
        model.setMappingEnabled(false, id: short.id)
        expectEqual(model.config.mappingStore.mappings.filter { $0.id != short.id }, before.filter { $0.id != short.id })
        expectFalse(model.config.dragMappingsManaged)
    }),
    ("UI duplicate returns existing and leaves configuration unchanged", {
        let model = uiModel(); let row = uiRow(9, .modifiedWheel(.up, .command))
        _ = model.saveMapping(row); let before = model.config
        var other = row; other.id = UUID(); other.action = .none
        if case .existing(let existing) = model.saveMapping(other) { expectEqual(existing, row) } else { expectTrue(false) }
        expectEqual(model.config, before)
    }),
    ("UI editing into another row conflict preserves both rows", {
        let model = uiModel(); let a = uiRow(9); var b = uiRow(10)
        _ = model.saveMapping(a); _ = model.saveMapping(b); let before = model.config
        b.input = a.input
        if case .existing(let existing) = model.saveMapping(b) { expectEqual(existing, a) } else { expectTrue(false) }
        expectEqual(model.config, before)
    }),
    ("UI rejects reserved left and right inputs", {
        let model = uiModel(); let before = model.config
        for button in [1, 2, 33] {
            if case .unavailable = model.saveMapping(uiRow(button)) {} else { expectTrue(false) }
        }
        expectEqual(model.config, before)
    }),
    ("UI deleting all rows produces a durable empty configuration", {
        let model = uiModel()
        for row in model.config.mappingStore.mappings { model.deleteMapping(row.id) }
        expectTrue(model.config.dragMappingsManaged); expectFalse(model.config.shouldRun)
        expectTrue(MappingPresentation.groups(in: model.config.mappingStore).isEmpty)
        uiDefaults { store, _ in store.save(model.config); expectTrue(store.load().mappingStore.mappings.isEmpty) }
    }),
    ("UI default navigation enters mappings and preserves auxiliary tabs", {
        expectEqual(AppViewModel().selectedTab, .mappings)
        expectEqual(SettingsTab.allCases.map(\.title), ["鼠标映射", "手势", "通用", "帮助", "关于"])
    }),
    ("UI settings no longer expose legacy button or axis controls", {
        let source = try uiSource("SettingsView.swift")
        for old in ["现有拖动手势", "buttonBinding", "\\.horizontalEnabled", "\\.verticalEnabled", "MappingSettingsSection"] { expectFalse(source.contains(old)) }
        expectFalse(source.contains("TabView("))
        let general = try uiSource("ApplicationSettingsView.swift")
        expectFalse(general.contains("horizontalInvert")); expectFalse(general.contains("mouseMappingsV1"))
    }),
    ("UI mapping views use dynamic groups and one universal editor", {
        let source = try uiSource("MappingSettingsView.swift")
        expectTrue(source.contains("ForEach(rows)")); expectTrue(source.contains("MappingEditorView"))
        for old in ["Button4Section", "Button5Section", "button4ClickAction", "button5ClickAction", "现有拖动手势", "查看拖动映射"] { expectFalse(source.contains(old)) }
        let editor = try uiSource("MappingEditorView.swift")
        expectTrue(editor.contains("编辑现有")); expectTrue(source.contains("删除这条映射")); expectTrue(source.contains("还没有鼠标映射"))
    }),
    ("drag adapter reads legacy axes membership and inversion without adoption", {
        var config = AppConfig(); config.gestureButtons = [4]; config.horizontalEnabled = false; config.horizontalInvert = false
        expectFalse(config.mappingStore.mapping(for: .button(4), trigger: .drag(.up))!.isEnabled)
        expectTrue(config.mappingStore.mapping(for: .button(5), trigger: .drag(.up))!.isEnabled)
        expectFalse(config.mappingStore.mapping(for: .button(5), trigger: .drag(.left))!.isEnabled)
        expectEqual(config.mappingStore.mapping(for: .button(5), trigger: .drag(.left))!.action, .system(.nextSpace))
        expectFalse(config.validated().dragMappingsManaged)
    }),
    ("drag adapter first edit adopts stable IDs and preserves press mappings", {
        let model = uiModel(); let before = model.config.mappingStore.mappings
        let left = before.first { $0.trigger == .drag(.left) }!
        model.setMappingEnabled(false, id: left.id)
        expectTrue(model.config.dragMappingsManaged)
        expectEqual(model.config.mappingStore.mappings.map(\.id), before.map(\.id))
        expectEqual(model.config.mappingStore.mappings.filter { $0.trigger.isButtonPress }, before.filter { $0.trigger.isButtonPress })
    }),
    ("drag adapter can add middle-button drag and derive runtime drivers", {
        let model = uiModel(); var row = uiRow(3, .drag(.up)); row.action = .system(.missionControl)
        if case .saved = model.saveMapping(row) {} else { expectTrue(false) }
        expectTrue(model.config.gestureButtons.contains(2)); expectTrue(model.config.verticalEnabled)
        expectEqual(model.config.mappingStore.mappings.first { $0.id == row.id }, row)
    }),
    ("drag adapter editing trigger uses supported fixed action", {
        let model = uiModel(); var row = model.config.mappingStore.mapping(for: .button(4), trigger: .drag(.left))!
        row.input = .button(19); row.trigger = .drag(.down); row.action = .system(.appExpose)
        if case .saved = model.saveMapping(row) {} else { expectTrue(false) }
        expectTrue(model.config.gestureButtons.contains(18))
        expectTrue(model.config.mappingStore.mapping(for: .button(4), trigger: .drag(.left)) == nil)
    }),
    ("drag adapter converting drag into press removes old direction durably", {
        let model = uiModel(); var row = model.config.mappingStore.mapping(for: .button(4), trigger: .drag(.left))!
        row.input = .button(12); row.trigger = .longPress; row.action = .system(.showDesktop)
        _ = model.saveMapping(row)
        expectTrue(model.config.dragMappingsManaged)
        expectTrue(model.config.mappingStore.mapping(for: .button(4), trigger: .drag(.left)) == nil)
        expectEqual(model.config.mappingStore.mapping(for: .button(12), trigger: .longPress), row)
    }),
    ("drag adapter inversion changes action representation but keeps row enablement", {
        let model = uiModel(); let left = model.config.mappingStore.mapping(for: .button(5), trigger: .drag(.left))!
        model.setMappingEnabled(false, id: left.id); model.binding(\.horizontalInvert).wrappedValue = false
        let after = model.config.mappingStore.mappings.first { $0.id == left.id }!
        expectFalse(after.isEnabled); expectEqual(after.action, .system(.nextSpace)); expectEqual(after.id, left.id)
    }),
    ("drag adapter last horizontal removal leaves vertical and press running", {
        let model = uiModel(); _ = model.saveMapping(uiRow(8))
        for row in model.config.mappingStore.mappings where row.trigger == .drag(.left) || row.trigger == .drag(.right) { model.deleteMapping(row.id) }
        expectFalse(model.config.horizontalEnabled); expectTrue(model.config.verticalEnabled); expectTrue(model.config.shouldRun)
        expectEqual(model.config.mappingStore.pressCGButtons, [7])
    }),
    ("drag adapter last driver removal does not re-enable default rows", {
        let model = uiModel()
        for row in model.config.mappingStore.mappings where !row.trigger.isButtonPress { model.deleteMapping(row.id) }
        expectFalse(model.config.horizontalEnabled); expectFalse(model.config.verticalEnabled)
        expectFalse(model.config.shouldRun); expectTrue(model.config.mappingStore.mappings.allSatisfy { $0.trigger.isButtonPress })
    }),
    ("drag adapter persists independently disabled and deleted directions", {
        let model = uiModel(); let left = model.config.mappingStore.mapping(for: .button(4), trigger: .drag(.left))!
        let down = model.config.mappingStore.mapping(for: .button(5), trigger: .drag(.down))!
        model.setMappingEnabled(false, id: left.id); model.deleteMapping(down.id)
        uiDefaults { store, _ in
            store.save(model.config); let loaded = store.load()
            expectEqual(loaded, model.config); expectFalse(loaded.mappingStore.mappings.first { $0.id == left.id }!.isEnabled)
            expectTrue(loaded.mappingStore.mappings.first { $0.id == down.id } == nil)
        }
    }),
    ("drag adapter legacy load does not rewrite preferences or opt in", {
        uiDefaults { store, defaults in
            store.save(.defaults); var values = defaults.dictionary(forKey: ConfigStore.key)!
            values.removeValue(forKey: "dragMappingsManaged"); defaults.set(values, forKey: ConfigStore.key)
            expectFalse(store.load().dragMappingsManaged)
            expectTrue(defaults.dictionary(forKey: ConfigStore.key)!["dragMappingsManaged"] == nil)
        }
    }),
    ("gesture reset preserves mappings deletion and driver state", {
        let model = uiModel(); let left = model.config.mappingStore.mapping(for: .button(4), trigger: .drag(.left))!
        model.deleteMapping(left.id); let before = model.config.mappingStore.mappings
        model.binding(\.sensitivity).wrappedValue = 1200; model.binding(\.deadZone).wrappedValue = 31
        model.resetGestureSettings()
        expectEqual(model.config.mappingStore.mappings, before); expectTrue(model.config.dragMappingsManaged)
        expectEqual(model.config.sensitivity, 600); expectEqual(model.config.deadZone, 8)
    }),
    ("drag delivery unmanaged legacy trace is identical", {
        var gate = LegacyDragDelivery(config: .defaults)
        let frames = [GestureFrame(.began, 0.1), GestureFrame(.changed, -0.2, -3), GestureFrame(.cancelled, 0)]
        expectEqual(gate.filter(frames, vertical: false, direction: .left), frames)
        expectEqual(gate.filter(frames, vertical: true, direction: .down), frames)
    }),
    ("drag delivery release flush preserves eligible last released button", {
        var config = AppConfig(); config.dragMappingsManaged = true
        config.mappings = [MouseMapping(input: .button(8), trigger: .drag(.left), action: .system(.previousSpace))]
        var gate = LegacyDragDelivery(config: config); gate.down(7); gate.begin(); gate.up(7)
        let frames = [GestureFrame(.began, -0.5), GestureFrame(.ended, -0.8, -1)]
        expectEqual(gate.filter(frames, vertical: false, direction: .left), frames)
    }),
    ("drag delivery does not post terminals for a disabled begin", {
        var config = AppConfig(); config.dragMappingsManaged = true; config.mappings = []
        var gate = LegacyDragDelivery(config: config); gate.down(3); gate.begin()
        expectTrue(gate.filter([GestureFrame(.began, 0.2)], vertical: true, direction: .up).isEmpty)
        expectTrue(gate.filter([GestureFrame(.changed, 0.4), GestureFrame(.cancelled, 0.4)], vertical: true, direction: .up).isEmpty)
    }),
    ("drag delivery ignores retired wheel and long owners", {
        var config = AppConfig(); config.dragMappingsManaged = true
        config.mappings = [MouseMapping(input: .button(8), trigger: .drag(.up), action: .system(.missionControl))]
        var gate = LegacyDragDelivery(config: config); gate.down(7); gate.begin(); gate.retire(7)
        expectTrue(gate.filter([GestureFrame(.began, 0.2)], vertical: true, direction: .up).isEmpty)
    }),
    ("drag delivery reset clears quarantined button eligibility", {
        var config = AppConfig(); config.dragMappingsManaged = true
        config.mappings = [MouseMapping(input: .button(8), trigger: .drag(.left), action: .system(.previousSpace))]
        var gate = LegacyDragDelivery(config: config); gate.down(7); gate.begin(); gate.reset(); gate.down(3); gate.begin()
        expectTrue(gate.filter([GestureFrame(.began, -0.2)], vertical: false, direction: .left).isEmpty)
    }),
    ("drag delivery reversal retains the original enabled sequence", {
        var config = AppConfig(); config.dragMappingsManaged = true
        config.mappings = [MouseMapping(input: .button(8), trigger: .drag(.left), action: .system(.previousSpace))]
        var gate = LegacyDragDelivery(config: config); gate.down(7); gate.begin()
        expectEqual(gate.filter([GestureFrame(.began, -0.2)], vertical: false, direction: .left).count, 1)
        let reverse = [GestureFrame(.changed, 0.1, 2), GestureFrame(.cancelled, 0.1)]
        expectEqual(gate.filter(reverse, vertical: false, direction: .right), reverse)
    }),
    ("drag delivery a muted sequence remains muted on reversal", {
        var config = AppConfig(); config.dragMappingsManaged = true
        config.mappings = [MouseMapping(input: .button(8), trigger: .drag(.left), action: .system(.previousSpace))]
        var gate = LegacyDragDelivery(config: config); gate.down(7); gate.begin()
        expectTrue(gate.filter([GestureFrame(.began, 0.2)], vertical: false, direction: .right).isEmpty)
        expectTrue(gate.filter([GestureFrame(.changed, -0.2), GestureFrame(.ended, -0.5)], vertical: false, direction: .left).isEmpty)
    }),
    ("drag delivery concurrent buttons share the original gesture lifetime", {
        var config = AppConfig(); config.dragMappingsManaged = true
        config.mappings = [MouseMapping(input: .button(8), trigger: .drag(.down), action: .system(.appExpose))]
        var gate = LegacyDragDelivery(config: config); gate.down(3); gate.begin(); gate.down(7); gate.up(7)
        let frame = [GestureFrame(.began, -0.3)]
        expectEqual(gate.filter(frame, vertical: true, direction: .down), frame)
        gate.up(3); gate.end(); gate.down(3); gate.begin()
        expectTrue(gate.filter(frame, vertical: true, direction: .down).isEmpty)
    })
] + MouseDragDirection.allCases.map { direction in
    ("drag independent toggle \(direction.rawValue)", {
        let model = uiModel(); let before = model.config.mappingStore.mappings
        let row = before.first { $0.input == .button(4) && $0.trigger == .drag(direction) }!
        model.setMappingEnabled(false, id: row.id)
        expectEqual(model.config.mappingStore.mappings.filter { $0.id != row.id }, before.filter { $0.id != row.id })
        expectFalse(model.config.mappingStore.mappings.first { $0.id == row.id }!.isEnabled)
        model.setMappingEnabled(true, id: row.id); expectEqual(model.config.mappingStore.mappings, before)
    })
} + MouseDragDirection.allCases.map { direction in
    ("drag independent delete \(direction.rawValue)", {
        let model = uiModel(); let before = model.config.mappingStore.mappings
        let row = before.first { $0.input == .button(5) && $0.trigger == .drag(direction) }!
        model.deleteMapping(row.id)
        expectEqual(model.config.mappingStore.mappings, before.filter { $0.id != row.id })
        expectTrue(model.config.mappingStore.mapping(for: row.input, trigger: row.trigger) == nil)
    })
} + MouseDragDirection.allCases.map { direction in
    ("drag delivery matches only enabled button and direction \(direction.rawValue)", {
        var config = AppConfig(); config.dragMappingsManaged = true
        config.mappings = [MouseMapping(input: .button(8), trigger: .drag(direction), action: LegacyDragSettingsAdapter.action(for: direction, inverted: true))]
        for button in [3, 7] {
            for candidate in MouseDragDirection.allCases {
                var gate = LegacyDragDelivery(config: config); gate.down(button); gate.begin()
                let frames = [GestureFrame(.began, 0.2), GestureFrame(.changed, 0.4, 1), GestureFrame(.ended, 0.8, 1)]
                expectEqual(gate.filter(frames, vertical: candidate == .up || candidate == .down, direction: candidate),
                            button == 7 && candidate == direction ? frames : [])
            }
        }
    })
}

let uiDragTraceChecks: [(String, () throws -> Void)] = MouseDragDirection.allCases.map { direction in
    ("drag delivery preserves real core trace and release flush \(direction.rawValue)", {
        var config = AppConfig(); config.dragMappingsManaged = true
        config.mappings = [MouseMapping(input: .button(8), trigger: .drag(direction), action: LegacyDragSettingsAdapter.action(for: direction, inverted: true))]
        var machine = GestureMachine(config: config.gestureConfig)
        var vertical = VerticalGestureTracker()
        let isVertical = direction == .up || direction == .down
        var trace: [GestureFrame] = []
        machine.down(at: 0); vertical.down(at: 0)
        machine.move(dx: direction == .left ? -420 : direction == .right ? 420 : 0,
                     dy: direction == .up ? -240 : direction == .down ? 240 : 0, at: 0.1)
        if isVertical {
            _ = machine.frame(at: 0.1); vertical.move(totalY: machine.totalY, at: 0.1)
            trace = vertical.finish(verticalLocked: true, at: 0.12)
        } else { trace = machine.finish(at: 0.12) }
        expectEqual(trace.first?.phase, .began); expectEqual(trace.last?.phase, .ended)
        for button in [3, 7] {
            var gate = LegacyDragDelivery(config: config); gate.down(button); gate.begin(); gate.up(button)
            let delivered = gate.filter(trace, vertical: isVertical, direction: direction)
            expectEqual(delivered, button == 7 ? trace : [])
            var counters = GestureCounters()
            for frame in delivered { counters.record(frame) }
            expectEqual(counters.openGestures, 0); expectEqual(counters.gestureBegins, button == 7 ? 1 : 0)
        }
    })
}
