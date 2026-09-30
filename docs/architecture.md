# 技术结构

SwiftUI 设置与首次设置界面 → 配置和权限生命周期 → CGEventTap 鼠标输入 → 有界输入队列 → GestureCore 状态机 → SystemGestureBridge → macOS 系统手势。

IOHIDManager 是可选的只读鼠标观察路径，不独占设备。Escape 仅用于取消当前手势。系统桥接涉及非公开 API 与协议，详细字段和来源见 [API 审计](api-audit.md)、[第三方审计](third-party-audit.md)。

本轮不改 GestureMachine、VerticalGestureTracker、SystemGestureBridge、HID payload、progress/velocity 参数。GestureEngine 增加只读侧键计数展示；Build 14 另修复设备移除生命周期通知：先安全结束旧序列，再请求有次数上限、尊重睡眠/权限/停用意图的输入恢复。

诊断在日志入口与报告出口集中脱敏；UI/复制/保存使用同一报告。单实例使用用户 Application Support 中的 flock，先持锁再构造/启动引擎；锁随进程结束释放，不删除 inode。安装路径不参与锁身份。对同 Bundle ID 的 Build 12 等旧版本，在新版本启动时额外检测并退出；无法让旧程序反向遵守新锁，旧版必须退出后测试。
