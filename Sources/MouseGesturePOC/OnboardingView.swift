import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppViewModel
    @State private var optionalPermission = false
    private var stepNumber: Int {
        switch model.onboarding.step {
        case .welcome: 1
        case .permissions: 2
        case .test: 3
        case .complete: 4
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                    .resizable().frame(width: 36, height: 36).accessibilityHidden(true)
                Text("MacMouseGesture").font(.headline)
                Spacer()
                Text("设置 · \(stepNumber) / 4").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            switch model.onboarding.step {
            case .welcome:
                Text("鼠标，也可以用手势").font(.title2.weight(.semibold))
                Text("按住鼠标侧键并拖动，轻松切换桌面和查看窗口。")
                    .foregroundStyle(.secondary)
                GestureMap().padding(.vertical, 12)
                Text("需要一只带侧键的鼠标。两颗侧键共用同一套手势设置。")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("开始设置") { model.onboarding.step = .permissions }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            case .permissions:
                Text("开启辅助功能权限").font(.title2.weight(.semibold))
                Text("MacMouseGesture 需要“辅助功能”权限，才能将鼠标侧键拖动转换为 macOS 系统手势。")
                    .foregroundStyle(.secondary)
                Label(model.accessibilityGranted ? "辅助功能权限已开启" : "等待开启辅助功能权限",
                      systemImage: model.accessibilityGranted ? "checkmark.circle" : "lock")
                Button("打开系统设置") { model.openAccessibility?() }
                Text("在系统设置中允许 MacMouseGesture，此页面会自动更新。")
                    .font(.callout).foregroundStyle(.secondary)
                DisclosureGroup("可选：输入监控", isExpanded: $optionalPermission) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("用于额外的鼠标兼容性诊断，未开启也可以使用手势。")
                            .font(.callout).foregroundStyle(.secondary)
                        Text(model.inputMonitoringGranted ? "输入监控已开启" : "输入监控未开启")
                        Button("打开输入监控设置") { model.openInputMonitoring?() }
                    }.padding(.top, 8)
                }
                Spacer()
                Button("继续") {
                    model.onboarding.beginTest(at: monotonicTime(), buttons: model.sideButtonCount)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(!model.accessibilityGranted)
            case .test:
                Text("测试你的鼠标侧键").font(.title2.weight(.semibold))
                Text("请按下鼠标侧键，确认能够识别后，再按住侧键拖动试试。")
                    .foregroundStyle(.secondary)
                GestureMap()
                if !model.accessibilityGranted {
                    Button("需要开启权限：打开系统设置") { model.openAccessibility?() }
                }
                if !model.config.shouldRun {
                    Button("前往鼠标映射") { model.onboardingVisible = false; model.selectedTab = .mappings }
                }
                if model.onboarding.detectedSideButton {
                    Label("已检测到侧键", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                } else if model.waitingForButton {
                    Label("尚未检测到侧键，请检查鼠标连接并换一颗侧键试试。", systemImage: "computermouse")
                        .foregroundStyle(.secondary)
                } else {
                    Label("等待侧键输入…", systemImage: "computermouse").foregroundStyle(.secondary)
                }
                Toggle("我已看到桌面或窗口随手势切换", isOn: $model.onboarding.confirmedGesture)
                if model.accessibilityGranted && model.config.shouldRun && model.status != .running {
                    Text(model.status.displayLabel).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                HStack {
                    Button("稍后设置") { model.onboardingVisible = false }
                    Spacer()
                    Button("继续") { model.onboarding.step = .complete }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .disabled(!model.onboarding.canComplete(accessibility: model.accessibilityGranted, running: model.status == .running))
                }
            case .complete:
                Image(systemName: "checkmark.circle").font(.system(size: 40)).foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("准备好了").font(.title2.weight(.semibold))
                Text("现在可以用鼠标侧键控制桌面与窗口。")
                Text("MacMouseGesture 会在菜单栏运行，随时可以打开设置。")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("开始使用") { model.finishOnboarding?() }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
            if let message = UserMessage.display(model.message) {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(30)
        .frame(minWidth: 530, minHeight: 580)
    }
}
