# 0.2.0-beta.1 本地验收记录

日期：2026-09-29。产物源码 commit：`c5e1526b637eefb50d6d422991b85a1a7aa4d6ba`；版本 0.2.0 / Build 13，BetaVersion=0.2.0-beta.1。之后的验收文档提交不改变该产物源码关联。

## 构建与完整性

最终产物位于本地忽略目录：

`build/beta-preview/0.2.0-beta.1-build13-c5e1526b637eefb50d6d422991b85a1a7aa4d6ba/MacMouseGesture-0.2.0-beta.1.dmg`

SHA-256：`6c26593a51a7aa7a17d8cd2e8498f9be4ca474c21c67e756b26071a6bbab9b09`

同目录 `SHA256SUMS` 复核 PASS。DMG 只读挂载后再次检查应用与 Applications 快捷方式，镜像 checksum PASS。

- **65 regression checks / 0 failures**：保留原 58 项，新增脱敏/内存日志、锁互斥/崩溃恢复/symlink 拒绝、onboarding、权限文案 7 项。
- **6 package mutation checks PASS**：错误版本、缺 Git Commit、dirty 标记、缺 notices、缺 icon、损坏 executable 都被拒绝。
- arm64，最低 macOS 27.0；系统依赖均为系统库，无额外 rpath；plist 与用户可执行文件无 Home 绝对路径。App 离开项目目录运行。
- `codesign --verify --deep --strict` PASS；Hardened Runtime 开启、空 entitlements、既有本地自签名；没有新增例外 entitlement。
- `--probe` PASS，不投递事件；不等于真实 Dock 动画验收。
- dSYM 单独放在 `developer/`，没有装入 DMG。Swift App 与 Objective-C bridge 调试信息均验证存在。二进制与 dSYM UUID 一致：`1A79D14E-A2D7-3E5D-9C32-0CBB05653E6F`。
- 较早的 4a958cb 本地产物因符号归档不完整被本产物替代，不用于交付。

## 安装与单实例：7 项 PASS

1. 稳定 Build 12 已运行时，新 Preview 退出，不启动第二个引擎。
2. 退出稳定实例后，直接从只读挂载 DMG 启动 GUI 进程成功，无 app 父目录 poc.lock。
3. 从 DMG 复制到 `/Applications/MacMouseGesture.app` 并启动成功。
4. 从 DMG 复制到 `~/Applications/MacMouseGesture.app` 并启动成功。
5. 从非项目临时目录的带空格路径启动成功。
6. 同时启动两个安装副本，仅首个持锁进程存活，第二个正常退出。
7. 首个退出后，另一位置副本可以接管；当前留在 ~/Applications 供真人测试。

复制使用 `ditto`，并非假装已经执行 Finder 鼠标拖放。没有 Internet quarantine 的真实下载链，也没有干净用户 TCC 测试；这些仍待验收。未覆盖任何已有目标 App，未更改系统权限、登录项或安全设置。

稳定 `build/MacMouseGesture.app` 可执行文件前后 SHA-256 相同；`main` 与 `v0.1.6-build12` 仍指向原稳定提交。新 Beta 防止与先启动的旧版共存，但旧 Build 12 不认识新用户级锁；不要在 Preview 运行时反向启动旧版。

## 界面与真人边界

通过应用专属 UI 检查了欢迎页布局，以及“开始设置 → 权限 → 测试侧键”路径。当前用户权限显示已授权，测试页显示引擎运行，未有侧键输入时继续按钮禁用。没有替用户确认“我已看到手势正常工作”，也没有模拟/注入手势。

1024 源图和 16/32 资源已目视检查，完整 iconset / ICNS 与 plist 已打包。Finder、Get Info、About 的最终安装视觉确认仍待用户反馈；未录制桌面或制作虚假演示截图。

**HR-01 未关闭**：等待两颗侧键各 ← → ↑ ↓，横纵半程停顿、反向和松手；另待关闭设置仍运行、退出重开配置保留、首次授权变化/完成持久化确认。不能据 probe 或自动状态测试宣布真人 PASS。

## 公开状态

GitHub 只读查询结果：PRIVATE。未 push、未修改 visibility、未创建 Release、未上传 binary。

全部可达对象模式扫描无私钥/常见凭据/个人 Home 路径命中；仍有提交邮箱与历史公开证书指纹待隐私决定。第三方来源和 public distribution Gate 未关闭。仍为 **BLOCKED BY LICENSE CONFIRMATION**，而非 Repository Public Ready 或 Public Beta Released。
