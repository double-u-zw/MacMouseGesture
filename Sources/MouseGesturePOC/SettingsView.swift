import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        if model.onboardingVisible {
            OnboardingView(model: model)
        } else {
        TabView(selection: $model.selectedTab) {
            GeneralSettingsView(model: model)
                .tabItem { Label("通用", systemImage: "gearshape") }.tag(SettingsTab.general)
            GestureSettingsView(model: model)
                .tabItem { Label("手势", systemImage: "computermouse") }.tag(SettingsTab.gestures)
            DiagnosticsView(model: model)
                .tabItem { Label("诊断", systemImage: "waveform.path.ecg") }.tag(SettingsTab.diagnostics)
            AboutView()
                .tabItem { Label("关于", systemImage: "info.circle") }.tag(SettingsTab.about)
        }
        .frame(minWidth: 510, idealWidth: 540, minHeight: 500, idealHeight: 540)
        }
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MacMouseGesture").font(.title2.weight(.semibold))
                    Text("用鼠标手势轻松操作 Mac。").foregroundStyle(.secondary)
                }
                .padding(.vertical, 5)
            }
            Section { Button("首次设置与手势测试") { model.reopenOnboarding?() } }
            Section("应用") {
                Toggle("启用 MacMouseGesture", isOn: model.binding(\.enabled))
                Toggle("登录时启动", isOn: Binding(
                    get: { model.loginState.isSelected },
                    set: { model.setLoginEnabled?($0) }
                ))
                if model.loginState == .requiresApproval {
                    HStack {
                        Text(model.loginState.label).foregroundStyle(.secondary)
                        Spacer()
                        Button("打开登录项设置") { model.openLoginItems?() }
                    }
                }
            }
            Section("状态") {
                LabeledContent("手势引擎", value: model.status.rawValue)
                HStack {
                    Text("辅助功能权限")
                    Spacer()
                    Text(PermissionPresentation.accessibility(model.accessibilityGranted, completed: !OnboardingState.needsWelcome()))
                        .foregroundStyle(model.accessibilityGranted ? Color.secondary : Color.orange)
                    if !model.accessibilityGranted {
                        Button("打开系统设置") { model.openAccessibility?() }
                    }
                }
                HStack {
                    Text("输入监控权限")
                    Spacer()
                    Text(PermissionPresentation.inputMonitoring(model.inputMonitoringGranted))
                        .foregroundStyle(.secondary)
                    if !model.inputMonitoringGranted {
                        Button("打开系统设置") { model.openInputMonitoring?() }
                    }
                }
            }
            if !model.accessibilityGranted {
                Section {
                    Text("MacMouseGesture 需要辅助功能权限，才能识别鼠标侧键手势。")
                        .foregroundStyle(.secondary)
                    Button("打开系统设置") { model.openAccessibility?() }
                }
            }
            if let message = model.message {
                Section { Text(message).foregroundStyle(.orange) }
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }
}

struct GestureSettingsView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        Form {
            Section("手势按键") {
                Toggle("侧键 1", isOn: model.buttonBinding(3))
                Toggle("侧键 2", isOn: model.buttonBinding(4))
                Text("至少保留一颗侧键。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("横向手势") {
                Toggle("切换桌面空间", isOn: model.binding(\.horizontalEnabled))
                Picker("方向", selection: model.binding(\.horizontalInvert)) {
                    Text("自然").tag(false)
                    Text("反向").tag(true)
                }
                .pickerStyle(.segmented)
            }
            Section("纵向手势") {
                Toggle("启用纵向手势", isOn: model.binding(\.verticalEnabled))
                LabeledContent("向上拖动", value: "调度中心")
                LabeledContent("向下拖动", value: "应用 Exposé")
            }
            Section("手感") {
                VStack(alignment: .leading, spacing: 5) {
                    Text("灵敏度")
                    Slider(value: model.sensitivityBinding, in: 0...1, step: 0.001)
                        .accessibilityLabel("横向手势灵敏度")
                        .accessibilityValue("\(Int(model.config.sensitivity))")
                    HStack { Text("较低"); Spacer(); Text("较高") }
                        .font(.caption).foregroundStyle(.secondary)
                    Text("控制横向拖动距离与桌面空间切换进度的关系；纵向手感目前固定。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("触发距离")
                    Slider(value: model.binding(\.deadZone, debounce: true), in: 1...80, step: 1)
                        .accessibilityLabel("触发距离")
                        .accessibilityValue("\(Int(model.config.deadZone)) 像素")
                    HStack { Text("较短"); Spacer(); Text("较长") }
                        .font(.caption).foregroundStyle(.secondary)
                    Text("鼠标移动多远后开始识别手势。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle("手势期间保持指针不动", isOn: model.binding(\.freezePointer))
                Text("进行手势时，指针不会跟随鼠标移动。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button("恢复默认手势设置") { model.resetGestureSettings() }
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }
}

struct DiagnosticsView: View {
    @ObservedObject var model: AppViewModel
    @State private var advanced = false

    private var macOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return version.patchVersion == 0
            ? "\(version.majorVersion).\(version.minorVersion)"
            : "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    var body: some View {
        Form {
            Section("系统") {
                LabeledContent("应用版本", value: "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.6") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "12"))")
                LabeledContent("macOS", value: macOSVersion)
                LabeledContent("架构", value: "Apple Silicon")
            }
            Section("状态") {
                LabeledContent("手势引擎", value: model.status.rawValue)
                LabeledContent("鼠标输入", value: model.snapshot.eventTap == "enabled" ? "正常" : "未运行")
                LabeledContent("手势后端", value: model.status == .running ? "正常" : "未运行")
            }
            Section("手势统计") {
                LabeledContent("已开始", value: "\(model.snapshot.started)")
                LabeledContent("已完成", value: "\(model.snapshot.completed)")
                LabeledContent("已取消", value: "\(model.snapshot.cancelled)")
                LabeledContent("进行中", value: "\(model.snapshot.open)")
                LabeledContent("Event Tap 重启次数", value: "\(model.snapshot.eventTapRestarts)")
                LabeledContent("投递失败", value: "\(model.snapshot.postFailures)")
                LabeledContent("序列错误", value: "\(model.snapshot.sequenceErrors)")
            }
            Section {
                DisclosureGroup("高级诊断", isExpanded: $advanced) {
                    ScrollView {
                        Text(model.advancedReport)
                            .font(.system(size: 10, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 155)
                }
            }
            Section {
                Text("分享前请展开高级诊断检查内容；复制和保存会使用同一份脱敏报告。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("复制诊断信息") { model.copyDiagnostics?() }
                    Button("保存诊断快照") { model.saveDiagnostics?() }
                }
                Divider().padding(.vertical, 5)
                Button("重新启动手势引擎") { model.restartEngine?() }
            }
            if let message = model.message {
                Section { Text(message).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                .resizable().frame(width: 80, height: 80)
                .accessibilityHidden(true)
            Text("MacMouseGesture").font(.title2.weight(.semibold))
            Text("版本 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.6") · Build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "12")")
                .foregroundStyle(.secondary)
            Text("让普通鼠标拥有类似触控板的 macOS 系统手势。")
            Text("Early Beta · macOS 27 / Apple Silicon").foregroundStyle(.secondary)
            Text("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)").font(.caption)
            Text("Git Commit: \(Bundle.main.object(forInfoDictionaryKey: "GitCommit") as? String ?? "unknown")")
                .font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
            Divider().frame(width: 260)
            Text("© 2026").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View { SettingsView(model: .preview) }
}
