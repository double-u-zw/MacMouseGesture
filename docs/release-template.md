# MacMouseGesture 0.2.0 Beta 1（草稿，禁止自动发布）

这是早期测试版本。发布前必须关闭第三方许可、private API 分发路线、正式身份、真人验收与发布批准 Gate。当前只生成本地 Beta Preview。

## 验证范围

- 稳定功能基线：macOS 27 / Apple Silicon，两颗侧键。
- 本次 Preview 的实际自动/真人验收以 beta-checklist 为准；未完成项不得改写为 Verified。

## 使用

按住任一侧键拖动：← / → 切换桌面，↑ 调度中心，↓ 应用 Exposé。
本轮增加首次设置说明、诊断脱敏、安装位置无关单实例和正式图标；不新增鼠标功能。

## 限制

使用非公开系统手势接口，系统更新可能失效。外接显示器全屏下 App Exposé 偶尔轻微收尾延迟。其他平台与鼠标仍在验证。
此 Early Beta 尚未经过 Apple notarization；下载与系统允许流程见 INSTALL。

## 附件（发布前重新生成）

DMG 与 SHA256SUMS；不要上传 developer/ 或 dSYM。正式 Bundle ID 决定前的 Preview 不能直接改名作为公共包。
