import SwiftUI

struct MappingEditorView: View {
    @ObservedObject var model: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MappingUIDraft
    @State private var recordingShortcut = false
    @State private var recordingMouse = false
    @State private var confirmDeletion = false
    @State private var notice: String?
    private let requestShortcutRecording: Bool
    init(model: AppViewModel, initial: MappingUIDraft, recordShortcut: Bool = false) {
        self.model = model; requestShortcutRecording = recordShortcut; _draft = State(initialValue: initial)
    }
    private var modifiedDrag: Bool { draft.operation == .drag && !draft.modifiers.isEmpty }
    private var conflict: MappingTableRow? { modifiedDrag ? nil : model.mappingConflict(draft) }
    private var shortcut: KeyboardShortcut? { if case .keyboardShortcut(let value) = draft.action { value } else { nil } }
    private var inputNumber: Binding<Int> {
        Binding(get: { draft.hasInput ? draft.input.number : 0 }, set: { number in
            if (3...32).contains(number) { draft.input = .button(number); draft.hasInput = true }
        })
    }
    private var actionSelection: Binding<MappingActionOption> {
        Binding(get: { MappingActionOption.choice(for: draft.action) }, set: { option in
            if option == .shortcut { recordingShortcut = true }
            else if let action = option.action { draft.action = action }
        })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(draft.isNew ? "添加映射" : "编辑映射").font(.title2.weight(.semibold))
            Form {
                Section("鼠标输入") {
                    Picker("按钮", selection: inputNumber) {
                        Text("请选择按钮…").tag(0)
                        ForEach(3...32, id: \.self) { number in Text(MouseInput.button(number).title).tag(number) }
                    }
                    Button("录制鼠标输入…") { recordingMouse = true }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("修饰键")
                        HStack(spacing: 18) {
                            modifierControl("⌃ Control", .control)
                            modifierControl("⌥ Option", .option)
                            modifierControl("⇧ Shift", .shift)
                            modifierControl("⌘ Command", .command)
                        }.font(.callout).accessibilityElement(children: .contain)
                    }.accessibilityElement(children: .contain)
                    LabeledContent("输入预览", value: draft.inputLabel)
                }
                Section("操作方式") {
                    if draft.isGestureGroup { LabeledContent("操作方式", value: "按住拖动") }
                    else {
                        Picker("操作方式", selection: $draft.operation) {
                            ForEach(MappingOperation.allCases, id: \.self) { operation in Text(operation.rawValue).tag(operation) }
                        }
                    }
                    if draft.operation == .wheelUp || draft.operation == .wheelDown {
                        Text("每个有效滚轮步执行一次动作。").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("执行动作") {
                    if draft.operation == .drag {
                        LabeledContent("执行动作", value: "触控板式手势")
                        Text("左右连续切换桌面、上拖调度中心、下拖应用 Exposé；四方向可分别启停，动作固定。")
                            .font(.callout).foregroundStyle(.secondary)
                        if modifiedDrag {
                            Label("触控板式手势暂不支持修饰键组合。", systemImage: "exclamationmark.circle")
                                .font(.callout).foregroundStyle(.orange)
                        }
                    } else {
                        Picker("执行动作", selection: actionSelection) {
                            ForEach(MappingActionOption.allCases.filter { $0 != .preserved }, id: \.self) { option in
                                Text(option.title).tag(option)
                            }
                            if MappingActionOption.choice(for: draft.action) == .preserved {
                                Text("\(draft.action.title) · 保留当前配置").tag(MappingActionOption.preserved)
                            }
                        }
                        if let shortcut {
                            HStack {
                                Text(shortcut.display).font(.body.monospaced())
                                Spacer()
                                Button("重新录制…") { recordingShortcut = true }
                            }
                        }
                        if draft.action == .navigation(.back) {
                            Text("Chrome 已验证；Finder 暂不支持此返回动作。").font(.caption).foregroundStyle(.secondary)
                        }
                        if draft.action == .system(.openFinder) {
                            Text("打开访达的个人主目录窗口。").font(.caption).foregroundStyle(.secondary)
                        }
                        if draft.action == .system(.newFolder) {
                            Text("仅在访达前台时，在当前文件夹新建并进入命名；其他应用中不执行。").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }.formStyle(.grouped)
            if let conflict {
                VStack(alignment: .leading, spacing: 7) {
                    Label("映射已存在", systemImage: "exclamationmark.circle").font(.callout.weight(.semibold))
                    Text(conflict.description).font(.callout)
                    Text("相同鼠标输入（含修饰键）和操作方式只能有一条映射。").font(.caption).foregroundStyle(.secondary)
                    Button("编辑现有映射") { draft = MappingUIDraft(conflict); notice = nil }
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityElement(children: .contain)
            }
            if let notice { Text(notice).font(.callout).foregroundStyle(.orange) }
            Toggle("启用这条映射", isOn: $draft.enabled).toggleStyle(.checkbox).font(.callout)
            HStack {
                if !draft.isNew { Button("删除…", role: .destructive) { confirmDeletion = true } }
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(draft.isNew ? "添加" : "保存") {
                    switch model.saveMappingDraft(draft) {
                    case .saved: dismiss()
                    case .existing: notice = "请先解决重复映射。"
                    case .unavailable: notice = "当前输入组合暂不支持此操作方式，或原映射已变更。"
                    }
                }.keyboardShortcut(.defaultAction).disabled(!draft.hasInput || modifiedDrag || conflict != nil)
            }
        }.padding(24).frame(width: 700, height: 690)
        .sheet(isPresented: $recordingShortcut) {
            ShortcutRecorderView(initial: shortcut) { value in draft.action = value.map(MouseAction.keyboardShortcut) ?? .none }
        }
        .sheet(isPresented: $recordingMouse) {
            MouseInputRecorderView(model: model) { input in
                draft.input = input.button.input; draft.modifiers = input.modifiers; draft.hasInput = true
            }
        }
        .onAppear { if requestShortcutRecording { recordingShortcut = true } }
        .alert("删除这条映射？", isPresented: $confirmDeletion) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                switch draft.source {
                case .mapping(let row): model.deleteMappingRow(.mapping(row))
                case .gestures(let group): model.deleteMappingRow(.gestures(group))
                case .new: break
                }
                dismiss()
            }
        } message: { Text("删除后可在本次使用中撤销。") }
    }
    private func modifierControl(_ title: String, _ flag: MouseModifiers) -> some View {
        Toggle(title, isOn: Binding(get: { draft.modifiers.contains(flag) }, set: { selected in
            if selected { draft.modifiers.insert(flag) } else { draft.modifiers.remove(flag) }
        })).toggleStyle(.checkbox).accessibilityLabel("\(title) 修饰键")
    }
}
