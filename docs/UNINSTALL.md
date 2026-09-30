# 卸载 MacMouseGesture

1. 在菜单栏设置中关闭“登录时启动”，若系统要求批准或管理，请到系统设置 → 通用 → 登录项确认已关闭。
2. 在菜单栏选择“退出 MacMouseGesture”。
3. 将 MacMouseGesture.app 移到废纸篓。没有后台 helper/daemon 需要卸载。

可选清理（不是正常卸载必须步骤）：

- 在 Finder 的“前往文件夹”中进入 `~/Library/Application Support/`，确认 App 所有副本都已退出后删除 `local.macmousegesture.poc` 文件夹。这只包含运行锁；不要在 App 运行时删除锁。
- 如希望完全重新设置，在 `~/Library/Preferences/` 查找并删除 `io.github.double-u-zw.macmousegesture.plist`（如使用过旧开发版本，还可能保留 `local.macmousegesture.poc.plist`）。macOS 可能缓存偏好，退出登录再登录后确认；无需 Terminal。这些文件只应在你确实希望清除设置时删除。
- 删除你自己保存的诊断快照。应用不扫描或自动删除这些文件。
- 前往“系统设置 → 隐私与安全性 → 辅助功能 / 输入监控”自行移除或关闭对应授权。

不自动操作 TCC。旧开发版本可能在 App 旁留下 poc.lock；本版不依赖它，也不会扫描你的文件夹删除它。
