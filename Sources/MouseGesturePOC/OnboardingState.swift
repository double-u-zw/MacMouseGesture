import Foundation

struct OnboardingState {
    enum Step { case welcome, permissions, test, complete }
    var step: Step = .welcome
    var testStartedAt: Double?
    var buttonBaseline = 0
    var detectedSideButton = false
    var confirmedGesture = false
    static let completedKey = "onboardingCompleted"
    static func needsWelcome(_ defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: completedKey)
    }
    mutating func beginTest(at time: Double, buttons: Int) {
        step = .test; testStartedAt = time; buttonBaseline = buttons
        detectedSideButton = false; confirmedGesture = false
    }
    mutating func observe(buttons: Int) {
        if step == .test && buttons > buttonBaseline { detectedSideButton = true }
    }
    func waitingHint(at time: Double) -> Bool {
        step == .test && !detectedSideButton && time - (testStartedAt ?? time) >= 12
    }
    func canComplete(accessibility: Bool, running: Bool) -> Bool {
        accessibility && running && detectedSideButton && confirmedGesture
    }
    func persistCompletion(_ defaults: UserDefaults = .standard) {
        guard step == .complete else { return }
        defaults.set(true, forKey: Self.completedKey)
    }
}

enum PermissionPresentation {
    static func accessibility(_ granted: Bool, completed: Bool) -> String {
        granted ? "已授权" : (completed ? "需要重新授权" : "未授权")
    }
    static func inputMonitoring(_ granted: Bool) -> String { granted ? "已授权" : "未授权（可选）" }
}
