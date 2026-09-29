<p align="center"><img src="design/app-icon-source.png" width="128" alt="MacMouseGesture App Icon"></p>

# MacMouseGesture

让普通鼠标侧键像 Mac 触控板一样控制系统手势。

MacMouseGesture 是一个 macOS 菜单栏鼠标工具。按住任一侧键并拖动：

| 方向 | 操作 |
|---|---|
| ← / → | 连续切换桌面空间 |
| ↑ | 调度中心 |
| ↓ | 应用 Exposé |

**0.2.0-beta.1 · Early Beta · 本地 Beta Preview。尚未公开发布二进制。**
第三方许可与正式产品身份仍在审核，请勿把 Preview 当作已获准外部分发的 Public Beta。

## 功能与使用方法

支持两颗侧键，拖动过程中可以停顿、继续、反向，松手结束。启用的侧键点击会被手势占用。应用关闭设置窗口后继续在菜单栏运行；通过菜单栏进入设置、诊断或退出。没有侧键的鼠标目前不能使用核心手势。

## 演示

设置界面、菜单栏截图及短演示正在准备：[截图清单](docs/images/README.md)、[演示清单](docs/demo/README.md)。这些是素材待办，不是已录制的演示。

## 安装

当前没有可供公众下载的 Release。完成公开 Gate 后，**仅应从项目官方 GitHub Release 下载**，不要从来源不明的网站获取安装包。

将 DMG 中的 MacMouseGesture.app 拖到“应用程序”，再打开安装后的 App。无管理员安装权限时，可放到自己用户目录中的“应用程序”。

**此 Early Beta 尚未经过 Apple notarization。** macOS 可能提示无法验证开发者或无法检查恶意软件。确认来源可信且文件完整后，按 Apple 官方流程首次尝试打开，再进入“系统设置 → 隐私与安全性 → 仍要打开”。如果提示恶意软件或文件损坏，请停止并报告，不应绕过。[安装、更新及校验说明](docs/INSTALL.md)。

## 权限

首次启动会显示“欢迎 → 权限 → 测试侧键 → 完成”。辅助功能用于识别并处理鼠标侧键和拖动；输入监控用于可选的 HID 鼠标观察及诊断。授权状态会自动刷新，未检测到侧键不会显示测试成功。详见[权限和排错](docs/TROUBLESHOOTING.md)。

## 兼容性

目前主要在 **macOS 27 / Apple Silicon** 上测试，实际真人基线见[兼容性矩阵](docs/compatibility-matrix.md)。本包为 arm64、最低系统 27.0；其他芯片、系统版本及鼠标环境仍为 Untested，不承诺所有 Apple Silicon 或所有鼠标兼容。

MacMouseGesture 使用 macOS 非公开系统接口，实现连续、可逆的 Spaces / Mission Control / App Exposé 手势。系统更新可能影响兼容性。

## 已知问题

- 外接显示器全屏场景下，应用 Exposé 偶尔有轻微收尾延迟。
- 没有自动更新；更换安装位置或签名可能需要重新授权。
- 当前身份仍是开发标识，Public Beta 前需要正式迁移。
- 新 Preview 的真人四方向、首次授权及安装 UI 验收结果见 [Beta checklist](docs/beta-checklist.md)，不能用自动检查代替。

## 隐私

无需账户，无云同步、遥测或自动上传。设置保存在本机，诊断日志保留在内存；只有你主动复制或保存时才导出。分享前可预览脱敏报告。[隐私说明](PRIVACY.md)。

## 卸载

关闭登录时启动，退出菜单栏 App，删除应用即可；设置和权限可选清理。[卸载说明](docs/UNINSTALL.md)。

## 开发状态

稳定功能基线为 `v0.1.6-build12`。本轮只做产品化，保持现有四方向手势算法和参数。当前不代表 1.0、Stable 或 Production Ready。

## 技术说明与开发

[架构](docs/architecture.md) · [贡献指南](CONTRIBUTING.md) · [安全报告](SECURITY.md)。当前主要开发环境为 macOS 27 / Apple Silicon，需 Xcode 命令行工具。

```sh
./scripts/test.sh
./scripts/build.sh
# 已配置自己的本地开发签名、提交源码后，生成本地 Preview：
./scripts/build-beta.sh
```

Preview 构建不 push、不创建 Release、不改变仓库可见性、不公证；dSYM 单独归档给开发者。

## Third-party / License

**License status is under review. No project-wide license yet.** GitHub 可见性不等于可自由复制、修改或再分发。

项目参考并改写了 Noah Nuebling 的 Mac Mouse Fix 部分系统手势协议实现。MMF 使用自定义许可证，相关衍生范围与发布条件尚未确认。详见 [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)、[第三方审计](docs/third-party-audit.md)与[许可证选项](docs/license-options.md)。目前 **BLOCKED BY LICENSE CONFIRMATION**，仓库保持 Private。
