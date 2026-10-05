import Foundation

struct PresentationTests {
    func testStatusUsesExistingEngineAndPermissionState() {
        let c = AppConfig.defaults
        expectEqual(UserStatus.resolve(config: c, accessibility: true, pendingStart: false,
                                       engineStatus: "Running: Horizontal gesture POC"), .running)
        expectEqual(UserStatus.resolve(config: c, accessibility: false, pendingStart: true,
                                       engineStatus: "Stopped"), .permissionRequired)
        expectEqual(UserStatus.resolve(config: c, accessibility: true, pendingStart: true,
                                       engineStatus: "Stopped"), .recovering)
        expectEqual(UserStatus.resolve(config: c, accessibility: true, pendingStart: false,
                                       engineStatus: "Stopped: backend failure"), .error)
        var disabled = c
        disabled.enabled = false
        expectEqual(UserStatus.resolve(config: disabled, accessibility: false, pendingStart: false,
                                       engineStatus: "Stopped"), .disabled)
    }

    func testDragMappingToggleDoesNotDisablePhysicalButton() {
        let model = AppViewModel()
        model.applyConfig = { [weak model] next, _ in model?.show(next.validated()) }
        let before = model.config.mappingStore.mappings
        let row = before.first { $0.input == .button(4) && $0.trigger == .drag(.left) }!
        model.setMappingEnabled(false, id: row.id)
        expectFalse(model.config.mappingStore.mappings.first { $0.id == row.id }!.isEnabled)
        expectEqual(model.config.mappingStore.mappings.filter { $0.id != row.id }, before.filter { $0.id != row.id })
        expectTrue(model.config.gestureButtons.contains(3))
    }

    func testSliderPositionsRoundTripExistingDefaults() {
        let position = GestureSettings.sensitivityPosition(for: AppConfig.defaults.sensitivity)
        expectTrue(position > 0.45 && position < 0.65)
        expectEqual(GestureSettings.sensitivityValue(at: position), 600)
        for value in [100.0, 300.0, 1200.0, 5000.0] {
            expectEqual(GestureSettings.sensitivityValue(at: GestureSettings.sensitivityPosition(for: value)),
                        value, accuracy: 1)
        }
    }

    func testSettingsBindingUsesExistingConfigStore() {
        let name = "local.macmousegesture.presentation-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = ConfigStore(defaults: defaults)
        let model = AppViewModel(config: store.load())
        model.applyConfig = { [weak model] next, _ in store.save(next); model?.show(next) }
        model.binding(\.enabled).wrappedValue = false
        expectFalse(store.load().enabled)
        let row = model.config.mappingStore.mapping(for: .button(4), trigger: .drag(.left))!
        model.setMappingEnabled(false, id: row.id)
        expectFalse(store.load().mappingStore.mappings.first { $0.id == row.id }!.isEnabled)
        expectTrue(store.load().mappingStore.mapping(for: .button(4), trigger: .drag(.right))!.isEnabled)
        model.binding(\.horizontalInvert).wrappedValue = false
        expectFalse(ConfigStore(defaults: defaults).load().horizontalInvert)
        model.binding(\.freezePointer).wrappedValue = false
        expectFalse(ConfigStore(defaults: defaults).load().freezePointer)
    }

    func testLoginStateDoesNotMistakeApprovalForOff() {
        expectFalse(LoginItemState.off.isSelected)
        expectTrue(LoginItemState.on.isSelected)
        expectTrue(LoginItemState.requiresApproval.isSelected)
        expectFalse(LoginItemState.unavailable.isSelected)
    }

    func testResetRestoresOnlyGestureSettings() {
        var changed = AppConfig.defaults
        changed.enabled = false
        changed.gestureButtons = [4]
        changed.horizontalEnabled = false
        changed.verticalEnabled = false
        changed.horizontalInvert = false
        changed.sensitivity = 1100
        changed.deadZone = 23
        changed.freezePointer = false
        let restored = GestureSettings.restoringDefaults(changed)
        expectFalse(restored.enabled)
        expectEqual(restored.gestureButtons, changed.gestureButtons)
        expectFalse(restored.horizontalEnabled)
        expectFalse(restored.verticalEnabled)
        expectTrue(restored.horizontalInvert)
        expectEqual(restored.sensitivity, 600)
        expectEqual(restored.deadZone, 8)
        expectTrue(restored.freezePointer)
    }

    func testUserStatusLabelsAreChinese() {
        expectEqual(UserStatus.running.rawValue, "运行中")
        expectEqual(UserStatus.disabled.rawValue, "已停用")
        expectEqual(UserStatus.permissionRequired.rawValue, "需要授权")
        expectEqual(UserStatus.recovering.rawValue, "正在恢复")
        expectEqual(UserStatus.error.rawValue, "手势引擎异常")
    }
}
