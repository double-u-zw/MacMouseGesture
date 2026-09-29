import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("MacMouseGesture · Early Beta").font(.caption).foregroundStyle(.secondary)
            switch model.onboarding.step {
            case .welcome:
                Text("欢迎使用 MacMouseGesture").font(.title2.bold())
                Text("用鼠标侧键控制 macOS 原生手势。")
                Text("← / →   切换桌面空间\n\n↑          调度中心\n\n↓          应用 Exposé")
                Text("主要验证环境：macOS 27 / Apple Silicon。使用非公开系统接口，系统升级可能影响兼容性。")
                    .font(.callout).foregroundStyle(.secondary)
                Button("开始设置") { model.onboarding.step = .permissions }.buttonStyle(.borderedProminent)
            case .permissions:
                Text("授予权限").font(.title2.bold())
                Text("辅助功能 · \(PermissionPresentation.accessibility(model.accessibilityGranted, completed: !OnboardingState.needsWelcome()))").bold()
                Text("用于通过系统事件监听鼠标侧键、拖动并控制系统手势。")
                Button("打开辅助功能设置") { model.openAccessibility?() }
                Text("输入监控 · \(PermissionPresentation.inputMonitoring(model.inputMonitoringGranted))").bold()
                Text("用于可选的 HID 鼠标输入观察和设备诊断；未授权时仍可尝试手势。")
                Button("打开输入监控设置") { model.openInputMonitoring?() }
                Text("在系统设置中允许 MacMouseGesture。此页面会自动更新授权状态。")
                    .font(.callout).foregroundStyle(.secondary)
                Button("测试鼠标手势") {
                    model.onboarding.beginTest(at: monotonicTime(), buttons: model.sideButtonCount)
                }.disabled(!model.accessibilityGranted)
            case .test:
                Text("测试鼠标手势").font(.title2.bold())
                Text("按住任一侧键并拖动鼠标。\n← / → 切换桌面空间 · ↑ 调度中心 · ↓ 应用 Exposé")
                Text("手势引擎：\(model.status.rawValue)")
                if !model.accessibilityGranted {
                    Button("需要重新授权：打开系统设置") { model.openAccessibility?() }
                }
                if !model.config.shouldRun {
                    Button("打开手势设置以启用") { model.onboardingVisible = false; model.selectedTab = .gestures }
                }
                if model.onboarding.detectedSideButton {
                    Text("已检测到侧键输入").foregroundStyle(.green)
                    Text(model.lastSideButton).font(.callout)
                } else if model.waitingForButton {
                    Text("暂未检测到鼠标侧键。\n请确认鼠标具有额外侧键，或尝试按下其他鼠标按键。")
                        .foregroundStyle(.orange)
                } else {
                    Text("等待侧键输入…").foregroundStyle(.secondary)
                }
                Text("输入计数不能证明系统动画正常，请观察屏幕上的实际效果。")
                    .font(.callout).foregroundStyle(.secondary)
                Toggle("我已看到手势正常工作", isOn: $model.onboarding.confirmedGesture)
                Button("继续") { model.onboarding.step = .complete }
                    .disabled(!model.onboarding.canComplete(accessibility: model.accessibilityGranted, running: model.status == .running))
                Button("稍后测试（不标记完成）") { model.onboardingVisible = false }
            case .complete:
                Text("设置完成").font(.title2.bold())
                Text("MacMouseGesture 会继续在菜单栏运行。\n以后可以通过“菜单栏 → 设置”调整配置。")
                Button("完成") { model.finishOnboarding?() }.buttonStyle(.borderedProminent)
            }
            if let message = model.message { Text(message).font(.callout).foregroundStyle(.orange) }
            Spacer(minLength: 0)
        }.padding(30).frame(minWidth: 510, minHeight: 500)
    }
}
