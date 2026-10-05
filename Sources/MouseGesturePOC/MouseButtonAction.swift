import Foundation
import CoreFoundation
import CoreGraphics

struct KeyboardShortcut: Equatable {
    static let modifierMask = CGEventFlags.maskCommand.rawValue | CGEventFlags.maskAlternate.rawValue |
        CGEventFlags.maskControl.rawValue | CGEventFlags.maskShift.rawValue
    let keyCode: UInt16
    let modifierFlags: UInt64
    init?(keyCode: UInt16, modifierFlags: UInt64) {
        guard keyCode <= 127, ![54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(keyCode) else { return nil }
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags & Self.modifierMask
    }
}

enum MouseButtonAction: String, CaseIterable {
    case none, showDesktop, missionControl, appExpose, launchpad, minimizeWindow, toggleFullScreen
    case lockScreen, openFinder, newFolder, playPause, back, forward, customShortcut
    var title: String {
        switch self {
        case .none: return "无操作"
        case .showDesktop: return "显示桌面"
        case .missionControl: return "调度中心"
        case .appExpose: return "应用 Exposé"
        case .launchpad: return "启动台"
        case .minimizeWindow: return "最小化窗口"
        case .toggleFullScreen: return "全屏 / 退出全屏"
        case .lockScreen: return "锁定屏幕"
        case .openFinder: return "打开访达"
        case .newFolder: return "新建文件夹"
        case .playPause: return "播放 / 暂停"
        case .back: return "返回"
        case .forward: return "前进"
        case .customShortcut: return "自定义键盘快捷键…"
        }
    }
    var group: String {
        switch self {
        case .none: return ""
        case .showDesktop, .missionControl, .appExpose, .launchpad, .lockScreen: return "系统"
        case .minimizeWindow, .toggleFullScreen: return "窗口"
        case .openFinder, .newFolder: return "访达"
        case .back, .forward: return "导航"
        case .playPause: return "媒体"
        case .customShortcut: return "自定义"
        }
    }
}

struct ButtonClickConfiguration: Equatable {
    var action: MouseButtonAction = .none
    var shortcut: KeyboardShortcut?
    var values: [String: Any] {
        var result: [String: Any] = ["action": action.rawValue]
        if let shortcut {
            result["keyCode"] = Int(shortcut.keyCode)
            result["modifierFlags"] = shortcut.modifierFlags
        }
        return result
    }
    init(action: MouseButtonAction = .none, shortcut: KeyboardShortcut? = nil) {
        self.action = action; self.shortcut = shortcut
    }
    init(values: Any?) {
        self.init()
        guard let values = values as? [String: Any], let raw = values["action"] as? String,
              let action = MouseButtonAction(rawValue: raw) else { return }
        self.action = action
        if let key = values["keyCode"] as? NSNumber, CFGetTypeID(key) != CFBooleanGetTypeID(),
           key.doubleValue.isFinite, (0...127).contains(key.doubleValue), key.doubleValue.rounded() == key.doubleValue,
           let flags = values["modifierFlags"] as? NSNumber, CFGetTypeID(flags) != CFBooleanGetTypeID(),
           flags.doubleValue.isFinite, flags.doubleValue >= 0, flags.doubleValue <= Double(KeyboardShortcut.modifierMask),
           flags.doubleValue.rounded() == flags.doubleValue {
            shortcut = KeyboardShortcut(keyCode: key.uint16Value, modifierFlags: flags.uint64Value)
        }
        if action == .customShortcut && shortcut == nil { self.action = .none }
    }
}
