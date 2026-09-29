# Build 7 菜单栏与设置现场验收

当前安装路径：`build/MacMouseGesture.app`。本页只记录真人能确认的行为；45项自动检查和开发环境 UI 检查见 [project-status.md](project-status.md)。

1. 打开应用，确认菜单栏有鼠标图标，Dock 没有常驻图标。**用户已确认图标与 Dock 表现。**已授权时不应自动弹出设置窗；缺少辅助功能权限时应显示 General 和打开系统设置入口。
2. 从菜单栏切换 Enable Gestures，确认状态在 Running / Disabled 间变化，General 开关同步。恢复为开启。**用户已确认两次切换及同步。**
3. 从菜单栏打开 Settings，在 Gestures 中调整 Sensitivity、Activation Distance、Direction，确认横向响应立即变化；然后恢复自己喜欢的值。两颗侧键至少保留一颗。**用户已确认 Direction 切换时实际方向反转并已恢复 Reversed；两个滑块分别调整后真实手感与起手距离有变化，并已恢复。**
4. 关闭 Settings 窗口，用两颗侧键各做一次横向 Spaces 手势；再从菜单栏重新打开 Settings，确认只有一扇窗口。**用户已确认关闭窗口后手势仍可用，两颗侧键分别左右横拖均正常；单窗口行为已在开发环境验证。**
5. Quit 后重新打开，确认设置保留；两颗侧键与方向没有回归。**用户已确认配置保留且手势正常。**登录启动仅在你主动打开 Launch at Login 并完成系统审核后再测。

每次反馈1–3项即可。系统菜单栏可自动隐藏或折叠图标，若看不到请先检查菜单栏可见区域。发现问题时在 Diagnostics 复制或保存快照，再尝试 Restart Gesture Engine。
