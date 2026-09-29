# 产品身份审计

日期：2026-09-29。仅提出方案，未改名、Bundle ID、图标、版本、登录项或偏好域。

## 名称与搜索辨识

`MacMouseGesture` 说明用途清楚，适合当前仓库/实验名称；对普通用户而言连续三个英文词偏技术、读写略长，且没有表达“连续跟手”的核心差异。

当日搜索 `MacMouseGesture mouse gesture app macOS`，发现已有 [MacGesture](https://github.com/MacGesture/MacGesture)、App Store 的 [MouseGesture](https://apps.apple.com/us/app/mousegesture/id6754866597?mt=12) 和 [MouseGestures](https://mousegestures.app/) 等近似名称。**这是搜索混淆风险，不是商标侵权结论**。未完成各地区商标、域名、App Store 名称和社交帐号可用性调查，也没有注册任何名称。

候选只是命名工作稿，均未做权利清查：

| 候选 | 优点 | 风险 / 适用 |
|---|---|---|
| MacMouseGesture（保留） | 当前认知与仓库连续 | 通用词、搜索重名，技术感强 |
| 轻划鼠标 / Qinghua Mouse | 中文容易理解、突出动作 | 英文转写长，需测试理解与重名 |
| 侧键轻划 / Sidekey Glide | 清楚说明侧键操作 | 若路线改为离散动作，“Glide”可能过度暗示连续体验 |
| 随鼠 / SuiMouse | 短、可形成品牌 | 含义需副标题解释，国际搜索需清查 |

建议先决定完整交互还是 documented 离散版本，再用短名称 + 如“鼠标侧键手势工具”的副标题。不能给失去连续动画的 fallback 版宣传“像触控板一样连续控制”。品牌选择 P2；公开前的名称冲突检查 P1。

## Bundle ID 与身份迁移（P1，若做正式首发应先完成）

当前 `local.macmousegesture.poc`、可执行名 MacMouseGesture、证书 leaf pin 都是个人开发身份。正式建议形式：`com.<owned-developer-domain>.<product>` 或对应自有域名反向 DNS 的标识。若暂时没有域名，可评估长期受控开发者命名空间，但不要占用别人的域名身份。此处占位符不是可直接写入发布构建的值。

实验/公开双版本时可计划 `…<product>.experimental` 与 `…<product>`；仅 UI 里加“实验”字样、仍使用同一 Bundle ID，不能隔离 TCC、UserDefaults、登录项和更新。

未来单独迁移任务应包含：

1. 固定开发者主体、正式 ID、Developer ID/Team ID 和路径策略；不要把旧 self-signed leaf pin 移入正式构建。
2. 偏好迁移需显式读取旧域、校验并一次性复制到新域，保留停用状态；避免两个版本相互覆盖。
3. 预期新身份可能需要重新授予 Accessibility/Input Monitoring；不能承诺权限无感继承，更不能自动改 TCC。
4. 登录项先识别旧 SMAppService 注册状态，设计用户确认迁移，防止双实例登录启动。
5. 更新身份、appcast 渠道和版本序列保持一致；明确实验版不能悄悄升级成有不同许可/体验的公开版。
6. 用干净用户、新装、旧版本升级、回退三种流程验收。

依据：[CFBundleIdentifier](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleidentifier)、[UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults)、[SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)、[Apple Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html)。迁移行为仍需实验确认，引用 API 文档不等于已经验证 TCC 继承。

## 版本路线（提案）

| 版本 | 定位 | 准入条件 |
|---|---|---|
| 0.1.6 / Build 12 | 个人稳定基线 | 保留 tag 和可恢复 app，本轮不变 |
| 0.2.0 Phase 0 | 本轮审计里程碑 | 是文档阶段名，不把实际 app 冒充升到 0.2.0 |
| 0.2.x | 产品化与内部验证 | 先关闭路线/许可问题，再做身份、签名、权限、隐私和安装改造 |
| 0.9.x | Public Beta | P0 关闭，承诺矩阵清楚，P1 具备验收证据 |
| 1.0.0 | General Release | 发布/更新/卸载可重复；稳定性和支持承诺有证据 |

CFBundleVersion 作为构建号保持递增，不用版本名称代替升级排序。不是承诺发布日期。

## 图标与品牌素材

Resources 只有 Info.plist / 空 Entitlements.plist，构建仅额外复制 THIRD_PARTY_NOTICES.md；无 icns、Asset Catalog 或 CFBundleIconFile，**没有正式 App Icon**（P2，Beta 前至少有可识别占位图标）。

菜单栏已经使用 `NSImage(systemSymbolName: "computermouse")` 且 `isTemplate=true`，不是“完全没有模板图标”。未来需验证明暗模式、屏幕缩放、VoiceOver、状态可辨识；自有正式菜单栏 template icon 可作为 P2 品牌工作。本轮没有设计 Logo。
