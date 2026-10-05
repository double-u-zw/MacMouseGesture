import Foundation
import CoreGraphics

// The only conversion boundary between zero-based CG/HID and one-based UI/storage.
struct MouseButtonIdentifier: Hashable {
    let rawValue: Int
    init?(rawValue: Int) {
        guard (0...31).contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }
    init?(number: Int) {
        guard (1...32).contains(number) else { return nil }
        self.init(rawValue: number - 1)
    }
    var number: Int { rawValue + 1 }
    var input: MouseInput { .button(number) }
    var canRemap: Bool { rawValue >= 2 }
    var title: String {
        switch rawValue {
        case 0: "左键"
        case 1: "右键"
        case 2: "中键"
        case 3: "侧键 4"
        case 4: "侧键 5"
        default: "鼠标按钮 \(number)"
        }
    }
}

struct MouseModifiers: OptionSet, Hashable, Codable {
    let rawValue: UInt64
    init(rawValue: UInt64) { self.rawValue = rawValue }
    static let command = Self(rawValue: CGEventFlags.maskCommand.rawValue)
    static let option = Self(rawValue: CGEventFlags.maskAlternate.rawValue)
    static let control = Self(rawValue: CGEventFlags.maskControl.rawValue)
    static let shift = Self(rawValue: CGEventFlags.maskShift.rawValue)
    static let supported: Self = [.command, .option, .control, .shift]
    init(flags: CGEventFlags) { self.init(rawValue: flags.rawValue & Self.supported.rawValue) }
    var symbols: String {
        (contains(.control) ? "⌃" : "") + (contains(.option) ? "⌥" : "") +
        (contains(.shift) ? "⇧" : "") + (contains(.command) ? "⌘" : "")
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = try c.decode(UInt64.self)
        guard raw & ~Self.supported.rawValue == 0 else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported mouse modifiers")
        }
        self.init(rawValue: raw)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer(); try c.encode(rawValue)
    }
}

struct RecordedMouseInput: Equatable, Hashable {
    let button: MouseButtonIdentifier
    var modifiers: MouseModifiers = []
    var title: String { modifiers.isEmpty ? button.title : "\(modifiers.symbols) + \(button.title)" }
    var trigger: MouseTrigger { .shortPress(modifiers: modifiers) }
}
