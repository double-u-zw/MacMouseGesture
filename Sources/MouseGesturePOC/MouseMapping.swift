import Foundation

// User-visible button numbers are one-based; CGEvent numbers are zero-based.
enum MouseInput: Hashable, Codable {
    case button(Int)
    var number: Int { switch self { case .button(let n): n } }
    var cgNumber: Int { MouseButtonIdentifier(number: number)?.rawValue ?? -1 }
    var isSupported: Bool { MouseButtonIdentifier(number: number)?.canRemap == true }
    var title: String { MouseButtonIdentifier(number: number)?.title ?? "鼠标按钮 \(number)" }
    private enum Keys: String, CodingKey { case kind, number }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        guard try c.decode(String.self, forKey: .kind) == "button" else {
            throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "Unknown input")
        }
        self = .button(try c.decode(Int.self, forKey: .number))
        guard isSupported else { throw DecodingError.dataCorruptedError(forKey: .number, in: c, debugDescription: "Expected extra button 3...32") }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode("button", forKey: .kind); try c.encode(number, forKey: .number)
    }
}

enum MouseDragDirection: String, Codable, CaseIterable { case left, right, up, down }
enum MouseWheelDirection: String, Codable, CaseIterable { case up, down }
enum MouseTrigger: Hashable, Codable {
    case shortPress
    case modifiedShortPress(MouseModifiers)
    case longPress
    case modifiedLongPress(MouseModifiers)
    case wheelUp
    case wheelDown
    case modifiedWheel(MouseWheelDirection, MouseModifiers)
    case drag(MouseDragDirection)
    static func wheel(_ direction: MouseWheelDirection, modifiers: MouseModifiers = []) -> Self {
        modifiers.isEmpty ? (direction == .up ? .wheelUp : .wheelDown) : .modifiedWheel(direction, modifiers)
    }
    static func shortPress(modifiers: MouseModifiers) -> Self {
        modifiers.isEmpty ? .shortPress : .modifiedShortPress(modifiers)
    }
    static func longPress(modifiers: MouseModifiers) -> Self {
        modifiers.isEmpty ? .longPress : .modifiedLongPress(modifiers)
    }
    func withModifiers(_ flags: MouseModifiers) -> Self {
        if isShortPress { return .shortPress(modifiers: flags) }
        if isLongPress { return .longPress(modifiers: flags) }
        if let direction = wheelDirection { return .wheel(direction, modifiers: flags) }
        return self
    }
    var modifiers: MouseModifiers {
        switch self {
        case .modifiedShortPress(let flags), .modifiedLongPress(let flags), .modifiedWheel(_, let flags): return flags
        default: return []
        }
    }
    var base: Self { isShortPress ? .shortPress : isLongPress ? .longPress : wheelDirection.map { .wheel($0) } ?? self }
    var wheelDirection: MouseWheelDirection? {
        switch self { case .wheelUp: .up; case .wheelDown: .down; case .modifiedWheel(let direction, _): direction; default: nil }
    }
    var isWheel: Bool { wheelDirection != nil }
    var isLongPress: Bool {
        switch self { case .longPress, .modifiedLongPress: true; default: false }
    }
    // All editable triggers require a held/pressed MouseInput, including wheel chords.
    var isButtonPress: Bool { isShortPress || isLongPress || isWheel }
    var isShortPress: Bool {
        switch self { case .shortPress, .modifiedShortPress: true; default: false }
    }
    var title: String {
        switch self {
        case .shortPress, .modifiedShortPress: "短按"
        case .longPress, .modifiedLongPress: "长按"
        case .wheelUp, .modifiedWheel(.up, _): "按住并向上滚动"
        case .wheelDown, .modifiedWheel(.down, _): "按住并向下滚动"
        case .drag(.left): "向左拖动"
        case .drag(.right): "向右拖动"
        case .drag(.up): "向上拖动"
        case .drag(.down): "向下拖动"
        }
    }
    var order: Int {
        switch self { case .shortPress, .modifiedShortPress: 0; case .drag(.left): 1; case .drag(.right): 2; case .drag(.up): 3; case .drag(.down): 4; case .longPress, .modifiedLongPress: 5; case .wheelUp, .modifiedWheel(.up, _): 6; case .wheelDown, .modifiedWheel(.down, _): 7 }
    }
    // Keep legacy order/UUIDs fixed while displaying long press beside short press.
    var displayOrder: Int { isShortPress ? 0 : isLongPress ? 1 : isWheel ? (wheelDirection == .up ? 2 : 3) : order + 3 }
    private enum Keys: String, CodingKey { case kind, direction, modifiers }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        switch try c.decode(String.self, forKey: .kind) {
        case "shortPress": self = .shortPress(modifiers: try c.decodeIfPresent(MouseModifiers.self, forKey: .modifiers) ?? [])
        case "longPress": self = .longPress(modifiers: try c.decodeIfPresent(MouseModifiers.self, forKey: .modifiers) ?? [])
        case "wheel": self = .wheel(try c.decode(MouseWheelDirection.self, forKey: .direction), modifiers: try c.decodeIfPresent(MouseModifiers.self, forKey: .modifiers) ?? [])
        case "drag":
            guard try c.decodeIfPresent(MouseModifiers.self, forKey: .modifiers) ?? [] == [] else {
                throw DecodingError.dataCorruptedError(forKey: .modifiers, in: c, debugDescription: "Modified drag is not supported")
            }
            self = .drag(try c.decode(MouseDragDirection.self, forKey: .direction))
        default: throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "Unknown trigger")
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .shortPress: try c.encode("shortPress", forKey: .kind)
        case .modifiedShortPress(let flags):
            try c.encode("shortPress", forKey: .kind); try c.encode(flags, forKey: .modifiers)
        case .longPress: try c.encode("longPress", forKey: .kind)
        case .modifiedLongPress(let flags):
            try c.encode("longPress", forKey: .kind); try c.encode(flags, forKey: .modifiers)
        case .wheelUp, .wheelDown, .modifiedWheel:
            try c.encode("wheel", forKey: .kind); try c.encode(wheelDirection!, forKey: .direction)
            if !modifiers.isEmpty { try c.encode(modifiers, forKey: .modifiers) }
        case .drag(let direction): try c.encode("drag", forKey: .kind); try c.encode(direction, forKey: .direction)
        }
    }
}

enum SystemAction: String, Codable { case showDesktop, missionControl, appExpose, launchpad, lockScreen, openFinder, newFolder, previousSpace, nextSpace }
enum WindowAction: String, Codable { case minimize, toggleFullscreen }
enum NavigationAction: String, Codable { case back, forward }
enum MediaAction: String, Codable { case playPause }

enum MouseAction: Equatable, Codable {
    case none, system(SystemAction), window(WindowAction), navigation(NavigationAction), media(MediaAction)
    case keyboardShortcut(KeyboardShortcut)
    private enum Keys: String, CodingKey { case kind, value, shortcut }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        // Unknown action kinds/values degrade to none, without discarding the row.
        switch try c.decode(String.self, forKey: .kind) {
        case "none": self = .none
        case "system": self = (try? c.decode(SystemAction.self, forKey: .value)).map(Self.system) ?? .none
        case "window": self = (try? c.decode(WindowAction.self, forKey: .value)).map(Self.window) ?? .none
        case "navigation": self = (try? c.decode(NavigationAction.self, forKey: .value)).map(Self.navigation) ?? .none
        case "media": self = (try? c.decode(MediaAction.self, forKey: .value)).map(Self.media) ?? .none
        case "keyboardShortcut": self = (try? c.decode(KeyboardShortcut.self, forKey: .shortcut)).map(Self.keyboardShortcut) ?? .none
        default: self = .none
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .none: try c.encode("none", forKey: .kind)
        case .system(let a): try c.encode("system", forKey: .kind); try c.encode(a, forKey: .value)
        case .window(let a): try c.encode("window", forKey: .kind); try c.encode(a, forKey: .value)
        case .navigation(let a): try c.encode("navigation", forKey: .kind); try c.encode(a, forKey: .value)
        case .media(let a): try c.encode("media", forKey: .kind); try c.encode(a, forKey: .value)
        case .keyboardShortcut(let a): try c.encode("keyboardShortcut", forKey: .kind); try c.encode(a, forKey: .shortcut)
        }
    }
    init(legacy: ButtonClickConfiguration) {
        switch legacy.action {
        case .none: self = .none
        case .showDesktop: self = .system(.showDesktop)
        case .missionControl: self = .system(.missionControl)
        case .appExpose: self = .system(.appExpose)
        case .launchpad: self = .system(.launchpad)
        case .lockScreen: self = .system(.lockScreen)
        case .openFinder: self = .system(.openFinder)
        case .newFolder: self = .system(.newFolder)
        case .minimizeWindow: self = .window(.minimize)
        case .toggleFullScreen: self = .window(.toggleFullscreen)
        case .back: self = .navigation(.back)
        case .forward: self = .navigation(.forward)
        case .playPause: self = .media(.playPause)
        case .customShortcut: self = legacy.shortcut.map(Self.keyboardShortcut) ?? .none
        }
    }
    var legacyConfiguration: ButtonClickConfiguration? {
        let a: MouseButtonAction
        switch self {
        case .none: a = .none
        case .system(.showDesktop): a = .showDesktop
        case .system(.missionControl): a = .missionControl
        case .system(.appExpose): a = .appExpose
        case .system(.launchpad): a = .launchpad
        case .system(.lockScreen): a = .lockScreen
        case .system(.openFinder): a = .openFinder
        case .system(.newFolder): a = .newFolder
        case .system(.previousSpace), .system(.nextSpace): return nil
        case .window(.minimize): a = .minimizeWindow
        case .window(.toggleFullscreen): a = .toggleFullScreen
        case .navigation(.back): a = .back
        case .navigation(.forward): a = .forward
        case .media(.playPause): a = .playPause
        case .keyboardShortcut(let shortcut): return ButtonClickConfiguration(action: .customShortcut, shortcut: shortcut)
        }
        return ButtonClickConfiguration(action: a)
    }
    var title: String {
        switch self {
        case .system(.previousSpace): "上一个桌面"
        case .system(.nextSpace): "下一个桌面"
        case .system(.launchpad): "应用浏览（旧配置，未支持）"
        case .keyboardShortcut: "自定义快捷键"
        default: legacyConfiguration?.action.title ?? "无操作"
        }
    }
    // Capability policy, not an assertion that all keyboard shortcuts were accepted on hardware.
    var isStandardChoice: Bool {
        switch self { case .none, .system(.showDesktop), .keyboardShortcut: true; default: false }
    }
    var acceptanceNote: String? {
        switch self {
        case .navigation(.back): "兼容性受限：Chrome 已验证，Finder 未通过"
        case .system(.missionControl), .system(.appExpose), .window: "已迁入：专项验收通过，暂不列入常规选项"
        case .keyboardShortcut: "基础实现；完整真机验收待完成"
        case .none, .system(.showDesktop), .system(.previousSpace), .system(.nextSpace): nil
        default: "实验性：尚未完成真机验收"
        }
    }
}

struct MouseMapping: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var input: MouseInput
    var trigger: MouseTrigger
    var action: MouseAction
    var isEnabled = true
}

extension KeyboardShortcut: Codable {
    private enum Keys: String, CodingKey { case keyCode, modifierFlags }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let code = try c.decode(UInt16.self, forKey: .keyCode)
        let flags = try c.decode(UInt64.self, forKey: .modifierFlags)
        guard let value = KeyboardShortcut(keyCode: code, modifierFlags: flags) else {
            throw DecodingError.dataCorruptedError(forKey: .keyCode, in: c, debugDescription: "A non-modifier main key is required")
        }
        self = value
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(keyCode, forKey: .keyCode); try c.encode(modifierFlags, forKey: .modifierFlags)
    }
}
