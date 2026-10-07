<p align="center"><img src="design/app-icon-source.png" width="128" alt="MacMouseGesture App Icon"></p>

# MacMouseGesture

使用普通鼠标的侧键或额外按钮，在 macOS 上获得连续系统手势，并配置短按、长按和按住按钮滚轮动作。

面向 **macOS 27 / Apple Silicon**。

本页介绍当前源码；公开 [v0.2.0-beta.1](https://github.com/double-u-zw/MacMouseGesture/releases/tag/v0.2.0-beta.1) 尚未包含全部映射功能。

## 基本使用

在设置中添加映射，录制鼠标按钮，再选择操作方式和执行动作。连续拖动使用“触控板式手势”分组，各方向可单独启停。

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

1. 从 [GitHub Releases](https://github.com/double-u-zw/MacMouseGesture/releases) 下载 DMG；在下载目录可用 `shasum -a 256 -c SHA256SUMS` 校验同版本文件。
2. 将 App 拖到“应用程序”，推出 DMG，再启动。公开包使用本地签名，未经 Apple 公证；确认来源后按 [Apple 打开 App 指南](https://support.apple.com/102445)处理系统提示。
3. 在“系统设置 → 隐私与安全性 → 辅助功能”授权当前 App，回到设置测试按钮。“输入监控”用于可选的鼠标兼容诊断，应用未将其设为基本手势的启动条件；干净用户的最小权限组合尚未完整验证。

更新前从菜单栏退出 App，再替换同一位置的文件；签名身份或位置变化可能需要重新授权。没有自动更新，请勿同时运行多个副本。从旧版更新时，先关闭旧版的登录启动，再按需开启新版。新版映射格式可能不兼容旧版，回退前备份设置。

卸载时关闭“登录时启动”，退出 App 并移到废纸篓，无需卸载后台 helper。若要清除设置，退出所有实例后运行 `defaults delete io.github.double-u-zw.macmousegesture`；使用过旧版时还需清除 `local.macmousegesture.poc` 偏好域，否则重装可能再次导入旧设置。可选清理运行锁目录 `~/Library/Application Support/local.macmousegesture.poc/`，并在系统设置移除相关授权。

### 常见问题

- **按钮未响应**：确认 App 和映射已启用，在录制器测试按钮。厂商驱动若将侧键转换为键盘事件或合并编号，应用无法恢复原始按钮身份。
- **权限或服务异常**：确认授权的是当前运行副本；需要时退出并重新打开。先在“设置 → 帮助”复制诊断，再到“运行状态”点“重新尝试”。不要删除运行中实例的锁文件。
- **关闭窗口后仍在运行**：这是菜单栏应用，请使用菜单中的“退出”。

## 已知限制

- 连续系统手势依赖 macOS 非公开接口，系统更新可能导致失效。当前构建仅支持 macOS 27 / Apple Silicon；其他机型、鼠标驱动、连接方式、多屏及长时间运行尚未全面验证。外接高刷新率屏幕的全屏应用 Exposé 偶有短暂收尾延迟。
- 窗口动作取决于目标应用的辅助功能支持；“返回”仅对 Chrome 验证，Finder 的该返回路径在现有验证中失败，Safari 尚未验证。新建文件夹仅作用于前台 Finder 的当前目录。
- 系统可能先截获快捷键，例如 ⇧⌘4 无法正常录制。额外按钮需由设备独立报告；左、右主键受保护，映射全局生效，没有按应用或设备的配置、宏或映射导入导出。
- 按住按钮滚轮的 40 ms 限速可能丢失快速刻度，连续滚动阈值尚未充分校准；按住鼠标时也可能接收到触控板滚动，当前不能可靠区分设备来源。
- 仓库源码可能包含尚未发布的功能。自动测试与事件提交成功不能证明系统动画或目标应用已响应。

## 开发

需要 macOS 27、Apple Silicon 和 Xcode 命令行工具。构建要求固定的代码签名身份，指纹存于本机 `.local-signing/identity.sha1`；缺失时停止，不自动退回 ad-hoc 签名。已有证书可用 `security find-identity -v -p codesigning` 查看。

没有签名身份时，可运行 `./scripts/setup-local-signing.sh --approved`：它创建项目独立钥匙串和本地证书，只增加该证书的当前用户代码签名信任，恢复原钥匙串搜索列表，不改变默认钥匙串；已有 `.local-signing/` 时拒绝覆盖。请保留本机签名材料，不提交证书、私钥或密码。

```sh
./scripts/test.sh
./scripts/build-dev.sh
codesign --verify --deep --strict build/dev/MacMouseGesture.app
```

开发包输出到 `build/dev/MacMouseGesture.app`；版本与 Build 来自 `Resources/Info.plist`。请先退出目标 App 再重新构建，构建会拒绝覆盖正在运行的目标包。

- `./scripts/build.sh`：普通本地构建，输出 `build/MacMouseGesture.app`。
- `./scripts/build-icon.sh`：从 [图标源 PNG](design/app-icon-source.png) 生成 iconset 与 ICNS。
- `./scripts/build-beta.sh`：从干净、已提交的源码隔离构建，生成本地签名 App、DMG、校验和与 dSYM，不上传；本地签名不等于 Developer ID 分发签名或 Apple 公证。

代码结构见 [architecture](docs/architecture.md)，系统接口与许可边界见 [system-gesture-provenance](docs/system-gesture-provenance.md)。修改输入或手势行为时，请运行回归测试并说明真实设备验证范围。引入外部代码时保留来源和许可通知；不要提交本机诊断或构建产物。推送明确选定的分支或标签，避免用 `git push --all` 或 `--mirror` 发布保留的私有历史 refs。

## 隐私、反馈与许可

无需账户，无云同步、遥测或自动上传。应用在本机处理鼠标输入，主动录制的快捷键保存到本机配置；诊断由用户主动复制或导出。详见 [隐私说明](PRIVACY.md)。

问题反馈请使用 [GitHub Issues](https://github.com/double-u-zw/MacMouseGesture/issues)，附应用版本、系统版本、鼠标型号、连接方式和复现步骤。分享诊断前请检查内容，勿公开私人路径、序列号、密码或其他敏感信息。

项目自有源代码采用 [MIT License](LICENSE)。第三方归因和许可边界见 [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)。
