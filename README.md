<p align="center"><img src="design/app-icon-source.png" width="128" alt="MacMouseGesture App Icon"></p>

# MacMouseGesture

使用普通鼠标的侧键或额外按钮，在 macOS 上获得连续系统手势，并配置短按、长按和按住按钮滚轮动作。

当前开发基线为 **0.2.0-beta.1-dev / Build 33**，面向 **macOS 27 / Apple Silicon**。

## 功能

按住已启用的按钮并拖动：

| 方向 | 操作 |
|---|---|
| ← / → | 切换桌面空间 |
| ↑ | 调度中心 |
| ↓ | 应用 Exposé |

- 连续拖动支持停顿、继续、反向和松手结束，各方向可分别启停。
- 短按、长按、按住按钮向上或向下滚动可独立映射，支持 ⌘ / ⌥ / ⌃ / ⇧ 组合。
- 通过鼠标输入和快捷键录制添加映射；左、右键保持保护。
- 设置保存在本机，可选登录时启动；关闭设置窗口后继续在菜单栏运行。

## 安装与权限

公开稳定基线为 **v0.2.0-beta.1 / Build 17**，安装包见 [GitHub Release](https://github.com/double-u-zw/MacMouseGesture/releases/tag/v0.2.0-beta.1)。当前 Build 33 是本地开发版本，新增映射能力尚未作为新 Release 发布。

将 App 放入“应用程序”，启动后按向导开启“辅助功能”并测试鼠标按钮。“输入监控”用于可选的鼠标兼容性诊断，基本手势不要求该权限。安装、更新、卸载与权限排错见 [安装说明](docs/INSTALL.md)。

连续系统手势依赖 macOS 非公开 API，系统更新可能导致功能失效。其他系统版本、Intel Mac、鼠标和多屏组合的验证范围见 [兼容性矩阵](docs/compatibility-matrix.md)。当前没有自动更新。

## 开发

需要 macOS 27、Apple Silicon 和 Xcode 命令行工具。

```sh
./scripts/test.sh
./scripts/build-dev.sh
```

开发包输出到 `build/dev/MacMouseGesture.app`；版本与 Build 来自 `Resources/Info.plist`。本地签名配置见 [签名说明](docs/signing.md)，代码结构见 [技术结构](docs/architecture.md)，其他构建入口见 [贡献指南](CONTRIBUTING.md)。自动检查不能替代真实鼠标与系统动画验收。

## 隐私、反馈与许可

无需账户，无云同步、遥测或自动上传。应用在本机处理鼠标输入，主动录制的快捷键保存到本机配置；诊断由用户主动复制或导出。详见 [隐私说明](PRIVACY.md)。

问题反馈请使用 [GitHub Issues](https://github.com/double-u-zw/MacMouseGesture/issues)，附系统版本、鼠标型号、连接方式和复现步骤。分享诊断前请检查内容。安全问题见 [SECURITY.md](SECURITY.md)。

项目自有源代码采用 [MIT License](LICENSE)。第三方来源及其独立条款见 [第三方说明](THIRD_PARTY_NOTICES.md)，当前与历史系统桥接来源见 [来源记录](docs/system-gesture-provenance.md)。图标源图及生成说明保留在 [design](design/README.md)。
