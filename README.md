<p align="center"><img src="design/app-icon-source.png" width="128" alt="MacMouseGesture App Icon"></p>

# MacMouseGesture

使用普通鼠标侧键，在 macOS 上获得类似触控板的连续系统手势。

按住任一启用的侧键并拖动：

| 方向 | 操作 |
|---|---|
| ← / → | 切换桌面空间 |
| ↑ | 调度中心 |
| ↓ | 应用 Exposé |

**0.2.0-beta.1 · Beta Preview，尚未公开发布。**

## 功能

- 两颗侧键共用四方向手势，支持停顿、继续、反向和松手结束。
- 可选择启用的侧键、横纵手势和左右方向反转，并调整手感。
- 设置保存在本机，可选登录时启动；关闭窗口后继续在菜单栏运行。
- 鼠标断连后支持有限次数自动恢复；连接稳定后仍不可用时，可在帮助页重新尝试。

启用的侧键点击会被手势占用。需要带额外侧键的鼠标。

## 下载与安装

公开后从 [GitHub Releases](https://github.com/double-u-zw/MacMouseGesture/releases) 获取安装包和校验和。当前尚无经批准的公开安装包。

1. 打开 DMG，将 MacMouseGesture 拖到“应用程序”。
2. 启动安装后的 App，按设置向导开启“辅助功能”权限。
3. 测试鼠标侧键，然后开始使用。

当前本地候选使用本地签名，尚无 Developer ID 分发签名或 Apple 公证；最终分发路线仍待确认。若系统阻止打开，请先核实来源并参考[安装说明](docs/INSTALL.md)，不要关闭系统安全保护。

## 权限

MacMouseGesture 需要“辅助功能”权限，将侧键拖动转换为系统手势。“输入监控”仅用于额外的鼠标兼容性诊断，不是基本手势的必需权限。更换应用身份或签名后可能需要重新授权。详见[权限与排错](docs/TROUBLESHOOTING.md)。

## 支持范围与 Beta 限制

目前面向 **macOS 27 / Apple Silicon**，其他系统、芯片及鼠标环境尚未充分验证。详见[兼容性记录](docs/compatibility-matrix.md)。

连续系统手势依赖 macOS **private / undocumented API**，系统更新可能导致功能失效；不承诺长期兼容性。应用 Exposé 在部分外接显示器全屏场景下可能有轻微收尾延迟。目前没有自动更新。

## 隐私

无需账户，无云同步、遥测或自动上传。设置保存在本机，诊断日志保留在内存；只有主动复制或导出时才保存诊断信息，分享前请检查内容。[隐私说明](PRIVACY.md) · [卸载说明](docs/UNINSTALL.md)。

## 反馈

请通过 [GitHub Issues](https://github.com/double-u-zw/MacMouseGesture/issues) 提交问题，注明系统版本、鼠标型号、连接方式及复现步骤。不要提供设备序列号或未经检查的诊断文件。安全问题请参阅 [SECURITY.md](SECURITY.md)。

## License / Acknowledgements

项目整体许可证尚未确定；仓库可见不代表已授予任意复制、修改或再分发许可。

早期系统手势研究参考过 Mac Mouse Fix，旧实现的历史归因保留。当前 Bridge 已按项目功能规格替换，工程来源审计未发现当前实现中的 MMF 代码派生部分；这不是法律保证。[第三方致谢](THIRD_PARTY_NOTICES.md) · [来源记录](docs/system-gesture-provenance.md)。
