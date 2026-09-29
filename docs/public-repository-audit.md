# PUBLIC_REPOSITORY_AUDIT

日期：2026-09-29；范围：本地全部可达 Git refs/commit/blob、当前跟踪及非忽略文件、提交作者/提交者元数据、图标资源。不是仅扫描 HEAD。执行工具：`scripts/audit-public.py`、`git ls-files`、`git rev-list --objects --all`、`git cat-file`、`git log --all`；原始机器结果仅放在忽略的 build/。

## 结果与边界

- 模式扫描未发现提交的私钥、钥匙串、p12、常见 GitHub/AWS token、硬编码高风险凭据或当前用户 Home 绝对路径。此扫描不证明所有可能的秘密都不存在。
- `.local-signing/`、build/、references/ 持续被 ignore；没有发现第三方完整研究 checkout 或 App/DMG 被跟踪。新增较大的 PNG/ICNS 是有意版本管理的最终设计资源。
- **历史有个人邮箱**：作者和提交者元数据使用个人邮箱，尚未取得作为公开联系信息的确认。此处不复述邮箱；公开前决定保留、脱敏历史或另建公开历史。
- **历史有本地证书公开指纹**：Phase 0 distribution-audit 曾写入 leaf pin；当前文档已替换占位符，原 commit 仍可达。这不是签名私钥，不据此自动轮换密钥或重写历史。
- 硬件型号/芯片、OS build 与测试版本是兼容性证据；未发现硬件序列号。CDHash/构建 SHA 不是设备 ID 或私钥；只保留必要技术记录。
- 第三方逐文件审计仍适用。MMF 原文对衍生来源声明与编译程序发布分别设要求；不能把 binary 限制简单等同于禁止所有源码公开，也不能跳过 Apple 头文件范围与实际发布内容复核。当前保持 **BLOCKED BY LICENSE CONFIRMATION**。

## 决策

仓库文档、资源和模板正在准备，但**尚未满足完整 Public 条件**。未改变可见性，未 push、未创建 Release、未上传二进制、未发送作者询问信。

保留 `main` / `v0.1.6-build12`；当前不做 force push/history rewrite。若决定公开保留历史，必须先确认个人邮箱/指纹披露；若要脱敏公开历史，应制定不破坏私有稳定归档的方案。任何路径仍要完成许可复核。

公开前重新运行脚本，人工复核新增文件与 commit metadata，并确认 GitHub 的私密漏洞报告功能和合适的项目许可证/权利声明。
