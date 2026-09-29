# 安装、更新与校验

0.2.0-beta.1 是 Early Beta / Beta Preview Artifact。当前仅本地验收，尚未批准公开下载；许可、正式 Bundle ID 和发布 Gate 关闭后才会提供公共包。

## 安装

1. 未来仅从项目官方 GitHub Release 获取 DMG 和同一版本 SHA256SUMS；当前没有公开 Release。来源不明的副本不要打开。
2. 双击 DMG，将 MacMouseGesture.app 拖到 Applications 快捷方式。也可在 Finder 打开“个人”文件夹，创建或进入“应用程序”文件夹后拖入。
3. 推出 DMG，打开已安装 App。它是菜单栏应用，不需要 Dock 常驻。
4. 按欢迎页说明授权并测试侧键。不要从 DMG 长期运行；误启动时会显示搬到应用程序的建议，不会自行复制 App。

此 Early Beta 尚未经过 Apple notarization，也没有 Developer ID 分发身份。macOS 可能提示无法验证开发者或无法检查恶意软件。确认可信来源和完整性后，先尝试打开，再到“系统设置 → 隐私与安全性 → 仍要打开”确认。遵循 [Apple 官方指南](https://support.apple.com/102445)。若没有允许按钮、提示恶意软件或文件损坏，请停止并报告；不要降低系统安全设置。

安装不需要 Terminal、管理员命令、开发证书、信任根证书或导入钥匙串。组织管理的 Mac 可能禁止用户覆盖，需遵循所在组织政策。

## 可选完整性校验

SHA256SUMS 为对应 DMG 提供 SHA-256；应与同一官方 Release 的值比对。可用已有可信校验工具。熟悉终端的用户可在两个下载文件所在目录执行 `shasum -a 256 -c SHA256SUMS`。校验是可选技术检查，不是日常安装前提；它不能替代可信来源或 Apple 公证。

## 更新与回退

退出当前 App，将新版本放到相同位置后打开；不要同时保留多个运行副本。本 Preview 没有自动更新。若身份/签名变化，macOS 可能要求重新授权。正式 Bundle ID 尚未决定，不能保证此 Preview 设置和权限无感迁移。保留可信旧安装包便于回退，回退前退出新版本；不要删除旧版权限来强制解决新版本问题。
