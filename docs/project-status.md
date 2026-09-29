# MacMouseGesture 当前项目状态

更新：2026-09-29。当前安装 **0.1.6 / Build 12**，普通启动支持四方向连续系统手势；可回退基线为 **0.1.5 / Build 7**。Build 7 与 Build 6 阶段记录保留在下方作为历史验收依据。

## 0.1.6 / Build 12：纵向手势与简体中文界面

- `baselines/build7/` 全部 SHA-256 校验通过，未覆盖或修改。Build 8–10 的 `GestureMachine.swift` 与 Build 7 逐字节相同；Build 11 只为正式接入增加了纵向锁轴状态，横向进度、速度、释放算法与 HID 创建/投递方法未改。普通启动现已支持四方向。
- 显式 `--vertical-poc` 启动后，复用现有侧键输入、锁轴、120 Hz 合并和冻结指针，增加独立的“上拖 → 调度中心”候选。新桥接使用 DockSwipe motion=VerticalY，Y 轴终结速度，四阶段附加负载回读 PASS；日志明确标记 `Vertical backend: interactive HID`，没有快捷键 fallback。首次下拖在 Phase 1 明确不执行动作，反向拖动不会在同一次手势里选择新动作。
- 首次真人上拖反馈“没反应”。`build/vertical-poc-no-response.txt` 显示 Event Tap enabled、侧键和上拖输入正常、无投递失败；数次上拖的 CG `dy` 为负（如 -424、-323），却被 Build 8 初始正号假设判为 `unsupportedDown`，纵向没有发出任何帧。Build 9 只将 POC 的向上符号改为负，横向状态机和 HID payload 未改。重新编译、签名并以 `--vertical-poc` 启动，UI 显示引擎运行中和两项权限已授权；Dock 交互动画仍待真人复测，不能把这一轮静态与自动检查当作 POC PASS。
- 现有菜单栏、通用/手势/诊断/关于和权限提示的普通文案已改为简体中文，VoiceOver 控件标签跟随中文；高级诊断保留技术字段。手势页增加“恢复默认手势设置”，经原 `ConfigStore` 保存，只恢复手势参数，不改变应用启用状态或登录项。
- 开发环境逐页检查 540 × 540 窗口，通用、手势、诊断、关于中文文本没有截断；手势和诊断页用原生滚动展示底部控件。签名和指定要求验证通过；同一路径启动后的辅助功能、输入监控均显示已授权，引擎运行中。
- **Phase 1 PASS：**用户确认上拖调度中心连续展开、半程停 2 秒保持、继续跟手、反向下拖关闭、小幅慢拖松开回弹、快速短甩完成；两颗侧键各向左/右的横向手势四次均正常。Build 9 现场快照 `build/vertical-phase1-build9-pass.txt` 显示 `started=61`、`ended+cancelled=61`、`open=0`、`sequenceErrors=0`、`postFailures=0`、`eventTapRestarts=0`。此前这些行为未全部验证，现已通过。
- **Phase 2 PASS：**Build 10 下拖应用 Exposé 使用负 DockSwipe 进度和 Y 轴速度。用户在前台两个访达窗口下确认连续展开、半程停 2 秒保持、继续跟手、反向上拖关闭且未切换调度中心、小幅回弹、另一颗侧键快速下甩完成；两颗侧键横向左右四次均正常。最终快照 `build/vertical-phase2-build10-final.txt` 显示 `87 = 63 + 24`、`open=0`、`sequenceErrors=0`、`postFailures=0`、`eventTapRestarts=0`。用户反馈外接 4K/120 Hz 屏幕松手后收尾比内建屏略慢（差异不到半秒），拖动跟手正常；尚不能仅凭日志确定是速度映射还是 Dock 动画。
- **Phase 3–5 PASS：**Build 11 把两个已通过的纵向动作接入普通引擎和手势页。“启用纵向手势”开关经原 ConfigStore 持久化，首次默认开启；旧配置若关闭了唯一横向手势，迁移时保持停用。横纵共用按钮、锁轴、120 Hz 输入合并与取消路径；纵向只保留独立进度/速度和动作选择。高级诊断增加上次轴/动作及纵向开始计数。用户在普通模式确认两颗实体侧键的四方向均正常；最终快照 `build/vertical-phase5-build11-two-physical-buttons.txt` 显示 Button4/5 DOWN 为 29/216、`started=244`、`ended+cancelled=244`、`open=0`、`sequenceErrors=0`、`postFailures=0`、`eventTapRestarts=0`。纵向开关已现场关闭、恢复，并在重开后保持开启；原有 777 灵敏度、9 触发距离、反向与双键配置也保留。Build 12 只补充灵敏度作用范围说明和版本号，手势算法未改；58 项自动检查通过、0 失败，固定签名、权限与普通启动状态均已验证。
- **外接屏观察：**外接 4K/120 Hz 屏幕上，通过绿色按钮进入 macOS 全屏的窗口，下拖应用 Exposé 时偶尔有不到半秒的松手收尾延迟。用户用原生触控板做同场景对照，触控板有时也会拖延；用户认为不影响使用。目前不能归因为鼠标工具的速度映射，因此没有调整已经通过交互验收的纵向参数。若将来出现明显变慢或仅鼠标持续复现，再采集同场景对照。协议与未验证项见 [vertical-gesture-research.md](vertical-gesture-research.md)。

## 0.1.5 / Build 7：菜单栏与设置界面

- 程序以菜单栏工具启动；`LSUIElement=true`、AppKit accessory 策略，正常运行时不常驻 Dock。菜单使用模板 SF Symbol 鼠标图标，显示不可点击的状态、启停、Settings、Diagnostics、Restart、Launch at Login、About 和 Quit。状态直接映射现有配置、权限和引擎运行状态。
- 只有一个 540 × 540 Settings Window，四页 General / Gestures / Diagnostics / About。已有权限时启动不弹窗口；缺少辅助功能权限时自动显示 General 和打开系统设置入口，不主动请求授权。关闭 Settings 不会停止引擎。
- General 的 Enable 与菜单快速开关共用 `AppConfig.enabled`。Launch at Login 使用 `SMAppService.mainApp`，系统状态为准，首次保持 OFF；本轮未替用户注册登录项，待用户亲自开启。若系统要求审核，页面提供登录项设置入口。
- Gestures 展示两颗侧键的中性名称，禁止取消到零颗；Switch Spaces、Direction、Sensitivity、Activation Distance 和 Keep Pointer Still 均写入原 `ConfigStore`，没有第二套保存状态。对数灵敏度滑块精确保持默认 600，Activation Distance 默认为8。滑块防抖约220 ms，其余设置即时应用。
- Diagnostics 将系统和手势统计放在前面，原始计数、性能和最近日志置于默认折叠的 Advanced Diagnostics。复制及保存快照已接通原完整诊断；Restart 单独放在操作区。About 从 bundle 读取版本号。
- 应用主界面名称改为 MacMouseGesture；固定 Bundle ID、可执行文件路径和证书 DR 仍相同。`GestureMachine.swift`、`SystemGestureBridge.m` 以及 HID payload 与 Build 6 逐字节不变；只读 UI 计数由引擎现有计数生成。

验证：**45 项自动检查全部通过，0 失败**，含 Build 6 的40项和5项有实际意义的界面状态/设置检查。新版编译签名有效、指定要求验证通过；同一路径启动后辅助功能与输入监控均显示 Granted，横向引擎 Running。真实界面验证了双侧键不能同时取消、方向切换、灵敏度与激活距离变更、General 启停、Diagnostics 保存到 `build/MacMouseGesture-Diagnostics-Build7.txt`，并在退出重开后读回双侧键、Reversed、600/8、Freeze=true。

用户现场已确认：菜单栏可见鼠标图标，Dock 没有常驻图标；关闭 Settings 后横向手势仍可使用；菜单 Enable Gestures 切换时状态与 General 开关同步，关闭为 Disabled，重新开启为 Running；两颗侧键分别向左、向右横拖均正常；Direction 临时改为 Natural 后实际方向反转，再恢复 Reversed；Sensitivity 调向 Slow 与 Activation Distance 调向 Long 后，真实横拖手感和短距离起手均有变化，随后两个滑块已恢复；退出并从原路径重开后，双侧键、Reversed、启用状态与滑块位置都保留，手势正常。登录启动保持默认关闭，仅在用户主动开启该选项后验证。清单见 [manual-ui-test.md](manual-ui-test.md)。`baselines/build7/` 保存本轮应用、源码、测试输出与签名记录；Build 4 / 6 归档未动。本轮不重新进行 CPU、长期内存或偶发失效分析。

## 0.1.4 / Build 6：历史基线记录

## 基线与边界

**0.1.3 / Build 4 — First confirmed working horizontal gesture baseline** 永久保留为本轮回归基线。

- 历史总结：[baseline-build4.md](baseline-build4.md)。
- 原签名 `.app`、源码、SHA256SUMS 和原有检查结果：`baselines/build4/`。
- 当时此目录尚未初始化 Git；历史 Build 4 没有对应 tag。当前稳定基线另以 `v0.1.6-build12` 标记。
- `GestureMachine.swift` 与 `SystemGestureBridge.m` 已用 `cmp` 和 SHA-256 与基线核对，逐字节相同。没有改变 HID payload、phase、注入逻辑、进度、速度算法或左右方向。
- CG 正常输入路径保留，新增计数和异常中断/恢复处理。沿用 120 Hz 合并、双键最后释放结束、原死区/锁轴策略。

原 Build 4 用户反馈过偶发失效、手动重启恢复。当时记录仍有左键，没有自发停止记录，也有一段无侧键记录。原因尚未确定，不能宣称新签名解决了该现象。Build 6 本次真实验收没有复现，补充诊断和有界 Tap 恢复用于后续定位。

## Phase A：固定身份及实际升级

| 项目 | 结果 |
|---|---|
| 原签名审计 | ad-hoc、DR 绑定 cdhash；Build 3 与 Build 4 DR 不同；历史 TCC 日志明确 requirement mismatch |
| 本机原有身份 | 0 valid identities |
| 新身份 | 经用户批准创建本地代码签名证书，固定指纹 `<本机证书指纹>` |
| 系统变更 | 项目独立钥匙串；仅这张证书的当前用户 code-signing 信任；用户搜索列表恢复原值 |
| 固定项 | Bundle ID `local.macmousegesture.poc`、原项目应用路径、Executable / Name、arm64、空 entitlements |
| DR | Bundle ID + 固定 certificate leaf hash，与二进制 cdhash 解耦 |
| 更新实验 | A / B 封存版本不同、cdhash 不同、DR 相同、双向签名条件验证通过 |
| 首次迁移 | 经用户单独批准，仅执行一次本应用 Accessibility reset，再由用户授权；未重置全局或 Input Monitoring |
| 真实继承 | A 授权 → B → 编译 Build 5 → 编译 Build 6，Accessibility 均直接 true，无再次申请 |
| 最终签名 | Build 6 cdhash `15a369a4709db0cf97137d28baba1cf7a013517a`；完整签名验证通过；满足 A 的 DR |

细节和原始证据路径见 [signing.md](signing.md)。本地签名不等同于 Developer ID 公证；TeamIdentifier 仍未设置。首次迁移是一次处理，后续构建没有再次 reset。

构建入口仍为 `./scripts/build.sh`：固定证书身份，不隐式退回 ad-hoc；运行中拒绝覆盖；新 bundle 通过签名验证才安装，上一版保存在 `build/previous.*`。签名材料位于 `.local-signing/`，不应进入版本库或随 build 清理。

## Phase B：配置持久化

`AppConfig` 与 `ConfigStore` 集中处理 defaults / load / save / validation，使用 UserDefaults `gesture.configuration.v1` 字典。保存 enabled、gestureButtons（集合以保留两键）、horizontalEnabled、horizontalInvert、sensitivity、deadZone、freezePointer。没有数据库；未新增尚未暴露的 velocity/axis UI 参数。

首次默认仍为：enabled=true、双键3/4、horizontalEnabled=true、invert=true、600 pixels/progress、deadZone=8、Freeze=true。

有效设置修改自动保存、应用；文字输入 350 ms 防抖，失焦立即应用。应用设置会终止旧手势并重新开启监听，避免同一手势中途换算法参数。无效 UI 输入保持上次有效值；损坏保存值进行类型检查、clamp / fallback。停止或进入观察模式保存 enabled=false，重开不会擅自启用。

已实际通过 AppKit UI 验证：600/8 → 720/13 立即作用；⌘Q 后重新打开保留720/13；恢复600/8；停止后重开仍停用；再次开启恢复。原始记录：`build/config-ui-verification.txt`。

## Phase C：诊断与横向验收

新增：

- 累计 rawMouseEvents、coalescedFrames、gestureBegins/Changes/Ends/Cancels、eventTapRestarts 和 recoveryAttempts；跨手动引擎重启保留，退出进程清零。
- ended/cancelled 包括停止和异常取消路径；显示 open、sequenceErrors、postFailures，不靠伪造计数掩盖投递失败。
- 两颗侧键 DOWN 数、最后鼠标/侧键回调时间、Tap 状态、gestureState。
- CPU 时间差与 RSS 采样，每跨过100个终止手势保存一个 RSS 检查点，最多10个；日志仍最多300行。
- 两种 Tap disabled 回调立即释放拦截，取消旧手势一次，再尝试重新启用；每60秒最多3次，失败明确停止。按住的旧按键须先释放再重新参与。
- 每秒健康检查，捕获无回调的禁用/失效；不因鼠标安静而周期性重启。
- 修复显示配置变化后只停止、不安排恢复的问题；仍尊重手动停用及睡眠挂起。此代码缺口不是旧失效日志已确认的根因。

### 自动测试：40 PASS / 0 FAIL

原28项全保留。新增覆盖配置所有字段与跨进程保存、非法/NaN/Infinity/类型损坏、慢拖与7+2px死区、停顿2秒再拖、100/80反向与小抖动、100次双键交替和松手抖动、中断取消/释放隔离/频率上限、显示变化时的启用意图、诊断异常序列。

最终输出：`build/test-output-build6.txt`。Phase B 最初在受限沙箱内跨进程偏好写入失败；在正常用户上下文复跑33项通过，最终40项也在该上下文通过。未把受限环境失败删除或改记成功。

### 已由开发环境验证

- 编译、签名、arm64、空 entitlement、基线核心文件一致性。
- A/B 与 Build 5/6 的实际权限继承。
- 真实 UI 的即时应用、退出重启保留、停用保存。
- 真实输入期间诊断及性能数据，记录见 `build/audit-build6/`。

### 已由用户真人验证

- 半程停2秒再继续、松手：用户反馈“两项正常”。
- 两颗侧键交替20次：同上，无卡住、反向或需要重开。
- 继续连续操作：用户反馈“100 次完成，正常”。该进程从0开始累计141个完整序列，139 ended + 2 cancelled，open=0、sequenceErrors=0、postFailures=0；恢复尝试与重启数均为0。
- 计数口径说明：第二批前累计49，之后141，新增92条触发手势，与用户手动计数100不完全一致；两项事实同时保留，不补写缺失事件。累计超过100条真实完整手势的证据成立。

### 性能实测与限制

| 测量点 | 数据 |
|---|---|
| 启动首个 RSS 样本 | 85.2 MiB |
| 累计49条完整手势 | RSS 124.8 MiB |
| 跨过100条时自动检查点 | 101 completed，RSS 112.0 MiB |
| 累计141条完整手势 | RSS 112.1 MiB |
| 之后154条完整手势 | RSS 85.6 MiB；154 = 149 ended + 5 cancelled，open=0 |
| 此段采样 RSS 最大值 | 133.5 MiB |
| 真实操作时 top 的 CPU | 有效区间样本10.4%–15.5%，100%为一个CPU核心 |
| 内置采样 CPU 最大值 | 17.44%，含面板显示和启动；不是瞬时峰值 |
| 关闭面板后的后台 CPU | 最后一组有效区间样本3.1%–7.5%；前一组0.0%–7.9%，仅末段一次0.0%；每组首个 top 样本不参与结论 |
| 严格空闲 CPU | **未通过验收**：未同步确认采样期间鼠标回调计数保持不变，后台样本不能证明无输入时接近0%；不能用单次0.0%代替连续结果 |

本段 RSS 没有呈现随手势次数持续线性增长，不能据此证明长期无泄漏。top 的 MEM 与内置 RSS 不是同一指标，不直接混比。

最后两组 CPU 原始记录为 `build/audit-build6/top-idle-recheck.txt` 和 `top-idle-settled.txt`。本轮保留这一性能验收缺口，后续优先用同一时间窗的输入计数与 CPU 采样区分真正空闲、普通鼠标移动和实际手势开销，再定位热点；尚未据此认定某个模块是原因。

### 仍需用户日常/专项验证

真实睡眠与唤醒、多显示器完整场景、系统主动禁用 Tap 的现场恢复、拔插设备、极端桌面边界、全天稳定性。精确边界的自动检查已通过，但不能替代对应硬件场景。完整清单在 [manual-test.md](manual-test.md)。

## Phase D：交付状态

当时0.1.4 / Build6已构建并在原路径运行。原方向、双键、600/8/Freeze=true 配置保持；该轮没有开始 Mission Control / App Exposé，没有快捷键替代交互式后端，也没有扩展宏、滚动或窗口管理。

`baselines/build6/` 保存本轮应用、源码与文档快照、40项测试结果、签名验证及关键验收记录，并附 SHA256SUMS；签名私钥和钥匙串不包含在归档中。Build4 原归档保留。此版本的实现与已完成验证已整理，但严格空闲 CPU、完整现场边界与长期稳定性仍未全部验收。

后续使用先以此版本收集实际反馈。再次失效时，先复制诊断，再手动重新开启，以保留故障前的输入计数和状态。


### 收尾运行记录

空闲测试的一次采样发现原进程不在，未把空输出记为0%通过。系统日志确认该进程00:53:11走正常AppKit退出流程，launchd报告退出码0，没有对应崩溃报告。重新打开同一Build6后，权限与600/8配置仍在，自动Running；又观察到10段侧键手势全部ended、open=0。

最后一次读取诊断时，新进程累计16 began = 16 ended，cancelled=0、open=0、sequenceErrors=0、postFailures=0，Tap enabled；收尾进程检查仍在运行。新旧进程计数分别记录，不拼接成单进程验收数字。

该次重开后的系统“display configuration changed”通知分别触发停止与自动启动，随后的真实侧键可用；此现象验证了恢复分支，但不替代全部多屏测试。窗口自动化读取在关闭后可能重新打开面板，所以空闲性能采用关闭后的独立进程采样，避免边读UI边改变测量条件。
