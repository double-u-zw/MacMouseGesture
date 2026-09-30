# Beta Preview checklist

目标：0.2.0-beta.1 / Build 14。本文件区分自动检查、真人验收、公共发布 Gate。未完成项不会推定通过。

## 自动与文档

- [x] Phase 0 独立 commit；Beta 在 productization/github-beta
- [x] build PASS：e28f25d，Hardened Runtime，自签名、空 entitlements
- [x] 原 58 项回归 + 新增 9 项产品化/恢复检查，67 / 0 failures（最终打包构建）
- [x] diagnostics redacted：集中日志入口、报告出口、UI 错误与 probe
- [x] single instance：进程互斥、崩溃释放、symlink 拒绝自动检查
- [x] onboarding state：持久化、超时、真实新输入与确认门槛自动检查
- [x] permission state display：未授权/授权/撤销/可选状态检查
- [x] App Icon 资源：1024 源图、10 个尺寸、ICNS、plist 和包内完整性检查
- [ ] App Icon 安装后的全部视觉检查
- [x] 两个实际 App 副本互斥 PASS：/Applications 与 ~/Applications，仅一个进程存活
- [x] 从 DMG 复制到 /Applications、~/Applications、带空格目录并启动；只读 DMG 直接启动
- [ ] Finder 手动拖放与干净用户下载隔离属性体验（本轮复制使用 ditto）
- [x] DMG / package metadata / 6 项负向变异测试 PASS
- [x] SHA256 PASS（具体值见 beta-validation.md）
- [x] dSYM UUID / version / build / commit 归档 PASS；Swift 和桥接调试信息存在
- [x] README / PRIVACY / SECURITY / CONTRIBUTING
- [x] install / troubleshooting / uninstall docs
- [x] third-party notice、作者信草稿、Issue 模板

## 真人验收

- [x] 实际 GUI 欢迎 → 中文权限页 → 测试页；当前用户两权限显示已授权、引擎运行、无输入时继续按钮禁用
- [ ] 实际 UI 的授权变化、12 秒无侧键提示、完成后不重复欢迎（状态逻辑已自动测试）
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

## 当前关闭结论

PRIV-01：CLOSED（集中脱敏、出口源码检查与自动测试）。INSTALL-01：CLOSED（用户级锁与 7 项实际启动/多副本检查）。HR-01：Pending human acceptance；本轮未收到真人结果，不将 probe 或输入计数当作四方向验收。详细证据边界见 [beta-validation.md](beta-validation.md)。

2026-09-30：已修复鼠标移除后永久停用，Build 14 已安装且引擎运行。用户确认此前重开能恢复；真正断连/重连自动恢复仍待真人确认。
