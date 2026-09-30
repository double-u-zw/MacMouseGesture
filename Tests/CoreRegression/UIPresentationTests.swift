import Foundation

struct UIPresentationTests {
    func testFriendlyStatus() {
        expectEqual(UserStatus.error.displayLabel, "系统手势暂时不可用")
        expectEqual(UserStatus.running.displayLabel, "正在运行")
        expectTrue(UserStatus.running.guidance == nil)
        expectTrue(UserStatus.permissionRequired.guidance?.contains("辅助功能") == true)
        // Do not claim physical device connectivity from the event tap state.
        expectFalse(UserStatus.recovering.displayLabel.contains("已连接"))
    }
    func testErrorsStayInDiagnostics() {
        expectEqual(UserMessage.display("无法更改登录启动设置：SMAppService internal error 42"),
                    "无法更改登录启动，请在帮助页查看诊断。")
        expectEqual(UserMessage.display("无法保存诊断快照：/private/secret.txt denied"),
                    "无法导出诊断信息，请选择其他保存位置。")
        expectEqual(UserMessage.display("鼠标连接频繁变化，自动恢复已暂停。"),
                    "鼠标连接不稳定。连接恢复后，请点击“重新尝试”。")
    }
    func testUsefulMessagesRemain() {
        expectTrue(UserMessage.display(nil) == nil)
        expectEqual(UserMessage.display("诊断信息已复制。"), "诊断信息已复制。")
        expectEqual(UserMessage.display("请先启用 MacMouseGesture 和至少一种手势。"),
                    "请先启用 MacMouseGesture 和至少一种手势。")
    }
}
