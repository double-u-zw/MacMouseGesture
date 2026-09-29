# Beta Preview checklist

目标：0.2.0-beta.1 / Build 13。本文件区分自动检查、真人验收、公共发布 Gate。未完成项不会推定通过。

## 自动与文档

- [x] Phase 0 独立 commit；Beta 在 productization/github-beta
- [ ] build PASS（最终签名包待生成）
- [x] 原 58 项回归 + 新增 7 项产品化检查，65 / 0 failures（初轮）
- [x] diagnostics redacted：集中日志入口、报告出口、UI 错误与 probe
- [x] single instance：进程互斥、崩溃释放、symlink 拒绝自动检查
- [x] onboarding state：持久化、超时、真实新输入与确认门槛自动检查
- [x] permission state display：未授权/授权/撤销/可选状态检查
- [ ] App Icon PASS：ICNS 打包与安装视觉检查
- [ ] 两个实际 App 副本互斥 PASS
- [ ] 安装到 /Applications、~/Applications、带空格目录、只读 DMG 验收
- [ ] DMG / package metadata / negative mutation tests PASS
- [ ] SHA256 PASS
- [ ] dSYM UUID / version / build / commit 归档 PASS
- [x] README / PRIVACY / SECURITY / CONTRIBUTING
- [x] install / troubleshooting / uninstall docs
- [x] third-party notice、作者信草稿、Issue 模板

## 真人验收

- [ ] 首次启动、实时权限刷新、无侧键提示、完成后不重复欢迎
- [ ] 干净用户权限组合、撤权与恢复（PERM-01）
- [ ] Button 1: ← → ↑ ↓
- [ ] Button 2: ← → ↑ ↓
- [ ] 横纵连续、半程停顿、反向、松手正常（HR-01 待测）
- [ ] 关闭设置仍运行；退出重开配置正常
- [ ] Finder / Applications / Get Info / About 图标；Launchpad 如适用

## Public Gate（未关闭）

- [ ] PUBLIC_REPOSITORY_AUDIT：历史个人邮箱/公开指纹处理决定
- [ ] MMF license gate closed（源码与 binary 分别确认）
- [ ] Apple 头文件来源、private API 公开分发路线确认
- [ ] Bundle ID finalized 与迁移验收
- [ ] 对外签名/未公证下载体验及干净用户安装验收
- [ ] user approved publication

本地 Preview 不是 Public Beta Released。只有真人验收完成才能关闭 HR-01；不添加危险 entitlement 绕过失败。
