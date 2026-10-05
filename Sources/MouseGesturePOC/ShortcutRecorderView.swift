import SwiftUI
import Carbon

struct ShortcutRecorderView: View {
    let initial: KeyboardShortcut?
    let save: (KeyboardShortcut?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var shortcut: KeyboardShortcut?
    @State private var recording = true
    var body: some View {
        VStack(spacing: 18) {
            Text("自定义键盘快捷键").font(.title2)
            Text(recording ? "请按下快捷键" : "已记录快捷键")
            Text(shortcut?.display ?? "尚未设置").font(.title).frame(minHeight: 40)
            Text("支持普通按键和 ⌘、⌥、⌃、⇧ 组合；不能只录入修饰键。")
                .font(.caption).foregroundStyle(.secondary)
            ShortcutCapture(recording: $recording, shortcut: $shortcut).frame(width: 1, height: 1)
            HStack {
                Button("重新录制") { recording = true }
                Button("清除") { shortcut = nil; recording = false }
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") { save(shortcut); dismiss() }
            }
        }.padding(24).frame(width: 480)
            .onAppear { shortcut = initial }
    }
}

private struct ShortcutCapture: NSViewRepresentable {
    @Binding var recording: Bool
    @Binding var shortcut: KeyboardShortcut?
    func makeNSView(context: Context) -> CaptureView { CaptureView() }
    func updateNSView(_ view: CaptureView, context: Context) {
        view.recording = recording
        view.record = { event in
            if let value = KeyboardShortcut(keyCode: event.keyCode, modifierFlags: UInt64(event.modifierFlags.rawValue)) {
                shortcut = value; recording = false
            }
        }
        if recording { DispatchQueue.main.async { view.window?.makeFirstResponder(view) } }
    }
    final class CaptureView: NSView {
        var recording = false
        var record: ((NSEvent) -> Void)?
        private var monitor: Any?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.recording, self.window?.isKeyWindow == true else { return event }
                self.record?(event)
                return nil
            }
        }
        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            if recording { record?(event) } else { super.keyDown(with: event) }
        }
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard recording, event.type == .keyDown else { return super.performKeyEquivalent(with: event) }
            record?(event); return true
        }
    }
}
