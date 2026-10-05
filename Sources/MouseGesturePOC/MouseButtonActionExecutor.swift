import AppKit
import GestureCore

struct SystemKeyBinding: Equatable {
    let keyCode: UInt16
    let modifierFlags: UInt64
}

// Navigation/window shortcuts are isolated here so their backend can be replaced.
final class MouseButtonActionExecutor {
    private let verticalAvailable: () -> Bool
    private let postVertical: (GestureFrame) -> Bool
    private let postKeyboard: (UInt16, CGEventFlags) -> Bool
    private let systemHotKeys: () -> [String: Any]
    private let postMedia: () -> Bool
    private let diagnostic: (String) -> Void
    private let backMouse: BackMouseAction
    private let fullScreenWindow: FullScreenWindowAction
    private let minimizeWindow: MinimizeWindowAction
    private let appExpose: AppExposeAction
    private let missionControl: MissionControlAction
    private let finder: FinderAction
    init(verticalAvailable: @escaping () -> Bool, postVertical: @escaping (GestureFrame) -> Bool,
         postKeyboard: @escaping (UInt16, CGEventFlags) -> Bool = MouseButtonActionExecutor.keyboard,
         postMedia: @escaping () -> Bool = MouseButtonActionExecutor.media,
         systemHotKeys: @escaping () -> [String: Any] = {
             UserDefaults.standard.persistentDomain(forName: "com.apple.symbolichotkeys")?["AppleSymbolicHotKeys"] as? [String: Any] ?? [:]
         }, diagnostic: @escaping (String) -> Void = { _ in },
         missionControl: MissionControlAction? = nil, appExpose: AppExposeAction? = nil, minimizeWindow: MinimizeWindowAction? = nil, fullScreenWindow: FullScreenWindowAction? = nil, backMouse: BackMouseAction? = nil, finder: FinderAction? = nil, gestureQueue: DispatchQueue? = nil) {
        self.verticalAvailable = verticalAvailable; self.postVertical = postVertical
        self.postKeyboard = postKeyboard; self.postMedia = postMedia; self.systemHotKeys = systemHotKeys
        self.diagnostic = diagnostic
        self.backMouse = backMouse ?? BackMouseAction(diagnostic: diagnostic)
        self.finder = finder ?? FinderAction(diagnostic: diagnostic)
        self.fullScreenWindow = fullScreenWindow ?? FullScreenWindowAction(diagnostic: diagnostic)
        self.minimizeWindow = minimizeWindow ?? MinimizeWindowAction(diagnostic: diagnostic)
        self.appExpose = appExpose ?? AppExposeAction(
            queue: gestureQueue ?? DispatchQueue(label: "MouseGesture.AppExposeAction", qos: .userInteractive),
            verticalAvailable: verticalAvailable, postVertical: postVertical, diagnostic: diagnostic)
        self.missionControl = missionControl ?? MissionControlAction(
            queue: gestureQueue ?? DispatchQueue(label: "MouseGesture.ShortClickActions", qos: .userInteractive),
            verticalAvailable: verticalAvailable, postVertical: postVertical, diagnostic: diagnostic)
    }
    func cancelAppExpose(reason: String) { appExpose.cancel(reason: reason) }
    func cancelMissionControl(reason: String) { missionControl.cancel(reason: reason) }
    func execute(_ action: MouseAction, button: Int? = nil) -> Bool {
        guard let legacy = action.legacyConfiguration else {
            diagnostic("[Mapping] result=unsupported reason=drag-action-not-dispatched-as-short-press")
            return false
        }
        return execute(legacy, button: button)
    }
    func execute(_ configuration: ButtonClickConfiguration, button: Int? = nil) -> Bool {
        switch configuration.action {
        case .none: return true
        case .missionControl:
            appExpose.cancel(reason: "Mission Control short-click takes priority")
            return missionControl.start(button: button) == .success
        case .appExpose:
            missionControl.cancel(reason: "App Exposé short-click takes priority")
            return appExpose.start(button: button) == .success
        case .showDesktop, .launchpad:
            guard let shortcut = Self.systemShortcut(configuration.action, values: systemHotKeys()) else {
                diagnostic("Short-click system action=\(configuration.action.rawValue) binding unavailable")
                return false
            }
            let posted = postKeyboard(shortcut.keyCode, CGEventFlags(rawValue: shortcut.modifierFlags))
            diagnostic("Short-click system action=\(configuration.action.rawValue) keyCode=\(shortcut.keyCode) flags=\(shortcut.modifierFlags) submitted=\(posted)")
            return posted
        case .minimizeWindow: return minimizeWindow.execute(button: button) == .success
        case .toggleFullScreen: return fullScreenWindow.execute(button: button) == .success
        case .lockScreen: return postKeyboard(12, [.maskCommand, .maskControl])
        case .openFinder: return finder.open(button: button)
        case .newFolder: return finder.newFolder(button: button) == .success
        case .back: return backMouse.execute(button: button) == .success
        case .forward: return postKeyboard(30, .maskCommand)
        case .customShortcut:
            guard let shortcut = configuration.shortcut else { return true }
            return postKeyboard(shortcut.keyCode, CGEventFlags(rawValue: shortcut.modifierFlags))
        case .playPause: return postMedia()
        }
    }
    // Read existing bindings without changing the user's system preferences.
    // Missing values use the conventional F11/F4 mapping; disabled/malformed
    // bindings fail safely and can be replaced using a custom shortcut.
    static func systemShortcut(_ action: MouseButtonAction, values: [String: Any]) -> SystemKeyBinding? {
        let identifier = action == .showDesktop ? "36" : "160"
        guard let raw = values[identifier] else {
            // macOS's default Show Desktop F11 binding includes the function-key
            // flag even when no override is stored in AppleSymbolicHotKeys.
            return SystemKeyBinding(keyCode: action == .showDesktop ? 103 : 118,
                                    modifierFlags: action == .showDesktop ? CGEventFlags.maskSecondaryFn.rawValue : 0)
        }
        guard let entry = raw as? [String: Any] else { return nil }
        if let enabled = entry["enabled"] as? Bool, !enabled { return nil }
        guard let value = entry["value"] as? [String: Any], value["type"] as? String == "standard",
              let parameters = value["parameters"] as? [NSNumber], parameters.count == 3,
              parameters.allSatisfy({ CFGetTypeID($0) != CFBooleanGetTypeID() && $0.doubleValue.isFinite &&
                  $0.doubleValue >= 0 && $0.doubleValue <= Double(UInt32.max) && $0.doubleValue.rounded() == $0.doubleValue }),
              parameters[1].uint64Value <= 127 else { return nil }
        return SystemKeyBinding(keyCode: parameters[1].uint16Value, modifierFlags: parameters[2].uint64Value)
    }
    static func media() -> Bool {
        // NX_KEYTYPE_PLAY = 16; post one paired system-defined media key.
        guard let down = NSEvent.otherEvent(with: .systemDefined, location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xa00), timestamp: 0,
            windowNumber: 0, context: nil, subtype: 8, data1: (16 << 16) | 0xa00, data2: -1)?.cgEvent,
            let up = NSEvent.otherEvent(with: .systemDefined, location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xb00), timestamp: 0,
            windowNumber: 0, context: nil, subtype: 8, data1: (16 << 16) | 0xb00, data2: -1)?.cgEvent else { return false }
        down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap); return true
    }
    static func keyboard(_ code: UInt16, _ flags: CGEventFlags) -> Bool {
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) else { return false }
        down.flags = flags; up.flags = flags
        down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap)
        return true
    }
}
