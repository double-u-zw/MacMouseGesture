# 贡献指南

当前项目许可证尚在审核。在获得适用授权前，不应把仓库可见性理解为自由再分发许可；提交外部代码也需先明确来源与授权。

开发环境主要为 macOS 27 / Apple Silicon，安装 Xcode 命令行工具。

- `./scripts/test.sh`：核心与产品化自动检查，不会替代实体鼠标验收。
- `./scripts/build.sh`：常规本地构建；需按 [本地签名说明](docs/signing.md)配置自己的开发身份。
- `./scripts/build-icon.sh`：从最终源图重新生成 iconset / ICNS。
- `./scripts/build-beta.sh`：要求源码已提交，隔离构建、检查、HR 本地签名、DMG、SHA256、dSYM；不覆盖稳定 App、不上传。

不要提交 `.local-signing/`、钥匙串、私钥、密码、凭据、`build/`、原始本机诊断、第三方研究 checkout 或个人路径。不要提交别人的本地证书。不要为跑测试重置 TCC 或改变系统安全策略。

private API 兼容修改必须附自动测试和真实四方向验证范围，报告未测场景。产品化修改不得悄悄改变手势参数/算法；提交按可审查的主题拆分。
