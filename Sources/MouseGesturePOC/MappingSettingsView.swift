import SwiftUI

private enum TableActionChoice: Hashable {
    case option(MappingActionOption), shortcutValue, currentValue, recordShortcut
}
private enum MappingSheet: Identifiable {
    case editor(MappingUIDraft, recordShortcut: Bool = false), gestures(MouseInput), settings(ApplicationSettingsTopic?)
    var id: String {
        switch self { case .editor(let draft, _): "editor-\(draft.id)"; case .gestures(let input): "gesture-\(input.number)"; case .settings: "settings" }
    }
    var isSettings: Bool { if case .settings = self { true } else { false } }
}

struct MappingSettingsView: View {
    @ObservedObject var model: AppViewModel
    @State private var sheet: MappingSheet?
    @State private var deleting: MappingTableRow?
    private let inputWidth: CGFloat = 230
    private let operationWidth: CGFloat = 200
    private var rows: [MappingTableRow] { MappingPresentation.tableRows(in: model.config.mappingStore) }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("鼠标映射").font(.title.weight(.semibold))
                    Text("选择鼠标输入、操作方式和执行动作。").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button { sheet = .editor(MappingUIDraft()) } label: { Label("添加映射", systemImage: "plus") }
                    .keyboardShortcut("n", modifiers: .command)
                Button { sheet = .settings(nil) } label: { Label("设置", systemImage: "gearshape") }
            }.padding(.bottom, 24)
            HStack(spacing: 16) {
                Text("鼠标输入").frame(width: inputWidth, alignment: .leading)
                Text("操作方式").frame(width: operationWidth, alignment: .leading)
                Text("执行动作").frame(maxWidth: .infinity, alignment: .leading)
                Color.clear.frame(width: 24, height: 1)
            }.font(.callout.weight(.semibold)).padding(.horizontal, 12).padding(.bottom, 12)
            Divider()
            if rows.isEmpty {
                ContentUnavailableView {
                    Label("还没有鼠标映射", systemImage: "computermouse")
                } description: { Text("添加一个鼠标输入，为它设置操作。") }
                actions: { Button("添加映射") { sheet = .editor(MappingUIDraft()) } }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            switch row {
                            case .mapping(let mapping): mappingRow(mapping)
                            case .gestures(let group): gestureRow(group)
                            }
                            Divider()
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                if let message = model.mappingNotice {
                    Text(message).font(.callout)
                    if model.deletedMappingRows != nil { Button("撤销") { model.undoMappingDeletion() }.buttonStyle(.link) }
                    Button { model.mappingNotice = nil; model.deletedMappingRows = nil } label: { Image(systemName: "xmark").font(.caption) }
                        .buttonStyle(.plain).accessibilityLabel("关闭提示")
                }
                Spacer()
            }.frame(height: 30).padding(.top, 10)
        }.padding(24).frame(minWidth: 930, minHeight: 640)
        .sheet(item: $sheet, onDismiss: { model.selectedTab = .mappings }) { item in
            switch item {
            case .editor(let draft, let recording): MappingEditorView(model: model, initial: draft, recordShortcut: recording)
            case .gestures(let input): GestureMappingDetailsView(model: model, input: input)
            case .settings(let topic): ApplicationSettingsView(model: model, initialTopic: topic)
            }
        }
        .alert("删除这条映射？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("取消", role: .cancel) { deleting = nil }
            Button("删除", role: .destructive) { if let item = deleting { model.deleteMappingRow(item) }; deleting = nil }
        } message: {
            Text(deleting.map { item in
                let detail: String
                if case .gestures(let group) = item { detail = "将删除这个按钮的 \(group.rows.count) 条方向映射。" } else { detail = "" }
                return item.description + "\n" + detail + "删除后可在本次使用中撤销。"
            } ?? "")
        }
        .onAppear { routeLegacyDestination() }
        .onChange(of: model.selectedTab) { _, _ in routeLegacyDestination() }
    }
    private func mappingRow(_ row: MouseMapping) -> some View {
        HStack(spacing: 16) {
            Button { sheet = .editor(MappingUIDraft(.mapping(row))) } label: {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(MappingPresentation.inputLabel(row))
                        if !row.isEnabled { Text("已停用").font(.caption).foregroundStyle(.secondary) }
                    }.frame(width: inputWidth, alignment: .leading)
                    Text(row.trigger.title).frame(width: operationWidth, alignment: .leading)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("编辑\(MappingPresentation.inputLabel(row)) · \(row.trigger.title)")
            Picker("执行动作", selection: actionBinding(row)) {
                ForEach(MappingActionOption.allCases.filter { $0.action != nil }, id: \.self) { option in
                    Text(option.title).tag(TableActionChoice.option(option))
                }
                if case .keyboardShortcut = row.action { Text(MappingPresentation.actionLabel(row.action)).tag(TableActionChoice.shortcutValue) }
                if MappingActionOption.choice(for: row.action) == .preserved { Text(MappingPresentation.actionLabel(row.action)).tag(TableActionChoice.currentValue) }
                Divider()
                Text("键盘快捷键…").tag(TableActionChoice.recordShortcut)
            }.labelsHidden().pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("\(MappingPresentation.inputLabel(row)) · \(row.trigger.title) · 执行动作")
            Menu {
                Button("编辑") { sheet = .editor(MappingUIDraft(.mapping(row))) }
                Button(row.isEnabled ? "停用" : "启用") {
                    model.setMappingEnabled(!row.isEnabled, id: row.id)
                    model.mappingNotice = row.isEnabled ? "已停用映射" : "已启用映射"; model.deletedMappingRows = nil
                }
                Divider()
                Button("删除", role: .destructive) { deleting = .mapping(row) }
            } label: { Image(systemName: "ellipsis") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 24)
                .accessibilityLabel("\(MappingPresentation.inputLabel(row)) · \(row.trigger.title) · 更多操作")
        }.padding(.horizontal, 12).frame(minHeight: 44).opacity(row.isEnabled ? 1 : 0.45)
    }
    private func actionBinding(_ row: MouseMapping) -> Binding<TableActionChoice> {
        Binding(get: {
            if case .keyboardShortcut = row.action { return .shortcutValue }
            let option = MappingActionOption.choice(for: row.action)
            return option == .preserved ? .currentValue : .option(option)
        }, set: { choice in
            switch choice {
            case .option(let option):
                guard let action = option.action else { return }
                var updated = row; updated.action = action
                if case .saved = model.saveMapping(updated) { model.mappingNotice = "已修改执行动作"; model.deletedMappingRows = nil }
            case .recordShortcut: sheet = .editor(MappingUIDraft(.mapping(row)), recordShortcut: true)
            case .shortcutValue, .currentValue: break
            }
        })
    }
    private func gestureRow(_ group: GestureMappingGroup) -> some View {
        HStack(spacing: 16) {
            Button { sheet = .editor(MappingUIDraft(.gestures(group))) } label: {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.input.title)
                        if !group.isEnabled { Text("已停用").font(.caption).foregroundStyle(.secondary) }
                    }.frame(width: inputWidth, alignment: .leading)
                    Text("按住拖动").frame(width: operationWidth, alignment: .leading)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("编辑\(group.input.title) · 按住拖动")
            HStack(spacing: 10) {
                Text("触控板式手势")
                Text("\(group.enabledCount)/\(group.rows.count) 方向启用").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Button("设置…") { sheet = .gestures(group.input) }
                    .accessibilityLabel("\(group.input.title) · 触控板式手势 · 设置")
            }.frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                Button("编辑") { sheet = .editor(MappingUIDraft(.gestures(group))) }
                Button(group.isEnabled ? "停用" : "启用") {
                    if !model.toggleGestureGroup(group.input) { sheet = .gestures(group.input) }
                }
                Divider()
                Button("删除", role: .destructive) { deleting = .gestures(group) }
            } label: { Image(systemName: "ellipsis") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 24)
                .accessibilityLabel("\(group.input.title) · 按住拖动 · 更多操作")
        }.padding(.horizontal, 12).frame(minHeight: 44).opacity(group.isEnabled ? 1 : 0.45)
    }
    private func routeLegacyDestination() {
        guard sheet?.isSettings != true else { return }
        switch model.selectedTab {
        case .mappings: break
        case .general: sheet = .settings(nil)
        case .diagnostics: sheet = .settings(.help)
        case .about: sheet = .settings(.about)
        case .gestures:
            if let input = MappingPresentation.groups(in: model.config.mappingStore).first(where: { $0.rows.contains { !$0.trigger.isButtonPress } })?.input { sheet = .gestures(input) }
        }
    }
}
