import SwiftUI

enum SettingsTab: Hashable { case general, diagnostics, about }

final class AppViewModel: ObservableObject {
    @Published private(set) var config: AppConfig
    @Published var selectedTab: SettingsTab = .general
    @Published var status: UserStatus = .recovering
    @Published var accessibilityGranted = false
    @Published var inputMonitoringGranted = false
    @Published var loginState: LoginItemState = .off
    @Published var snapshot = EngineUISnapshot()
    @Published var advancedReport = ""
    @Published var message: String?

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

    init(config: AppConfig = .defaults) { self.config = config }

    func show(_ config: AppConfig) { self.config = config }

    func resetGestureSettings() {
        applyConfig?(GestureSettings.restoringDefaults(config), false)
    }

    func binding<Value>(_ keyPath: WritableKeyPath<AppConfig, Value>, debounce: Bool = false) -> Binding<Value> {
        Binding(get: { self.config[keyPath: keyPath] }, set: { value in
            var next = self.config
            next[keyPath: keyPath] = value
            self.applyConfig?(next, debounce)
        })
    }

    func buttonBinding(_ number: Int) -> Binding<Bool> {
        Binding(get: { self.config.gestureButtons.contains(number) }, set: { selected in
            guard let next = GestureSettings.changingButton(self.config, number: number, selected: selected) else { return }
            self.applyConfig?(next, false)
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
}
