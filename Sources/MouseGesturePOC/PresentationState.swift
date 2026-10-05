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
        next.horizontalInvert = defaults.horizontalInvert
        next.sensitivity = defaults.sensitivity
        next.deadZone = defaults.deadZone
        next.freezePointer = defaults.freezePointer
        return next
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

// User-facing wording only; engine state resolution remains unchanged.
extension UserStatus {
    var displayLabel: String {
        switch self {
        case .running: "正在运行"
        case .disabled: "已停用"
        case .permissionRequired: "需要开启权限"
        case .recovering: "正在连接鼠标"
        case .error: "系统手势暂时不可用"
        }
    }
    var guidance: String? {
        switch self {
        case .running, .disabled: nil
        case .permissionRequired: "请开启辅助功能权限。"
        case .recovering: "请确认鼠标已连接。"
        case .error: "请重新尝试；若仍无法使用，可在帮助页查看诊断。"
        }
    }
}

enum UserMessage {
    static func display(_ message: String?) -> String? {
        guard let message else { return nil }
        if message.hasPrefix("无法更改登录启动设置") { return "无法更改登录启动，请在帮助页查看诊断。" }
        if message.hasPrefix("无法保存诊断快照") { return "无法导出诊断信息，请选择其他保存位置。" }
        if message.hasPrefix("鼠标连接频繁变化") { return "鼠标连接不稳定。连接恢复后，请点击“重新尝试”。" }
        return message
    }
}
