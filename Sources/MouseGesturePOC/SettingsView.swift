import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppViewModel
    var body: some View {
        if model.onboardingVisible {
            OnboardingView(model: model)
        } else {
            TabView(selection: $model.selectedTab) {
                GeneralSettingsView(model: model)
                    .tabItem { Label("设置", systemImage: "computermouse") }.tag(SettingsTab.general)
                DiagnosticsView(model: model)
                    .tabItem { Label("帮助", systemImage: "questionmark.circle") }.tag(SettingsTab.diagnostics)
                AboutView()
                    .tabItem { Label("关于", systemImage: "info.circle") }.tag(SettingsTab.about)
            }
            .frame(minWidth: 530, idealWidth: 550, minHeight: 600, idealHeight: 620)
        }
    }
}

struct ProductHeading: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                .resizable().frame(width: 48, height: 48).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("MacMouseGesture").font(.title2.weight(.semibold))
                Text("让普通鼠标也能使用类似触控板的系统手势")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct GestureMap: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("左右拖动 · 切换桌面", systemImage: "arrow.left.and.right")
            Label("向上拖动 · 调度中心", systemImage: "arrow.up")
            Label("向下拖动 · 应用 Exposé", systemImage: "arrow.down")
        }
        .font(.callout)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var model: AppViewModel
    @State private var feelExpanded = false
    var body: some View {
        Form {
            Section { ProductHeading() }
            Section {
                Toggle("启用 MacMouseGesture", isOn: model.binding(\.enabled))
                Toggle("登录时启动", isOn: Binding(
                    get: { model.loginState.isSelected }, set: { model.setLoginEnabled?($0) }))
                if model.loginState == .requiresApproval || model.loginState == .unavailable {
                    HStack {
                        Text(model.loginState.label).font(.callout).foregroundStyle(.secondary)
                        Spacer()
                        Button("登录项设置") { model.openLoginItems?() }
                    }
                }
            }
            Section("按住侧键并拖动") {
                HStack(spacing: 24) {
                    Toggle("侧键 1", isOn: model.buttonBinding(3))
                    Toggle("侧键 2", isOn: model.buttonBinding(4))
                }
                Text("两颗侧键共用以下设置，至少保留一颗。")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("左右拖动 · 切换桌面", isOn: model.binding(\.horizontalEnabled))
                Toggle("上下拖动 · 调度中心 / 应用 Exposé", isOn: model.binding(\.verticalEnabled))
                Text("向上打开调度中心，向下查看当前应用的所有窗口。")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("反转左右拖动方向", isOn: model.binding(\.horizontalInvert))
            }
            Section {
                DisclosureGroup("调整手感", isExpanded: $feelExpanded) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("横向灵敏度")
                        Slider(value: model.sensitivityBinding, in: 0...1, step: 0.001)
                            .accessibilityLabel("横向手势灵敏度")
                            .accessibilityValue("\(Int(model.config.sensitivity))")
                        HStack { Text("较低"); Spacer(); Text("较高") }
                            .font(.caption).foregroundStyle(.secondary)
                        Text("触发距离")
                        Slider(value: model.binding(\.deadZone, debounce: true), in: 1...80, step: 1)
                            .accessibilityLabel("触发距离")
                            .accessibilityValue("\(Int(model.config.deadZone)) 像素")
                        HStack { Text("较短"); Spacer(); Text("较长") }
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                    Toggle("手势期间保持指针不动", isOn: model.binding(\.freezePointer))
                    Button("恢复默认手势设置") { model.resetGestureSettings() }
                }
            }
            Section {
                LabeledContent("状态", value: model.status.displayLabel)
                HStack {
                    Text("辅助功能权限")
                    Spacer()
                    Text(model.accessibilityGranted ? "已开启" : "未开启").foregroundStyle(.secondary)
                    if !model.accessibilityGranted {
                        Button("打开系统设置") { model.openAccessibility?() }
                    }
                }
                if let guidance = model.status.guidance {
                    HStack {
                        Text(guidance).font(.callout).foregroundStyle(.secondary)
                        Spacer()
                        if model.status == .error || model.status == .recovering {
                            Button("重新尝试") { model.restartEngine?() }
                        }
                    }
                }
                if let message = UserMessage.display(model.message) {
                    Text(message).font(.callout).foregroundStyle(.secondary)
                }
                Button("设置指引与侧键测试") { model.reopenOnboarding?() }
            }
        }
        .formStyle(.grouped)
        .padding(6)
    }
}

struct DiagnosticsView: View {
    @ObservedObject var model: AppViewModel
    @State private var advanced = false
    @State private var optionalPermission = false
    var body: some View {
        Form {
            Section("使用手势") {
                Text("按住已启用的鼠标侧键，再向需要的方向拖动。")
                GestureMap()
                Button("打开设置指引") { model.reopenOnboarding?() }
            }
            Section("遇到问题？") {
                LabeledContent("当前状态", value: model.status.displayLabel)
                if !model.accessibilityGranted {
                    Text("开启辅助功能权限后，MacMouseGesture 才能控制系统手势。")
                        .foregroundStyle(.secondary)
                    Button("打开系统设置") { model.openAccessibility?() }
                }
                Button("重新尝试运行手势") { model.restartEngine?() }
                DisclosureGroup("可选输入权限", isExpanded: $optionalPermission) {
                    Text("输入监控用于额外的鼠标兼容性诊断，不是使用手势的必需权限。")
                        .font(.callout).foregroundStyle(.secondary)
                    LabeledContent("输入监控", value: model.inputMonitoringGranted ? "已开启" : "未开启")
                    Button("打开输入监控设置") { model.openInputMonitoring?() }
                }
            }
            Section("诊断") {
                Text("需要反馈问题时，可复制或导出诊断信息。分享前请先查看内容。")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button("复制诊断信息") { model.copyDiagnostics?() }
                    Button("导出诊断信息…") { model.saveDiagnostics?() }
                }
                DisclosureGroup("查看详细诊断", isExpanded: $advanced) {
                    ScrollView {
                        Text(model.advancedReport)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(height: 180)
                }
                if let message = UserMessage.display(model.message) {
                    Text(message).font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(6)
    }
}

struct AboutView: View {
    @State private var showNotices = false
    private var version: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                .resizable().frame(width: 88, height: 88).accessibilityHidden(true)
            Text("MacMouseGesture").font(.title2.weight(.semibold))
            Text(version).foregroundStyle(.secondary)
            Text("让普通鼠标也能使用类似触控板的系统手势")
                .font(.callout)
            Text("Beta · macOS 27 / Apple Silicon").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 18) {
                Link("GitHub 项目", destination: URL(string: "https://github.com/double-u-zw/MacMouseGesture")!)
                Button("许可与致谢") { showNotices = true }.buttonStyle(.link)
            }.padding(.top, 8)
            Text("© 2026 MacMouseGesture").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showNotices) {
            VStack(alignment: .leading, spacing: 16) {
                Text("许可与致谢").font(.title2.weight(.semibold))
                ScrollView {
                    Text(notices).font(.callout).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack { Spacer(); Button("完成") { showNotices = false }.keyboardShortcut(.defaultAction) }
            }.padding(24).frame(width: 490, height: 390)
        }
    }
    private var notices: String {
        guard let url = Bundle.main.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "暂时无法读取随应用提供的许可与致谢文件。"
        }
        return text
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View { SettingsView(model: .preview) }
}
