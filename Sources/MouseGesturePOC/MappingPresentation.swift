import Foundation
import CoreGraphics
import Carbon

// The settings list is derived exclusively from the mapping snapshot.
struct MappingGroup: Identifiable, Equatable {
    let input: MouseInput
    let rows: [MouseMapping]
    var id: MouseInput { input }
    var title: String { input.title }
}
enum MappingPresentation {
    static func groups(in store: MouseMappingStore) -> [MappingGroup] {
        // Old migration placeholders do not represent a user-created mapping.
        let rows = store.mappings.filter { !LegacyMappingProjection.isEmptyPlaceholder($0) }
        return Set(rows.map(\.input)).sorted { $0.number < $1.number }.map { input in
            MappingGroup(input: input, rows: rows.filter { $0.input == input }.sorted {
                $0.trigger.displayOrder == $1.trigger.displayOrder ?
                    $0.trigger.modifiers.rawValue < $1.trigger.modifiers.rawValue : $0.trigger.displayOrder < $1.trigger.displayOrder
            })
        }
    }
    static func triggerLabel(_ trigger: MouseTrigger) -> String {
        trigger.modifiers.isEmpty ? trigger.title : "\(trigger.modifiers.symbols) + \(trigger.title)"
    }
    static func actionLabel(_ action: MouseAction) -> String {
        if case .keyboardShortcut(let shortcut) = action { return "键盘快捷键 · \(shortcut.display)" }
        return action.title
    }
    static func inputLabel(_ row: MouseMapping) -> String {
        row.trigger.modifiers.isEmpty ? row.input.title : "\(row.trigger.modifiers.symbols) + \(row.input.title)"
    }
    static func gestureGroup(_ input: MouseInput, in store: MouseMappingStore) -> GestureMappingGroup? {
        let rows = store.mappings.filter { $0.input == input && !$0.trigger.isButtonPress }
        return rows.isEmpty ? nil : GestureMappingGroup(input: input, rows: rows)
    }
    static func tableRows(in store: MouseMappingStore) -> [MappingTableRow] {
        groups(in: store).flatMap { group in
            let ordinary = group.rows.filter { $0.trigger.isButtonPress }.map(MappingTableRow.mapping)
            return ordinary + (gestureGroup(group.input, in: store).map { [MappingTableRow.gestures($0)] } ?? [])
        }
    }
}

// UI-only grouping and drafts. The persisted records, triggers and actions stay unchanged.
struct GestureMappingGroup: Identifiable, Equatable {
    let input: MouseInput
    let rows: [MouseMapping]
    var id: MouseInput { input }
    var enabledCount: Int { rows.filter(\.isEnabled).count }
    var isEnabled: Bool { enabledCount > 0 }
}
enum MappingTableRow: Identifiable {
    case mapping(MouseMapping), gestures(GestureMappingGroup)
    var id: String { switch self { case .mapping(let row): row.id.uuidString; case .gestures(let group): "gestures-\(group.input.number)" } }
    var description: String {
        switch self {
        case .mapping(let row): "\(MappingPresentation.inputLabel(row)) · \(row.trigger.title)\n\(MappingPresentation.actionLabel(row.action)) · \(row.isEnabled ? "已启用" : "已停用")"
        case .gestures(let group): "\(group.input.title) · 按住拖动\n触控板式手势 · \(group.enabledCount)/\(group.rows.count) 方向启用"
        }
    }
}
enum MappingOperation: String, CaseIterable {
    case short = "短按", long = "长按", wheelUp = "按住并向上滚动", wheelDown = "按住并向下滚动", drag = "按住拖动"
    init(_ trigger: MouseTrigger) {
        self = trigger.isShortPress ? .short : trigger.isLongPress ? .long : trigger.isWheel ? (trigger.wheelDirection == .up ? .wheelUp : .wheelDown) : .drag
    }
    func trigger(modifiers: MouseModifiers) -> MouseTrigger {
        switch self {
        case .short: .shortPress(modifiers: modifiers)
        case .long: .longPress(modifiers: modifiers)
        case .wheelUp: .wheel(.up, modifiers: modifiers)
        case .wheelDown: .wheel(.down, modifiers: modifiers)
        case .drag: .drag(.left)
        }
    }
}
struct MappingUIDraft: Identifiable {
    enum Source { case new, mapping(MouseMapping), gestures(GestureMappingGroup) }
    var id = UUID()
    var source: Source = .new
    var input: MouseInput = .button(3)
    var modifiers: MouseModifiers = []
    var hasInput = false
    var operation: MappingOperation = .short
    var action: MouseAction = .system(.showDesktop)
    var enabled = true
    var isNew: Bool { if case .new = source { true } else { false } }
    var isGestureGroup: Bool { if case .gestures = source { true } else { false } }
    var originalIDs: Set<UUID> {
        switch source { case .new: []; case .mapping(let row): [row.id]; case .gestures(let group): Set(group.rows.map(\.id)) }
    }
    var inputLabel: String { hasInput ? (modifiers.isEmpty ? input.title : "\(modifiers.symbols) + \(input.title)") : "尚未选择" }
    init() {}
    init(_ row: MappingTableRow) {
        hasInput = true
        switch row {
        case .mapping(let mapping):
            source = .mapping(mapping); input = mapping.input; modifiers = mapping.trigger.modifiers
            operation = MappingOperation(mapping.trigger); action = mapping.action; enabled = mapping.isEnabled
        case .gestures(let group):
            source = .gestures(group); input = group.input; operation = .drag; enabled = group.isEnabled
        }
    }
}
struct MappingGestureParameters: Equatable {
    var inverted: Bool
    var sensitivity: Double
    var distance: Double
    var freeze: Bool
    init(_ config: AppConfig) { inverted = config.horizontalInvert; sensitivity = config.sensitivity; distance = config.deadZone; freeze = config.freezePointer }
}
enum MappingActionOption: Int, CaseIterable {
    case none, desktop, fullscreen, minimize, missionControl, appExpose, back, lockScreen, openFinder, newFolder, shortcut, preserved
    var title: String {
        switch self { case .shortcut: "键盘快捷键"; case .preserved: "保留当前动作"; case .back: "返回（Chrome）"; default: action!.title }
    }
    var action: MouseAction? {
        switch self {
        case .none: MouseAction.none
        case .desktop: .system(.showDesktop)
        case .fullscreen: .window(.toggleFullscreen)
        case .minimize: .window(.minimize)
        case .missionControl: .system(.missionControl)
        case .appExpose: .system(.appExpose)
        case .back: .navigation(.back)
        case .lockScreen: .system(.lockScreen)
        case .openFinder: .system(.openFinder)
        case .newFolder: .system(.newFolder)
        case .shortcut, .preserved: nil
        }
    }
    static func choice(for action: MouseAction) -> Self {
        if case .keyboardShortcut = action { return .shortcut }
        return allCases.first { $0.action == action } ?? .preserved
    }
}

extension KeyboardShortcut {
    var display: String {
        let flags = CGEventFlags(rawValue: modifierFlags)
        let prefix = (flags.contains(.maskControl) ? "⌃" : "") + (flags.contains(.maskAlternate) ? "⌥" : "") +
            (flags.contains(.maskShift) ? "⇧" : "") + (flags.contains(.maskCommand) ? "⌘" : "")
        let special: [UInt16: String] = [36: "↩", 48: "⇥", 49: "空格", 51: "⌫", 53: "⎋", 123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"]
        if let label = special[keyCode] { return prefix + label }
        let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeRetainedValue()
        if let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) {
            let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue()
            let layout = UnsafeRawPointer(CFDataGetBytePtr(data)).assumingMemoryBound(to: UCKeyboardLayout.self)
            var dead: UInt32 = 0
            var count = 0
            var chars = [UniChar](repeating: 0, count: 8)
            if UCKeyTranslate(layout, keyCode, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                              OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, chars.count, &count, &chars) == noErr, count > 0 {
                return prefix + String(utf16CodeUnits: chars, count: count).uppercased()
            }
        }
        return prefix + "按键 \(keyCode)"
    }
}
