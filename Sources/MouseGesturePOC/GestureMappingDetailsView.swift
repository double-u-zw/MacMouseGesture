import SwiftUI

struct GestureMappingDetailsView: View {
    @ObservedObject var model: AppViewModel
    let input: MouseInput
    @Environment(\.dismiss) private var dismiss
    @State private var enabled: [MouseDragDirection: Bool]
    @State private var parameters: MappingGestureParameters
    private let existingDirections: Set<MouseDragDirection>
    init(model: AppViewModel, input: MouseInput) {
        self.model = model; self.input = input
        let rows = model.config.mappingStore.mappings.filter { $0.input == input && !$0.trigger.isButtonPress }
        let states = rows.compactMap { row -> (MouseDragDirection, Bool)? in
            if case .drag(let direction) = row.trigger { return (direction, row.isEnabled) }; return nil
        }
        existingDirections = Set(states.map(\.0))
        _enabled = State(initialValue: Dictionary(uniqueKeysWithValues: states))
        _parameters = State(initialValue: MappingGestureParameters(model.config))
    }
    private var scope: String {
        MappingPresentation.tableRows(in: model.config.mappingStore).compactMap { row -> String? in
            if case .gestures(let group) = row { return group.input.title }; return nil
        }.joined(separator: "、")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("触控板式手势").font(.title2.weight(.semibold))
                Spacer(); Text(input.title).foregroundStyle(.secondary)
            }
            Text("按住按钮，拖动时连续跟随；可停顿、继续或反向，松开结束。").font(.callout)
            Form {
                Section("这个按钮的四个方向") {
                    Text("每个方向可独立启用或停用；目前不支持替换成其他拖动动作。")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(MouseDragDirection.allCases, id: \.self) { direction in
                        HStack {
                            Label(MouseTrigger.drag(direction).title, systemImage: symbol(direction)).frame(width: 170, alignment: .leading)
                            Text(LegacyDragSettingsAdapter.action(for: direction, inverted: parameters.inverted).title)
                                .foregroundStyle(enabled[direction] == true ? .primary : .secondary)
                            Spacer()
                            Toggle(existingDirections.contains(direction) ? (enabled[direction] == true ? "已启用" : "已停用") : "未配置", isOn: directionBinding(direction))
                                .toggleStyle(.checkbox).accessibilityLabel("\(input.title) · \(MouseTrigger.drag(direction).title) · 启用")
                        }
                    }
                    if existingDirections.count < 4 {
                        Text("未配置的方向保持缺省；勾选并保存才会新增该方向映射。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("全局手势参数 · 影响所有手势按钮") {
                    Text("作用范围：所有配置了触控板式手势的按钮（当前：\(scope)）。保存后，其他手势按钮也使用相同参数。")
                        .font(.callout)
                    Toggle("反转水平手势", isOn: $parameters.inverted).toggleStyle(.checkbox)
                    Text("当前效果：左拖 → \(LegacyDragSettingsAdapter.action(for: .left, inverted: parameters.inverted).title)；右拖 → \(LegacyDragSettingsAdapter.action(for: .right, inverted: parameters.inverted).title)。")
                        .font(.caption).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("横向灵敏度 · 只影响左右连续手势")
                        Slider(value: Binding(get: { GestureSettings.sensitivityPosition(for: parameters.sensitivity) }, set: { parameters.sensitivity = GestureSettings.sensitivityValue(at: $0) }), in: 0...1)
                            .accessibilityLabel("所有手势按钮的横向灵敏度")
                        HStack { Text("较低"); Spacer(); Text("较高") }.font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { Text("触发距离 · 所有方向"); Spacer(); Text("\(Int(parameters.distance)) 像素").foregroundStyle(.secondary) }
                        Slider(value: $parameters.distance, in: 1...80, step: 1).accessibilityLabel("所有手势按钮的触发距离")
                    }
                    Toggle("手势期间保持指针不动 · 所有方向", isOn: $parameters.freeze).toggleStyle(.checkbox)
                    Button("恢复默认全局参数") { parameters = MappingGestureParameters(.defaults) }
                }
            }.formStyle(.grouped)
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存") { model.saveGestureDetails(input: input, enabled: enabled, parameters: parameters); dismiss() }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 700, height: 680)
    }
    private func directionBinding(_ direction: MouseDragDirection) -> Binding<Bool> {
        Binding(get: { enabled[direction] == true }, set: { enabled[direction] = $0 })
    }
    private func symbol(_ direction: MouseDragDirection) -> String {
        switch direction { case .left: "arrow.left"; case .right: "arrow.right"; case .up: "arrow.up"; case .down: "arrow.down" }
    }
}
