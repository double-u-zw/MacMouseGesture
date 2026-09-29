import Foundation

enum UserStatus: String {
    case running = "运行中"
    case disabled = "已停用"
    case permissionRequired = "需要授权"
    case recovering = "正在恢复"
    case error = "手势引擎异常"

    static func resolve(config: AppConfig, accessibility: Bool, pendingStart: Bool, engineStatus: String) -> Self {
        guard config.shouldRun else { return .disabled }
        guard accessibility else { return .permissionRequired }
        if engineStatus.hasPrefix("Running:") { return .running }
        if pendingStart || engineStatus == "Stopped" { return .recovering }
        return .error
    }
}

enum LoginItemState: Equatable {
    case off, on, requiresApproval, unavailable

    var isSelected: Bool { self == .on || self == .requiresApproval }
    var label: String {
        switch self {
        case .off: "已关闭"
        case .on: "已开启"
        case .requiresApproval: "请在系统设置中批准登录项"
        case .unavailable: "不可用"
        }
    }
}

enum GestureSettings {
    static func restoringDefaults(_ config: AppConfig) -> AppConfig {
        var next = config
        let defaults = AppConfig.defaults
        next.gestureButtons = defaults.gestureButtons
        next.horizontalEnabled = defaults.horizontalEnabled
        next.verticalEnabled = defaults.verticalEnabled
        next.horizontalInvert = defaults.horizontalInvert
        next.sensitivity = defaults.sensitivity
        next.deadZone = defaults.deadZone
        next.freezePointer = defaults.freezePointer
        return next
    }
    static func changingButton(_ config: AppConfig, number: Int, selected: Bool) -> AppConfig? {
        guard number == 3 || number == 4 else { return nil }
        var next = config
        if selected { next.gestureButtons.insert(number) } else { next.gestureButtons.remove(number) }
        return next.gestureButtons.isEmpty ? nil : next
    }

    // Logarithmic mapping keeps the confirmed 600 setting near the middle and
    // preserves every existing stored sensitivity value in the 100...5000 range.
    static func sensitivityPosition(for value: Double) -> Double {
        log(5000 / min(5000, max(100, value))) / log(50)
    }
    static func sensitivityValue(at position: Double) -> Double {
        (5000 * pow(1.0 / 50.0, min(1, max(0, position)))).rounded()
    }
}
