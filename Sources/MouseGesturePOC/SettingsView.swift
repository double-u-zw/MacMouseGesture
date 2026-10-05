import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppViewModel
    var body: some View {
        if model.onboardingVisible { OnboardingView(model: model) }
        else { MappingSettingsView(model: model) }
    }
}

struct ProductHeading: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                .resizable().frame(width: 40, height: 40).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("MacMouseGesture").font(.title2.weight(.semibold))
                Text("让普通鼠标也能使用类似触控板的系统手势")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
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
