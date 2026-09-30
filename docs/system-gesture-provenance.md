# Current implementation — Build 15 replacement

2026-09-30：`CURRENT_IMPLEMENTATION_MMF_DERIVATIVE_NOT_PRESENT`，仅为当前源码树的工程来源判断，不是法律保证或从未接触 MMF 的声明。

本次先建立 [功能规格](system-gesture-bridge-spec.md)，再固定本项目 C API 的行为契约（旧实现黑盒 12/12），随后替换同一 `.m` 中的全部构造实现。实施期间没有重新打开 MMF 或 MIT 比较项目源码，也没有阅读旧构造函数作为编码模板。

新的 `SystemGestureEventBuilder` 由无状态请求描述、完整对象集分配、统一字段应用和最终封装四步组成。来源是公开 C 接口、Swift 调用参数、既有测试和运行行为、已登记的 ABI/协议数值及系统原生对象回读。不是旧函数改名、抽 helper 或机械重排。`createEvent` / `createVerticalEvent` 旧主体均已删除，无源码备份、注释块或 dead code 进入当前树。

当前构造代码分类 E（项目规格实现）；必要协议/ABI 事实保持 D，不声称本项目发明协议。四个 C entry points、所有 Swift 源文件及 Build 14 断连恢复代码未改变。实现者曾参与前轮研究，因此不声称法律意义的隔离 clean-room。当前未发现其他 MMF 代码派生块的依据承接下方历史逐文件审计，未以相似度扫描冒充独立创作证明。

自动验证：原有 67/67 + 新增 Bridge 15/15，通过；原生字段容差 1e-4，覆盖量化误差而非字节 golden。测试拦截投递，不操作 Dock。隔离 Build 15 编译通过；最终包和真人验收见 [Build 15 验证](build15-validation.md)。历史源码和 Build 14 二进制不在本结论覆盖范围内。

`PRIVATE_API_DEPENDENCY_REMAINS` / `NO_DOCUMENTED_EQUIVALENT_FOUND`。Apple 条款与声明来源审查保持独立；项目整体许可未选定。

---

# Historical audit — Build 14 (preserved)

以下“当前”“本轮”仅指替换前 `856891d` 审计快照，不代表 Build 15。

# System gesture provenance — Gate A

审计日期：2026-09-30；本项目 `856891d3bc50cf09518f0c5d838f57d86ae0417c`，0.2.0-beta.1 / Build 14。本轮仅阅读、比较和制定方案，没有修改运行代码。

## 结论与证据强度

**MMF_DERIVATIVE_PRESENT**：按工程来源登记，`SystemGestureBridge.m` 的两段 DockSwipe 构造流程归为 **STRUCTURAL_DERIVATIVE**。这不是法院意义上的版权衍生作品认定。协议事实、必需 ABI 名称、通用调用相同本身不足以证明受保护表达被复制；若需要据此决定版权边界，标记 `LEGAL_INTERPRETATION_REQUIRED`。

关键证据是组合证据，而非名字相似：

1. `docs/research.md` 明确记录开发前逐文件阅读 MMF 的 TouchSimulator、FixDockSwipes、CGEventHIDEventBridge 和 ModifiedDragOutputThreeFingerSwipe；`docs/vertical-gesture-research.md` 明确从 MMF 横纵构造路径取证。只有一个包含这些实现的初始 Git 提交，不能重建更早的创作过程。
2. 本项目 `createEvent` / `createVerticalEvent` 的构造组织，与 MMF `TouchSimulator.m:196–220` 对应：DockSwipe 对象、phase options、motion/flavor/progress、仅 terminal 阶段创建 Velocity 子事件、CG type 30 外壳。附件符号路径对应 MMF `FixDockSwipes.m:263–304`。
3. 有具体独立差异：本项目使用当前单调时间、轴向独立速度、符号与 selector 检查、无投递回读 probe、独立 Swift 状态机；不含 MMF 固定内存偏移写入、legacy 字段生成、屏幕归一化、拟合速度库或延时重复 end。这些差异限制归因范围，但不会自动抹去构造流程来源。

未找到可认定为 EXACT_COPY 的完整函数/文件，也未找到仅重命名/翻译构成 MODIFIED_COPY 的充分证据。归一化去空白、长度至少 20 字符的连续四行比较：749 个 MMF 源文件对当前 21 个本项目源文件，0 个匹配窗口。该筛查不能发现所有改写，更不能证明原创。

旧研究文档中“没有复制实现”的表述应理解为未整文件搬运，不能作为来源独立的证明；本报告的逐段判断优先于旧笼统表述。

## 固定来源

| 来源 | 固定版本和位置 | 本轮核实 |
|---|---|---|
| 本项目 | HEAD `856891d…`；Bridge 自 `e69aded…` 起仅一个 blob 版本 | 当前源码与初始归档中的 Bridge 相同 |
| MMF 研究时快照 | `a7ac3ecc86acf4ddb309ce1007472439a2f9d42a` | 本地忽略目录 `references/mac-mouse-fix` |
| MMF 当前官方 master | [2b5a82b96f6df8b4bdba18a666e1183da7cf24db](https://github.com/noah-nuebling/mac-mouse-fix/tree/2b5a82b96f6df8b4bdba18a666e1183da7cf24db)，API 返回提交时间 2026-09-29T22:21:47Z | License、TouchSimulator.m、FixDockSwipes.m 与研究快照逐字节相同 |
| MIT 比较项目 | [timmyagentic/mac-mouse-fix-macos-27-fix@9cf987ef070707fd8651475f78223403fca34ce6](https://github.com/timmyagentic/mac-mouse-fix-macos-27-fix/tree/9cf987ef070707fd8651475f78223403fca34ce6)，提交时间 2026-07-19T05:12:36Z | 阅读 `src/main.m`、LICENSE、README 及其引用的 4 个 MMF PR |
| Apple 接口来源 | [IOHIDFamily-1633.120.12](https://github.com/apple-oss-distributions/IOHIDFamily/tree/IOHIDFamily-1633.120.12)，IOHIDEventTypes.h / IOHIDEventFieldDefs.h / HIDEvent.h | 本项目研究记录和本地 Apple 头文件；未把整份头文件编进产品 |

本轮只读下载存于忽略目录 `build/provenance-audit-20260930/`；其中有 API 元数据、原始来源、关键词清单和比较结果。源码未加入本项目构建或跟踪文件。MMF License SHA256：`d5bee2d51b1dce8e3afb19ae200c4f60d076e8eb9ab1ba371b742067e6511c5a`；MIT main.m SHA256：`cd119e9f19b4072f6a8a26db1a30ed37044172d72652a9bb8c8a3ee9e19cc15c`。

## 运行路径与历史边界

运行链为 `CGEventTapBackend → InputMailbox → GestureEngine → GestureMachine / VerticalGestureTracker → MacOS27GestureBackend → MGPostHorizontal / MGPostVertical → HIDEvent + SkyLight → CGEventPost`。

`Package.swift`、`scripts/toolchain.sh`、`scripts/build.sh` 和 `scripts/compile-preview.sh` 都使用当前 Bridge。名称含 POC 的文件、`.missionControlPOC`、`.cgInput`、`.hidInput` 仍是可达运行模式，不能因名称旧就当作不参与产品的历史文件。HIDInputBackend 仅观察硬件，不注入 Dock 手势。

全部 12 个可达提交逐 tree 检查：**没有只存在于历史而已从 HEAD 删除的文件路径**；`git log --all --diff-filter=D` 无删除记录。旧代码是同路径旧 blob，不是另一套遗留 Bridge；当前 Bridge 从初始提交起未改变。`references/` 的 MMF/Apple 源文件和 `build/` 的旧二进制仅为忽略的本地研究/产物，不属于 Git 历史或构建输入。`baselines/` 是说明、校验和、测试输出，不是另一份源代码实现。

## 分类约定

A = EXACT_COPY；B = MODIFIED_COPY；C = STRUCTURAL_DERIVATIVE；D = IDEA_ONLY；E = INDEPENDENT。

E 表示在本轮可取得的源码、API 来源、研究记录和对照中支持独立实现的判断；不声称已证明作者从未接触任何相似代码。D 表示技术思路/协议事实有外部来源，不将功能相同自动升级为 C。C 是保守的工程来源分类，受保护表达范围另需解释。

### SystemGestureBridge 逐段登记

上游位置：MMF [TouchSimulator.m](https://github.com/noah-nuebling/mac-mouse-fix/blob/2b5a82b96f6df8b4bdba18a666e1183da7cf24db/Helper/Core/Touch/TouchSimulator.m#L196)、[FixDockSwipes.m](https://github.com/noah-nuebling/mac-mouse-fix/blob/2b5a82b96f6df8b4bdba18a666e1183da7cf24db/Tests/FixDockSwipes.m#L263)。本项目行号相对当前 HEAD。

| 本项目片段 | 分类 | 证据及范围 |
|---|---|---|
| `SystemGestureBridge.m:11–21`，`MGHIDContract` 的 initWithType、setOptions/options/type、整数/浮点 set/get、appendEvent 声明 | D（对 MMF）；Apple 声明表达范围待解释 | selector/签名由系统 ABI 约束，研究明确用 Apple HIDEvent 接口核对；未复制完整头文件、Apple 原注释或实现。不要为去 MMF 而把它自动称为 Apple 许可已结清 |
| `:23–24`，AttachFunction / CopyFunction typedef | D | 对私有系统符号的最小调用签名；同名并非 MMF 独有表达 |
| `:25–29`，class/function pointers、ready、failure 状态 | E | 本项目 once-loader 和故障报告存储，未发现 MMF 特有结构 |
| `:30–32`，Dock/Velocity/Motion/Progress/Flavor enum；motion 1/2、flavor 3、phase shift 24 | D | Apple OSS 类型/field 编码和 runtime 协议事实；常量组合进入下方 C 流程，但数字本身不等同受保护算法 |
| `:34–62`，loadAPI | D（加载思路）+ E（防护实现） | SLEvent 路线来自 MMF 实验；本项目独立 dlopen 三库、动态类/9 个 selector 检查、macOS gate、失败消息。未复制 MMF 的内存偏移 attach 实现 |
| `:64–86`，createEvent | C | 研究记录 + TouchSimulator 的 payload 组装顺序及 terminal child 对应；时间戳、按轴速度与外壳标记是本项目差异 |
| `:88–114`，MGBackendProbe | E（测试组织）/依赖 C builder | 四 phase、不投递、附加后回读逐字段、释放 CF 对象；是本项目启动契约测试，不能单独让被测构造器变独立 |
| `:116–130`，MGPostHorizontal | E（参数校验、包装、异常处理）/依赖 C builder | 有限数和 phase 集合检查、CGEventPost、CFRelease 是包装层；公开投递 API 并非私有协议授权 |
| `:134–156`，createVerticalEvent | C | 从上述构造和 MMF 纵向路径扩展；Motion=2、Y 速度独立、X=0 是项目选择 |
| `:158–186`，MGVerticalProbe | E（测试组织）/依赖 C builder | 正负 progress、四 phase、Motion=2 回读，无投递 |
| `:188–202`，MGPostVertical | E（包装）/依赖 C builder | 与横向相同校验/释放约束，调用纵向构造器 |
| `include/SystemGestureBridge.h`，MGBackendProbe/MGPostHorizontal/MGVerticalProbe/MGPostVertical | E | 自有 C ABI，公开输入是 phase/progress/velocity，不含 MMF 类型 |
| `include/module.modulemap` | E | 项目模块名与标准 Clang module 语法 |

### 输入、状态与编排

| 文件 / 类型 / 函数组 | 分类 | 依据 |
|---|---|---|
| GestureMachine.swift：MouseButton、init(cgNumber:)/name | E | CG 公共按钮编号映射；不是 MMF 专有映射表 |
| 同文件：GestureConfig；GestureState；GestureFrame/init | E | 本项目参数、纯值状态和 C ABI 输入；协议 phase 定义单独见下一行 |
| 同文件：GesturePhase raw values 1/2/4/8 | D | HID phase 协议常量，有 Apple OSS 来源；不是自创数值 |
| 同文件：VelocityTracker/init/add/velocity | E | 有界 24 样本、100ms 窗口、75ms 停顿失效、首尾差分；未发现 MMF 曲线拟合/Polynomial Regression 实现被采用 |
| 同文件：GestureMachine/init/down/move/frame/finish/progress/active | D（体验与 phase 思路）；E（状态机实现） | 独立累计器、死区/锁轴/terminal 规则；MMF 使用另一套 drag 输出/屏幕缩放/延时 end。历史研究直接说明这些项目选择，不能仅因功能同为 swipe 判 C |
| VerticalGestureTracker.swift：VerticalGestureAction；init/down/move/frame/finish；signedProgress/progress/hasOpenGesture | D（MMF motion/sign 研究）；E（状态与阈值实现） | 逐次固定 MC/Exposé、按动作裁剪 progress、独立 300 比例和本机反向实测记录；不是翻译 MMF TouchSimulator |
| MouseInput.swift：InputRecord；InputTiming/observe/summary | E | 自有事件数据类型与不信任外来 timestamp 的安全计时 |
| 同文件：InputMailbox/init/capture/drain/wake | D（合并思路）；E（实现） | research 引用 MMF PR #2025 的合并想法；具体为 256 段有界队列、相邻 motion 合并、双键 Set 仲裁和边沿唤醒，无上游源码块对应 |
| 同文件：cancel/interruptForTapRecovery/resumeAfterTapRecovery/stop/counts/stats | E | 本项目 fail-open、等待松键、恢复状态与计数；不是 Dock payload 构造 |
| 同文件：CGEventTapBackend/init/start/health/reenable/stop | E | 公开 CoreGraphics tap + CFRunLoop；相同 Apple 调用不构成 MMF 来源证据 |
| HIDInputBackend.swift：init/start/receive/snapshot/stop、回调 | E | 公开 IOHIDManager 与硬件 usage 观察；不实现 IOHID 私有注入，不复制 MMF 整体设备层 |
| GestureEngine.swift：SystemGestureBackend；MacOS27GestureBackend/init/send/probeVertical/sendVertical | E / 调用 C Bridge | 本项目后端接口与参数转发；其产品功能仍依赖被调用 Bridge |
| 同文件：Experiment、PostingAxis；GestureEngine/start/startTimer/drainInput/tick/verticalAxisLocked/send | D（120Hz 合并/连续 phase 思路）；E（串行编排） | 独立 timer、边沿处理、横纵分发；未采用 MMF 延时重复 terminal 或旧系统 fallback |
| 同文件：uiSnapshot/onboardingInput/diagnosticsSnapshot/setStatus/stop/shutdown/startHealthMonitor/recoverTap/logVerticalSelection/reportGesture/stopOnQueue | E | 本项目状态、取消、权限和恢复路径；不包含上游手势构造代码 |
| AutoStartState.swift、RuntimeMetrics.swift（生命周期、counter、TapRecoveryBudget） | E | 本项目停用/休眠/权限意图、有界恢复与序列计数；实际运行的辅助代码，虽非关键词主命中仍纳入 |
| AppConfig.swift 的 AppConfig/ConfigStore；main.swift 的后端/模式选择与启动接线 | E | 自有配置和生命周期；引用本项目类型不会让整文件成为 MMF 改写 |
| OnboardingView.swift、SettingsView.swift 的动作名/设置绑定；DiagnosticRedactor.swift 的技术词匹配 | E | 关键词属于 UI/脱敏文本，并非系统手势实现；本轮未重新审计 UI/隐私 |

### 测试、构建和研究文件

`Tests/CoreRegression/GestureMachineTests.swift`、`InputPipelineTests.swift`、`BoundaryTests.swift`、`MissionControlPOCTests.swift` 的测试类、合成 CGEvent helper、pump 和所有 `test*` 函数为 E（针对项目状态/队列契约），涉及 HID raw phase/协议断言为 D。两个 `test…HID…/testPrivateBridge…` probe 测试调用当前 C Bridge，不能作为新的独立实现证据。`ConfigTests.swift` 的关键词 Exposed、`main.swift` 的 test labels 是语义相关/文本命中，不是注入实现。`ProductizationTests.testDeviceRemovalRecovery`、AutoStartTests 为 E 的生命周期验收补充。

`Package.swift` 与脚本是 E 的构建配置；`test.sh` 把 Tests 编译到专用回归 executable，不编入 App。`docs/research.md`、`vertical-gesture-research.md` 是原始来源记录，其它 docs 和 baselines 是描述/历史证据，不是被编译的替代后端。下面附全部关键词文件清单，避免把 UI 文案和测试误报成实现。

## MIT 项目比较及许可证链

仓库：[timmyagentic/mac-mouse-fix-macos-27-fix](https://github.com/timmyagentic/mac-mouse-fix-macos-27-fix)。候选源文件：[src/main.m（固定提交）](https://github.com/timmyagentic/mac-mouse-fix-macos-27-fix/blob/9cf987ef070707fd8651475f78223403fca34ce6/src/main.m)。[LICENSE](https://github.com/timmyagentic/mac-mouse-fix-macos-27-fix/blob/9cf987ef070707fd8651475f78223403fca34ce6/LICENSE) 确为 MIT，版权声明为 `Copyright (c) 2026 Timmy ZHOU`；若采用其代码/实质部分，应保留该版权声明及完整 MIT 许可通知。MIT 不强制另建名为 NOTICE 的文件；可在第三方许可证目录保留全文并在源码及随包 notices 明确来源和修改。

| 范围 | MMF 官方 | MIT companion | 当前 MacMouseGesture / 来源判断 |
|---|---|---|---|
| payload 生成 | TouchSimulator 创建新 DockSwipe 与 CG 外壳 | `MMFAttachDockSwipePayload:208–283` 读取已有 legacy CG 字段后补 payload | 当前由自己的 progress/velocity 创建新事件；流程和原始研究证据更接近 MMF 生成器 |
| attach | 正式 Bridge 原有内存偏移；实验 FixDockSwipes 用 SLEvent | `MMFLoadPrivateAPIs:172–185` 动态解析 SLEvent | 当前也用 dlsym；此通用替代方式不证明抄 MIT，更不证明独立于 MMF 研究 |
| 时间/速度 | HID timestamp=0；terminal X/Y 同速度 | 保留输入 timestamp；读 legacy X/Y 并统一方向 | 当前 HID 当前 mach time、CG 当前 uptime ns，横向只 X、纵向只 Y；不能直接搬 MIT 而声称行为不变 |
| 运行架构 | MMF 全应用 | 修补 MMF 既有事件、event-tap 回调内附加、幂等跳过 | 当前独立侧键捕获/Swift 状态机/新事件投递；没有 MMF 运行依赖 |
| readback/self-test | 实验有读取与比较 | 有完整 round-trip/self-test | 当前自有四 phase probes，通用测试形态的相同不足以追认 MIT 来源 |

MIT README:411–424 明确关联 MMF PR [#1916](https://github.com/noah-nuebling/mac-mouse-fix/pull/1916)、[#1920](https://github.com/noah-nuebling/mac-mouse-fix/pull/1920)、[#1924](https://github.com/noah-nuebling/mac-mouse-fix/pull/1924)、[#1936](https://github.com/noah-nuebling/mac-mouse-fix/pull/1936)。前三者修改 MMF 原 bridge；#1936 是同一 MIT 项目作者提交的修复，说明了 companion 实验和向 MMF 回传的改动。

这证明技术研究相连，**不证明 MIT 作者侵权，也不证明其所有代码都来自 MMF**。但现有资料未逐段声明 payload 生成表达的独立创作边界，因此不能凭 MIT 标签给当前已有 C 片段换许可证。当前仓库在本轮前没有该 MIT 项目的来源记录；相似的局部写法不能倒推“当前代码其实来自 MIT”。若以后复用，先取得候选片段的来源说明；只抽取明确有权按 MIT 提供的部分。

## MMF 许可：源码与二进制分别判断

证据：[当前官方 License（固定 2b5a82b 提交）](https://github.com/noah-nuebling/mac-mouse-fix/blob/2b5a82b96f6df8b4bdba18a666e1183da7cf24db/License)。本次与开发时 License 内容一致；它是自定义 MMF License，不是 MIT。

| 事项 | 条文工程阅读 |
|---|---|
| Derived source | 一般授权允许使用源码；发布衍生作品需让来源明确可见。没有把二进制条件笼统施加到所有源码发布 |
| Executable | 只要源文件/代码包含复制或派生内容，二进制进入附加条件；无隐藏恶意内容 |
| Attribution | 必须明确派生自 MMF；现有 THIRD_PARTY_NOTICES 已指出作者、仓库、片段范围与改写来源 |
| Monetization | 默认同时涉及不向用户收费，以及保留并启用原许可、试用和支付系统；仅“免费”不足以跳过后半部分 |
| Substantial improvements/additions exception | 可影响上项条件；是否足够独立成为自身衍生作品没有量化标准。此项目是否符合：`LEGAL_INTERPRETATION_REQUIRED` |

| 本项目评估 | 状态（仅 MMF 许可层面） | 当前所需行动 |
|---|---|---|
| SOURCE_RELEASE | **CLEAR** | 当前 attribution 已明确来源；保留它和 License 链接，不能把相关范围无条件改挂 MIT，也不能声称整项目独立。此项不批准 Apple 条款、隐私或总体公开操作 |
| BINARY_RELEASE | **UNCERTAIN** | 当前 App 没有 MMF 的商业化系统；免费不足以说明满足默认条件。需确认 substantial-improvements 例外、获得书面许可，或完成有证据的独立替换 |

未发现本项目集成 MMF 附带的 GPL Polynomial Regression 组件，不因为上游存在它就给全项目套用 GPL。权利问题不能靠删除 attribution、简单换名、重新排版或在新 commit 覆盖旧函数解决；替换后的旧 Git 历史仍应保留准确 MMF 来源说明。

## 附录：精确关键词命中文件清单

搜索包含用户指定词及 Exposé，大小写不敏感；全仓 tracked 文本共 47 文件命中。行号是审计时工作区位置，仅做定位，不是衍生性证据。ConfigTests 的 Exposed 等普通词也会命中。

| 文件 | 角色 | 命中行 |
|---|---|---|
| `Package.swift` | 构建配置 | 10, 13 |
| `README.md` | 文档/历史说明；不编译 | 13, 42, 46 |
| `Sources/GestureCore/GestureMachine.swift` | 运行源码/接口 | 37, 40, 43 |
| `Sources/GestureCore/VerticalGestureTracker.swift` | 运行源码/接口 | 7, 27, 57 |
| `Sources/MouseGesturePOC/AppConfig.swift` | 运行源码/接口 | 40 |
| `Sources/MouseGesturePOC/DiagnosticRedactor.swift` | 运行源码/接口 | 8 |
| `Sources/MouseGesturePOC/GestureEngine.swift` | 运行源码/接口 | 4, 6, 12, 36, 46, 65, 99, 170, 172, 353 |
| `Sources/MouseGesturePOC/HIDInputBackend.swift` | 运行源码/接口 | 4, 7, 20, 22, 23, 25, 28, 29, 32, 38, 42, 44, 45, 46, 50, 51, 52, 53, 54, 75, 76 |
| `Sources/MouseGesturePOC/MouseInput.swift` | 运行源码/接口 | 14, 54, 155, 167, 170, 171, 175, 193, 209, 214, 215 |
| `Sources/MouseGesturePOC/OnboardingView.swift` | 运行源码/接口 | 12, 31 |
| `Sources/MouseGesturePOC/SettingsView.swift` | 运行源码/接口 | 111 |
| `Sources/MouseGesturePOC/main.swift` | 运行源码/接口 | 299 |
| `Sources/SystemGestureBridge/SystemGestureBridge.m` | 运行源码/接口 | 1, 9, 23, 24, 30, 43, 44, 46, 47, 50, 64, 79, 81, 82, 83, 95, 123, 125, 133, 134, 149, 151, 152, 153, 167, 195, 197 |
| `Sources/SystemGestureBridge/include/SystemGestureBridge.h` | 运行源码/接口 | 10 |
| `Sources/SystemGestureBridge/include/module.modulemap` | 运行源码/接口 | 1, 2 |
| `THIRD_PARTY_NOTICES.md` | 文档/历史说明；不编译 | 12, 18 |
| `Tests/CoreRegression/BoundaryTests.swift` | 独立测试 executable | 52, 53, 139 |
| `Tests/CoreRegression/ConfigTests.swift` | 独立测试 executable | 19 |
| `Tests/CoreRegression/GestureMachineTests.swift` | 独立测试 executable | 3 |
| `Tests/CoreRegression/InputPipelineTests.swift` | 独立测试 executable | 6, 7 |
| `Tests/CoreRegression/MissionControlPOCTests.swift` | 独立测试 executable | 3, 21, 26, 30, 35, 40, 49 |
| `Tests/CoreRegression/main.swift` | 独立测试 executable | 92, 103, 112, 113, 114, 115, 127 |
| `baselines/build4/README.md` | 文档/历史说明；不编译 | 3, 25, 59, 69 |
| `baselines/build4/tests-rechecked.txt` | 文档/历史说明；不编译 | 32 |
| `baselines/build6/test-output.txt` | 文档/历史说明；不编译 | 43, 44 |
| `baselines/build7/test-output.txt` | 文档/历史说明；不编译 | 40, 46 |
| `docs/api-audit.md` | 文档/历史说明；不编译 | 7, 23, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 41, 49, 51, 52, 54, 55, 56, 57, 58, 59, 60, 83, 86, 87, 88, 94, 95, 96, 97, 98, 100, 104, 105, 106, 107, 108, 109, 122 |
| `docs/architecture.md` | 文档/历史说明；不编译 | 3, 5, 7 |
| `docs/baseline-build4.md` | 文档/历史说明；不编译 | 40, 56, 59, 61, 65, 85 |
| `docs/compatibility-matrix.md` | 文档/历史说明；不编译 | 16, 32, 48 |
| `docs/demo/README.md` | 文档/历史说明；不编译 | 3 |
| `docs/distribution-audit.md` | 文档/历史说明；不编译 | 84 |
| `docs/manual-test.md` | 文档/历史说明；不编译 | 3, 78 |
| `docs/manual-ui-test.md` | 文档/历史说明；不编译 | 8 |
| `docs/mmf-author-message.md` | 文档/历史说明；不编译 | 7 |
| `docs/onboarding-audit.md` | 文档/历史说明；不编译 | 26, 29 |
| `docs/productization-audit.md` | 文档/历史说明；不编译 | 9, 39 |
| `docs/project-status.md` | 文档/历史说明；不编译 | 8, 13, 15, 22, 24, 39, 130 |
| `docs/release-template.md` | 文档/历史说明；不编译 | 12, 17 |
| `docs/research.md` | 文档/历史说明；不编译 | 1, 3, 11, 19, 23, 25, 26, 28, 32, 34, 36, 40, 47, 49, 51, 59, 60, 61, 62, 66, 74 |
| `docs/third-party-audit.md` | 文档/历史说明；不编译 | 3, 9, 11, 18, 19, 20, 21, 22, 24, 35, 36, 37, 71, 72 |
| `docs/validation.md` | 文档/历史说明；不编译 | 23, 30, 31, 34, 51, 69, 99, 138 |
| `docs/vertical-gesture-research.md` | 文档/历史说明；不编译 | 3, 7, 11, 15, 16, 18, 19 |
| `scripts/build.sh` | 构建/检查脚本 | 16, 17 |
| `scripts/compile-preview.sh` | 构建/检查脚本 | 11, 14 |
| `scripts/test.sh` | 构建/检查脚本 | 6, 11 |
| `scripts/toolchain.sh` | 构建/检查脚本 | 13, 14 |
