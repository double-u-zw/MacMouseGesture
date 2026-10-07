# 贡献指南

项目自有源代码采用 [MIT License](LICENSE)。引入外部代码时，请说明来源、版本、修改范围及适用许可，并保留要求的版权与许可通知；第三方条款见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

开发环境为 macOS 27 / Apple Silicon，需安装 Xcode 命令行工具。本地签名按 [签名说明](docs/signing.md)配置自己的身份。

## 构建与验证

- `./scripts/test.sh`：运行核心、应用部件回归与拦截投递的 Bridge 合约检查。
- `./scripts/build-dev.sh`：复用 `build.sh --dev`，输出 `build/dev/MacMouseGesture.app`。
- `./scripts/build.sh`：普通本地构建，输出 `build/MacMouseGesture.app`。
- `./scripts/build-icon.sh`：从 `design/app-icon-source.png` 生成 iconset 与 ICNS。
- `./scripts/build-beta.sh`：从已提交且干净的源码隔离构建，使用当前 `Resources/Info.plist` 的版本信息，生成本地签名的 Preview、DMG、校验和及 dSYM；不上传。

自动检查不等于实体鼠标验收。涉及输入处理、连续手势或非公开 API 的修改，应提供适当回归结果及真实四方向验证范围，并明确未测环境。版本与 Build 统一维护在 `Resources/Info.plist`，不要在脚本中另建一套版本来源。

## 提交要求

提交按可审查的主题拆分，说明行为变化、验证结果与兼容边界。产品界面修改若涉及手势参数或算法，也应明确说明。代码结构见 [architecture](docs/architecture.md)，系统接口与历史来源见 [system-gesture-provenance](docs/system-gesture-provenance.md)。

不要提交 `.local-signing/`、证书私钥、钥匙串、密码、凭据、`build/`、本机原始诊断或第三方研究 checkout。不要为运行测试重置 TCC、导入别人的开发证书或改变系统安全策略。

只推送明确选定的分支或标签；仓库保留私有历史 refs 时，不使用 `git push --all` 或 `--mirror`。
