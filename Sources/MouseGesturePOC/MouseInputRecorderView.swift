import SwiftUI

struct MouseInputRecorderView: View {
    @ObservedObject var model: AppViewModel
    let use: (RecordedMouseInput) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var closing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("录制鼠标输入").font(.title2)
            Text("请按下要配置的鼠标按钮")
            switch model.mouseRecording {
            case .captured(let input):
                Text("检测到：\(input.title)").font(.title3)
            case .failed(let message): Text(message).foregroundStyle(.secondary)
            case .primaryUnsupported:
                Text("主按键和辅助按键暂不支持重新映射").foregroundStyle(.secondary)
                Text("正在等待其他鼠标按钮…")
            default: Text("正在等待输入…").foregroundStyle(.secondary)
            }
            Text("可按住 ⌘、⌥、⌃、⇧ 再点击鼠标按钮。此次输入只用于录制，不执行已有动作。")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("重新录制") { model.beginMouseRecording?() }
                Spacer()
                Button("取消") { cancel(.cancel) }
                Button("使用此输入") {
                    if case .captured(let input) = model.mouseRecording {
                        closing = true
                        use(input); model.endMouseRecording?(.captureFinished); dismiss()
                    }
                }.disabled(!hasInput)
            }
        }.padding(24).frame(width: 460)
            .onAppear { model.beginMouseRecording?() }
            .onDisappear { model.endMouseRecording?(.sheetClosed) }
            .onExitCommand { cancel(.escape) }
            .onChange(of: model.mouseRecording) { _, value in
                if value == .idle && !closing { closing = true; dismiss() }
            }
    }
    private var hasInput: Bool { if case .captured = model.mouseRecording { return true }; return false }
    private func cancel(_ reason: MouseRecordingEndReason) {
        guard !closing else { return }
        closing = true; model.endMouseRecording?(reason); dismiss()
    }
}
