# 分发审计 — Developer ID、Hardened Runtime 与包装

日期：2026-09-29；范围：站外分发研究和隔离本地实验，不是发布批准。基线 0.1.6 / Build 12 保持不变。

## 私有 API 与官方分发路线：结论边界

1. [API 审计](api-audit.md)确认完整连续交互依赖 private API，不能宣称“仅使用 Apple documented API”。
2. **Mac App Store 与 Developer ID 站外分发要分开。**[App Review Guidelines 2.5.1](https://developer.apple.com/app-store/review/guidelines/#software-requirements)要求公开 API；当前后端不满足这个方向的要求。
3. 阅读 [Apple Developer Program License Agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/)时，不能只摘 §3.3.1(A)：§3.3 开头列举了适用的分发渠道；还需同时审阅 §3.2、§5.2–5.4、§7.6。§5.3 的公证安全检查与 §5.4 的撤销权不构成特定私有协议的授权。**本次证据既不足以宣布“所有站外 private API 一概禁止”，也不足以确认当前实现获准公开分发。**需要按实际签署版本进行 Apple 条款/许可复核；继续保留完整后端的站外路线是待确认选项。
4. [Apple 公证说明](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)明确公证并非 App Review，主要做恶意内容和签名问题检查。即便以后获得 ticket，也不是稳定 ABI 保证、API 使用许可或第三方版权许可。

**技术上：Hardened Runtime 没有在本次 probe 中阻止该后端。许可与发布资格：未关闭。**需要在公开分发前关闭的 P0 是“路线与使用权未确认”，不是在此宣布违法。报告不替代法律判断。

## Current Development Setup vs Public Distribution Requirement

证据：Resources/Info.plist、Resources/Entitlements.plist、scripts/signing.sh、scripts/toolchain.sh；对实际 `build/MacMouseGesture.app` 执行 codesign 检查，而非只看配置。

| 项目 | 当前实际状态 | 普通用户站外分发目标 / 差距 |
|---|---|---|
| 证书 | 自签名 RSA 本地代码签名证书；Subject=Issuer，CN `MacMouseGesture Local Development`，O `MacMouseGesture Personal Development` | Apple Developer Program 下的 Developer ID Application 证书；本地信任不随下载传播 |
| 证书有效期 | 2026-09-28 至 2036-09-25（UTC） | 有效期长不等于 Developer ID；正式密钥保管、续期与事故恢复需建立 |
| TeamIdentifier | not set | 正式 Apple 团队身份 |
| Designated Requirement | `identifier "local.macmousegesture.poc" and certificate leaf = H"<LOCAL_CERTIFICATE_SHA1>"` | 当前 leaf pin 仅适合本机；迁移 Developer ID 的 DR/TCC/更新连续性必须单独验收，不能直接沿用该证书 pin |
| Hardened Runtime | CodeDirectory flags `0x0(none)` | 正式发布开启 `runtime`；与 App Sandbox 是两种机制 |
| Entitlements | 实际导出空字典，与源文件一致 | 仅放必要 entitlement；不启用 get-task-allow；不因动态加载就禁用 library validation |
| 时间戳 | `--timestamp=none`；存在普通 Signed Time，不是 secure timestamp | 正式代码签名需安全时间戳 |
| 应用标识 | `local.macmousegesture.poc`；0.1.6 / 12；LSUIElement=true | 正式身份和迁移方案见 [product-identity.md](product-identity.md) |
| 架构 / 最低系统 | Mach-O thin arm64；deployment target 和 plist 均 27.0 | 按实际测试声明；当前不能称 universal / 26+ |
| 本机签名验证 | 正常用户上下文 `codesign --verify --deep --strict` PASS；DR PASS | 本机结构有效不代表 Gatekeeper 下载信任 |
| 公证 | 无本轮公证提交；现有流程没有 notarytool/stapler | 公证提交、日志审查、staple、验证与保留构建记录 |
| 分发形态 | 本地 build `.app`，无正式安装包 | 签名、公证的 .app/DMG，加真实下载隔离属性测试 |
| 安装路径依赖 | main.swift:38–44 在 .app 父目录创建 `poc.lock` | **P0**：只读 DMG/translocation 或不可写 Applications 父目录可能启动即退；需未来迁移用户可写锁位置并处理重复安装 |

首次沙箱内 codesign 曾显示 `CSSMERR_TP_NOT_TRUSTED`、Authority unavailable、Info.plist/entitlements 异常提示；正常用户上下文复核显示有效、Info.plist entries=11、空 entitlement。**这是本次检查上下文差异，不能据此宣称稳定签名损坏。**证书仅导出公开 DER 到忽略目录，未导出私钥，也未更改信任设置。

当前稳定 CDHash：`37a9788dbf5c1b532ebf33379ef2e4c4486e4351`。本轮实验前后可执行文件 SHA-256 完全相同；Sources、Resources、原 scripts 的 Git diff 为零。

## 官方站外发布流程（以后实施）

根据 [Developer ID](https://developer.apple.com/developer-id/)、[公证要求](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)、[自定义公证流程](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)：

1. 决定开发者主体并加入 Apple Developer Program，建立 Developer ID Application 证书及私钥保管流程。PKG 若采用 Developer ID 安装包签名，另需 Developer ID Installer；普通 .app/DMG 不为此引入 PKG。
2. 固定正式 Bundle ID、版本、架构/最低系统；先签嵌套代码，后签 app；开启 Hardened Runtime 和 secure timestamp。评估必要 entitlement，不用全开例外绕过失败。
3. 用 ZIP/UDIF DMG/受支持 flat PKG 作为提交容器。`xcrun notarytool submit … --keychain-profile … --wait`；记录 submission ID，并用 `notarytool log` 检查结果。凭证不写入脚本或 Git。
4. `xcrun stapler staple` / `validate` 对受支持的 .app/DMG/PKG 操作。ZIP 不能直接 staple：对 .app staple 后重新 ZIP，不能把第一次未附票的 ZIP 当最终归档。
5. 对最终文件做签名、公证票据和 Gatekeeper 评估；从浏览器重新下载以保留 quarantine，验证安装/首启/升级/离线首启，使用干净用户或测试机。不能用 `xattr -d`、关闭 Gatekeeper 或本地已有 TCC 授权当验收方式。

本轮未加入开发者计划、申请证书、提交软件给 Apple、改变 Apple Account、创建 Release、公开仓库或生成 DMG。

## Hardened Runtime Compatibility：隔离实验

实验时间：2026-09-29；macOS 27.0 (26A428)、Apple M5 / Mac17,3、arm64。

路径：`build/productization-experiments/MacMouseGesture-Hardened.app`。该目录被 Git 忽略。构建脚本 `build/productization-experiments/build-hardened.zsh` 只把编译对象、缓存、模块、临时文件和 bundle 写入该子目录；使用未修改 Sources 和原 plist。没有调用会覆盖稳定 app 的 build.sh。

与基线唯一的有意签名策略差异是 `codesign --options runtime`，使用原本地证书及同一 DR、`--timestamp=none`。没有传 entitlement 文件，实际没有 entitlement，未新增 `disable-library-validation` / `allow-unsigned-executable-memory` / `get-task-allow`。原稳定空 entitlement 与实验无 entitlement 的区别已记录。保持 bundle identity 只是本次实验条件，不是正式产品身份决定。

| 检查 | 结果 | 能证明什么 / 不能证明什么 |
|---|---|---|
| 独立编译 | PASS | 原源码可在本机重新构建 |
| 签名与 DR | PASS；flags=`0x10000(runtime)`；Runtime Version 27.0.0 | 确实启用 Hardened Runtime；非 Developer ID |
| 动态类/selector/符号 | PASS | 本机 Apple 私有库可加载；不等于 API 授权 |
| `--probe` 横向四 phase | PASS | 构造、附加、回读成功，没有投递 |
| `--probe` 纵向正负 progress 四 phase | PASS | 同上；probe 没有验证实际 Dock 接收和所有速度子字段的消费 |
| 权限读数 | Accessibility=true / Input Monitoring=true | 当前用户环境；不是干净用户授权验收 |
| 原 58 项回归检查 | 58 PASS / 0 FAIL | 使用独立产物路径；回归 executable 自身不是 Hardened app，不把它当全流程 HR 验收 |
| Gatekeeper `spctl --assess` | rejected，exit 3 | 本地自签名产物未成为互联网受信任发布包；不能归因于私有 API |
| 真人四方向、半程停顿、反向、松手 | **Untested** | 本轮未抢占用户稳定实例或自动发手势 |
| 稳定可执行文件哈希前后比对 | 相同 | Build 12 未覆盖 |

原始证据在同目录 `evidence/`：`hardened-signature.txt`、`hardened-probe.txt`、`regression.txt`、`stable-before.txt`、`stable-after.txt`、`stable-signature.txt`。结论是 **Partial：HR 下非注入 probe 成功，真人交互待测**。没有遇到需要危险例外 entitlement 的证据。[Apple library validation 文档](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.cs.disable-library-validation)允许 Apple 签名库通过默认校验；这一机制与加载对象是否公开 API 是不同问题。

### 真人实验运行说明（可稍后做，不是 Phase 0 自动进入下一阶段）

实验版与稳定版共享 Bundle ID/偏好，但因为不同父目录，各自 `poc.lock` **不能防止二者同时运行**。

1. 先在稳定版菜单点击“退出 MacMouseGesture”，确认其菜单图标消失。不要更改原权限或登录启动设置。
2. 在项目目录执行：

   ```sh
   open -n "$PWD/build/productization-experiments/MacMouseGesture-Hardened.app"
   ```

3. 保持已有设置，分别用两颗侧键测试四方向：半程保持 2 秒、继续、反向收回、小幅慢拖松手回弹、快速短甩完成。应用 Exposé 选择有多个窗口的应用；只在准备好的桌面进行。
4. 若授权提示或系统阻止，停在该状态记录现象，不删除稳定版权限、不 reset TCC、不关闭 Gatekeeper。probe 的 true 不保证 GUI launch 时相同。
5. 记录实验目录、运行时 flags、前后计数；诊断分享前删除 Bundle 绝对路径。异常立即退出实验版。
6. 退出实验版，再执行 `open "$PWD/build/MacMouseGesture.app"` 恢复稳定实例。不要同时运行，不要在实验版改配置/登录启动，因为它们共用身份。

## 包装方案与卸载

| 形态 | 用户安装 | 公证/更新 | 成本与建议 |
|---|---|---|---|
| DMG | 清楚展示 .app → Applications 拖放 | 可公证并 staple；Sparkle 可使用 | **未来普通用户首选**；先解决只读路径启动锁，明确从 DMG 拖出再启动 |
| ZIP | 解压后用户自己搬 app | 提交 ZIP，staple 内部 app 后重打包；更新也可用 | 适合受控 Beta/备选；容易在 Downloads 或 translocation 路径运行 |
| PKG | 系统安装向导，可能增加权限/脚本 | installer 独立签名与公证；升级/卸载更复杂 | 当前无 helper/driver，不需要；不推荐为菜单栏 app 引入 |

卸载方案（未来文档，不在本轮执行）：先关闭登录启动（SMAppService.unregister）并退出，删除 .app；用户可选择删除 `local.macmousegesture.poc` 的 UserDefaults 域（通常是 `~/Library/Preferences/local.macmousegesture.poc.plist`，系统有缓存，应通过偏好 API/适当工具管理）；删除自己保存的诊断文件。当前父目录 `poc.lock` 是额外残留，必须确保无实例持锁才清理，未来应改位置。没有发现自动写出的诊断目录或云账户数据。

Accessibility / Input Monitoring 授权由用户在系统设置管理；不修改 TCC 数据库，不写自动篡改权限的卸载器。开发用 `.local-signing/` 是本机开发身份，不属于产品卸载清理对象。

## Sparkle 2：只研究

适合未来的独立 `.app` 更新，当前没有集成。依据 [Sparkle 官方入门](https://sparkle-project.org/documentation/)与[发布更新](https://sparkle-project.org/documentation/publishing/)。现有项目靠 swiftc/clang 手工打包，新增 framework/XPC 嵌套签名、rpath 和资源复制的工作量为中等；不能只在 Package.swift 增加依赖就认为完成。

未来需：嵌入/签名 framework 与 helper，建立 updater 生命周期；配置 HTTPS appcast、`SUFeedURL`、递增 `CFBundleVersion`；保管独立 EdDSA/ed25519 私钥并在 app 放 `SUPublicEDKey`；签更新归档，生成 appcast，验收断网/损坏签名/回滚/跨版本更新。Developer ID 代码签名、公证与 Sparkle 更新签名解决不同问题，不能互相替代。

P1：先稳定产品身份与发行签名再接更新；P2：渠道、回滚运营、发布说明与自动更新体验。若未来启用联网检查，应说明更新时间/IP 等网络元数据；保持默认无遥测并另审查 Sparkle 及第三方组件许可证。本轮没有生成 EdDSA 密钥、appcast 或联网更新逻辑。
