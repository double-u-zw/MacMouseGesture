# MacMouseGesture 0.2.0 Productization Phase 0

日期：2026-09-29。审计对象：**0.1.6 / Build 12**，`v0.1.6-build12` → `e69aded137b3a8ed6dc635732fcb4926fe811ce9`。工作分支：`productization/distribution-audit`。

## Executive Summary

**当前不适合直接面向普通 Mac 用户公开分发。**主要差距不是手势功能数量，而是核心接口/来源使用权、正式分发信任链、安装位置假设、诊断隐私和验证范围。

**四方向连续手势确实依赖 private / undocumented API。**源码使用私有 `HID.framework` 的 `HIDEvent`、`SkyLight` 的 `SLEventSetIOHIDEvent` / `SLEventCopyIOHIDEvent`，以及 DockSwipe/Velocity、phase/field 编码、CGEvent type 30。公开的 CGEventTap 输入捕获与私有系统动画注入是不同层。搜索 Apple 的 CGEvent、AppKit/NSEvent/NSWorkspace、Accessibility 和 IOKit 文档及本机公开 SDK 后：**No documented equivalent found**，没有找到可完整替代 Spaces / Mission Control / App Exposé 的 continuous、interactive、reversible、progress-driven 接口。

**能否沿 Apple 官方站外路线继续？尚不能把当前实现判为“已获准公开分发”，也不能简单判为“private API 必然禁止所有站外发布”。**当前后端不满足 App Store 的公开 API 要求；Developer ID + 公证是独立的站外流程，必须结合协议适用范围及第三方许可继续复核。公证并非 App Review，也不是私有 API 授权或兼容承诺。依据：[Apple 协议](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/)、[App Review 2.5.1](https://developer.apple.com/app-store/review/guidelines/#software-requirements)、[公证说明](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)。这是技术与条款风险判断，不是法律合规/违法结论。

一个积极但有限的实验结果：**原后端在 Hardened Runtime、无额外 entitlement 下，横纵四阶段构造/附加/回读均 PASS；58 项回归检查 PASS。**真实手势注入/动画未在实验版中真人验收；实验仍用本地证书，Gatekeeper 评估 rejected，没有正式公证。

**P0 blockers**：路线及私有接口使用权未关闭；Mac Mouse Fix 衍生性/许可未关闭；未建立 Developer ID 公证信任链；诊断泄露应用绝对路径；app 父目录锁不适合只读/不可写安装环境。下一阶段先解决这五项的决策与基础改造，不再堆功能。品牌精修、正式图标细节、更多非目标平台和更新体验不是当前最先要做的事。

## 本轮交付与冻结

| 文档 | 回答的问题 |
|---|---|
| [api-audit.md](api-audit.md) | 全部系统交互 API、动态符号/selector、私有字段、公开替代搜索边界 |
| [distribution-audit.md](distribution-audit.md) | 当前签名/DR/entitlements，Developer ID/公证流程，HR隔离实验，DMG/ZIP/PKG，Sparkle与卸载 |
| [third-party-audit.md](third-party-audit.md) | 逐文件来源、MMF结构/常量对比、当前许可证、Git历史与敏感资料范围 |
| [product-identity.md](product-identity.md) | 名称候选、正式Bundle ID迁移、版本路线、图标 |
| [onboarding-audit.md](onboarding-audit.md) | 新用户安装、权限最小化、失败处理、诊断与隐私 |
| [compatibility-matrix.md](compatibility-matrix.md) | Verified/Partial/Untested/Unsupported，实际M5环境、鼠标证据缺口、Beta优先级 |

main 工作区最初干净，`git pull --ff-only` 返回 Already up to date 后创建独立分支，没有本地/远端差异、reset/force 或历史改写。`v0.1.6-build12` 是 annotated tag，tag object 与 commit hash 不同属正常，解引用后与 main/origin/main 相同。

本轮只新增这七份文档；实验、证据和参考下载放在 `build/productization-experiments/`（Git ignored）。未改 Sources、Resources、Package.swift、稳定脚本、手势算法/参数/注入、UI功能、Bundle ID 或版本。未发布、推送、创建 Release、注册证书、集成 Sparkle、实现 fallback、增加 LICENSE 或制作 DMG。Build12 可执行文件实验前后 SHA-256 相同，稳定签名复核有效。

## 风险登记与完成标准

分级：P0 = 公开分发前必须解决（包括公开二进制 Beta）；P1 = Public Beta 前应解决；P2 = 1.0前完善；P3 = 后续优化。许可 blocker 的“解决”是得到可依据的路线/权利结论，不是暗示必须删除所有现有后端。

| ID | 级别 | 发现 / 后果 | 关闭标准 |
|---|---|---|---|
| API-01 | **P0** | 四方向核心依赖私有API；Apple站外使用条款未形成针对本产品的确认 | 用户选择路线；针对实际签署协议/分发渠道完成许可复核，或公开版不包含相关私有路径；不得用公证结果代替 |
| LIC-01 | **P0** | Bridge 的DockSwipe构造结构与MMF高度对应，最小ABI还参考Apple OSS；自定义MMF License不是MIT | 明确衍生范围、所需授权/署名和可发布模式；必要时获许可或替换；校准现有notices |
| DIST-01 | **P0** | 自签名、无runtime/secure timestamp/正式公证，不构成普通下载信任链 | Developer ID签名+HR+timestamp+公证/staple，干净用户互联网下载Gatekeeper链验收；本轮未代办账户 |
| PRIV-01 | **P0** | main.swift:257 导出bundle绝对路径，可能含用户名与私人目录名 | 默认匿名化输出、分享前预览，检查所有错误日志字段；不上传原始报告 |
| INSTALL-01 | **P0** | app父目录poc.lock需要可写；不同安装目录不能互斥 | 安装位置无关的用户级单实例/锁方案；只读卷、标准用户Applications、多副本验证 |
| HR-01 | P1 | HR probe通过但未做真实四方向验收 | 独立实验真人验证，继续无例外entitlement，若失败先定位 |
| PERM-01 | P1 | Input Monitoring在源码中可选，当前两权限都开，无法证明所有目标环境最小权限 | 干净用户AX/Listen四组合、撤销/刷新/重开及拔插验证 |
| ID-01 | P1 | 开发Bundle ID与leaf pin身份；正式迁移会影响TCC/defaults/login/update | 正式主体/ID及迁移验收；在首次公开发布前确定 |
| UX-01 | P1 | 无侧键/编号不同/纵向backend退化可能被“运行中/正常”掩盖 | 首次输入测试、按能力状态和失败指导；说明侧键点击被占用 |
| COMPAT-01 | P1 | 主要只有当前27.0/M5的用户验收；两只鼠标缺逐设备证据 | 公布精确目标矩阵，按矩阵验收；不宣称所有Mac/鼠标/27+ |
| LIFE-01 | P1 | 睡眠、撤权、断连、多屏、全屏、长期稳定性仍有缺口 | 指定场景重复验收，无持续吞输入/异常重启 |
| DIAG-01 | P1 | 无Dock投递确认，架构硬编码，历史Build4文案，错误自由文本可能敏感 | 诊断准确标注证据层级、脱敏、可支持陌生用户定位 |
| UPDATE-01 | P1/P2 | 没有正式更新链；私有后端升级后失效需要可恢复分发机制 | Beta前有人工安全升级/回退流程；1.0前再按路线评估Sparkle自动更新 |
| BRAND-01 | P1/P2 | 近似产品名已存在，无正式App Icon；已有菜单栏模板SF Symbol | Beta前名称冲突初查；1.0前图标/品牌/可访问性完善 |
| SUPPORT-01 | P2 | 崩溃符号化、用户主动支持材料和卸载帮助不足 | 最小化诊断、dSYM/版本关联、删除偏好/登录项/权限的用户说明 |
| EXPAND-01 | P3 | 更多鼠标/非目标OS、Intel与广泛平台尚未验证 | 按需求与收益另立范围；若承诺这些平台则前移为P1，不能带未测承诺发布 |

## 产品路线选项（至少三条；未替用户决定）

| 路线 | 体验与可保留能力 | 分发/许可风险 | 维护/系统升级风险 | 成本与选择条件 |
|---|---|---|---|---|
| **A 保留完整 interactive private backend** | 保留跟手、停住、反向收回、终结速度与四方向体验 | 短期继续个人/非公开研究；若要站外公开，须额外关闭Apple条款与MMF授权问题，不能宣称研究标签自动豁免 | 高：私有类/字段/消费者语义可能变；probe只能查部分，OS升级前后都需真人回归 | 现有体验价值最高；需要长期适配资源。未取得充分确认前不作为已批准公开路线 |
| **B 公开版仅documented API** | 保留鼠标侧键方向识别、设置、菜单栏；未来可发离散系统快捷键 | API风险较低但仍须权限、许可、代码来源和正式签名复核；不用旧私有路径不会自动解决所有衍生问题 | 中低：公开输入合同更稳定，但系统快捷键、用户映射/冲突仍变化 | 失去连续系统动画/半程保持/反向控制；需用户接受核心体验降级。本轮不实现 |
| **C 公开版与实验版分离 / 双backend** | 公开版离散；实验版保留连续；清楚区分体验 | 公开artifact应实际剔除未批准私有代码，不是隐藏开关；实验版分发本身仍要复核，不是许可绕路 | 高：两个身份/渠道/测试矩阵和迁移；共用配置、双进程竞争需设计 | 适合同时重视产品探索和当前体验；开发/支持成本最高 |
| **D 研究其他documented architecture** | 向Apple技术支持/Feedback核实能力，或用公开API做自己的交互UI | 当前没有找到等价方案，不能先承诺原生效果 | 进度与可行性未知 | 可作为有时间盒的研究，不应作为已存在的替换方案或无限期拖延 |

**建议的决策方式**：先问“连续原生动画是否是不可退让的产品价值”。如果是，优先给A设定明确的许可/技术尽调门槛，同时保留D的限时求证；未通过前停留个人使用。若可接受离散体验，B是较直接的公开产品方向。只有愿意承担双版本成本时再选C。任何路线均须修复隐私、安装与分发信任链。

## 需要用户决定的事项

1. 完整连续动画是否必须保留？是否接受B的离散体验或C的双版本维护？
2. 是否计划公开源码、免费二进制或商业收费？这个选择直接影响MMF许可复核范围；不是由本报告默认收费/免费。
3. 是否愿意为保留后端投入权利确认/Apple条款复核与长期macOS适配？本轮没有代表用户联系Apple或MMF作者。
4. 首轮Beta是否只覆盖经验证的macOS27 Apple Silicon范围？M1–M4与两只鼠标的型号/逐设备记录仍需补全。
5. 正式开发者主体与命名空间采用什么？品牌名可稍后定，但不能在身份迁移之前开始承诺无感更新。

## 建议 Productization Phase 1（待用户选择后另行开始）

1. **先关闭路线/权利问题**：形成一页决策记录，列清发布artifact、许可依据、残余风险和退出条件；未关闭不公开仓库/二进制。
2. **独立实验补证据**：按 distribution-audit.md 的步骤真人测HR四方向；在干净测试用户/机器做最小权限与下载链验证。不给稳定版加危险entitlement，不清空其TCC。
3. **实施最小产品化改造**：诊断脱敏、安装目录无关的单实例、首次输入和权限失败指导、准确backend状态；继续冻结已验收手势行为。
4. **身份与发布管线**：用户选主体/ID后单独迁移，之后建立正式签名、公证、staple、可重复构建/归档；这些动作不在Phase0执行。
5. **有限Beta门槛**：完成声明范围内矩阵，具备升级/回退/卸载和支持说明，P0全部关闭再决定发布。Sparkle、Logo精修和扩平台后置。

Phase 0 到此停止。报告的“待验证/需复核”是审计结论和未来准入条件，不伪装成已经通过，也不自动进入下一阶段。
