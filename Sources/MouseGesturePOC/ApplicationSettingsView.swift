import SwiftUI

enum ApplicationSettingsTopic: String {
    case status = "运行状态", permissions = "权限检查", installation = "安装位置", help = "帮助", about = "关于"
}
struct ApplicationSettingsView: View {
    @ObservedObject var model: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var topic: ApplicationSettingsTopic?
    @State private var optionalPermission = false
    @State private var advanced = false
    init(model: AppViewModel, initialTopic: ApplicationSettingsTopic? = nil) {
        self.model = model; _topic = State(initialValue: initialTopic)
    }
    private var installationIsStandard: Bool { DiagnosticRedactor.installation() == "Applications" }
    private var message: String? {
        guard let message = UserMessage.display(model.message), !message.hasPrefix("建议将 MacMouseGesture") else { return nil }
        return message
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                if topic != nil {
                    Button { topic = nil } label: { Label("设置", systemImage: "chevron.left") }.buttonStyle(.plain)
                    Spacer()
                }
                Text(topic?.rawValue ?? "设置").font(.title2.weight(.semibold))
            }
            if let topic {
                if topic == .about { AboutView() }
                else {
                    Form {
                        switch topic {
                        case .status:
                            LabeledContent("当前状态", value: model.status.displayLabel)
                            if let guidance = model.status.guidance { Text(guidance).font(.callout).foregroundStyle(.secondary) }
                            if model.status == .error || model.status == .recovering {
                                Button("重新尝试") { model.restartEngine?() }
                            }
                            if let message { Text(message).font(.callout).foregroundStyle(.secondary) }
                        case .permissions:
                            LabeledContent("辅助功能", value: model.accessibilityGranted ? "已开启" : "未开启")
                            Text("执行配置动作需要辅助功能权限；状态会自动更新。").font(.callout).foregroundStyle(.secondary)
                            Button("打开辅助功能设置") { model.openAccessibility?() }
                            DisclosureGroup("可选：输入监控", isExpanded: $optionalPermission) {
                                Text("用于额外的鼠标兼容性诊断，未开启也可以使用手势。").font(.callout).foregroundStyle(.secondary)
                                LabeledContent("输入监控", value: model.inputMonitoringGranted ? "已开启" : "未开启")
                                Button("打开输入监控设置") { model.openInputMonitoring?() }
                            }
                        case .installation:
                            LabeledContent("应用位置", value: installationIsStandard ? "应用程序" : "其他位置")
                            if !installationIsStandard { Text("建议将 MacMouseGesture 移动到“应用程序”文件夹。当前开发版本可以在此位置检查。") }
                            else { Text("MacMouseGesture 已放置在“应用程序”文件夹。") }
                        case .help:
                            Section("配置鼠标映射") {
                                Text("点击动作选择器可直接修改动作；点击鼠标输入、操作方式或行菜单中的“编辑”可编辑映射。停用和删除位于行菜单中。")
                                Text("按住拖动对应触控板式手势。点击“设置”查看四方向和全局参数作用范围。")
                                Button("设置向导") { dismiss(); model.reopenOnboarding?() }
                            }
                            Section("诊断与反馈") {
                                Button("复制诊断信息") { model.copyDiagnostics?() }
                                Button("导出诊断信息…") { model.saveDiagnostics?() }
                                DisclosureGroup("查看详细诊断", isExpanded: $advanced) {
                                    ScrollView { Text(model.advancedReport).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(height: 140)
                                }
                            }
                        case .about: EmptyView()
                        }
                    }.formStyle(.grouped)
                }
            } else {
                Form {
                    Section {
                        Toggle("启用 MacMouseGesture", isOn: model.binding(\.enabled)).toggleStyle(.checkbox)
                        Toggle("登录时启动", isOn: Binding(get: { model.loginState.isSelected }, set: { model.setLoginEnabled?($0) })).toggleStyle(.checkbox)
                        if model.loginState == .requiresApproval || model.loginState == .unavailable {
                            HStack { Text(model.loginState.label).font(.callout).foregroundStyle(.secondary); Spacer(); Button("登录项设置") { model.openLoginItems?() } }
                        }
                    }
                    Section {
                        topicButton(.status, symbol: "waveform.path")
                        topicButton(.permissions, symbol: "hand.raised")
                        topicButton(.installation, symbol: "folder")
                    }
                }.formStyle(.grouped)
                HStack(spacing: 18) {
                    Button("帮助") { topic = .help }.buttonStyle(.link)
                    Button("关于") { topic = .about }.buttonStyle(.link)
                    Spacer()
                }
            }
            HStack { Spacer(); Button("完成") { dismiss() }.keyboardShortcut(.cancelAction) }
        }.padding(24).frame(width: 620, height: 520)
            .onAppear { if topic == .help { model.selectedTab = .diagnostics } }
            .onChange(of: topic) { _, value in if value == .help { model.selectedTab = .diagnostics } }
    }
    private func topicButton(_ topic: ApplicationSettingsTopic, symbol: String) -> some View {
        Button { self.topic = topic } label: {
            HStack { Label(topic.rawValue, systemImage: symbol); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary) }.contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
