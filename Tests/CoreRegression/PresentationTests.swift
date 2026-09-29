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

    func testSideButtonsCannotBecomeEmpty() {
        let both = AppConfig.defaults
        let firstOnly = GestureSettings.changingButton(both, number: 4, selected: false)
        expectEqual(firstOnly?.gestureButtons, Set([3]))
        expectTrue(GestureSettings.changingButton(firstOnly!, number: 3, selected: false) == nil)
        expectEqual(GestureSettings.changingButton(firstOnly!, number: 4, selected: true)?.gestureButtons,
                    Set([3, 4]))
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
        model.buttonBinding(3).wrappedValue = false
        expectEqual(store.load().gestureButtons, Set([4]))
        model.buttonBinding(4).wrappedValue = false
        expectEqual(store.load().gestureButtons, Set([4]))
        model.binding(\.horizontalInvert).wrappedValue = false
        expectFalse(ConfigStore(defaults: defaults).load().horizontalInvert)
        model.binding(\.verticalEnabled).wrappedValue = false
        expectFalse(ConfigStore(defaults: defaults).load().verticalEnabled)
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
        expectEqual(restored.gestureButtons, Set([3, 4]))
        expectTrue(restored.horizontalEnabled)
        expectTrue(restored.verticalEnabled)
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
