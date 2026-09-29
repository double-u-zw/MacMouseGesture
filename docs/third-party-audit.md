# 第三方代码与许可审计

日期：2026-09-29。结论：**P0 — 公开源码/二进制前，需要关闭 SystemGestureBridge 的 MMF 衍生性和 Apple 头文件来源复核。**没有给项目添加许可证，没有复制研究仓库进 Git，也没有联系第三方。

## 固定比较对象与方法

- 本项目：`e69aded137b3a8ed6dc635732fcb4926fe811ce9`，单个初始 release commit；不是包含完整开发过程的细粒度历史。
- 研究快照：Mac Mouse Fix `a7ac3ecc86acf4ddb309ce1007472439a2f9d42a`，本地 `references/mac-mouse-fix/`（忽略目录）。
- 在线核对 master：`0c0fc99e65b3b09e083cbedc71c4d83fe21d1075`，提交时间 2026-09-28T20:32:36Z。[固定提交](https://github.com/noah-nuebling/mac-mouse-fix/commit/0c0fc99e65b3b09e083cbedc71c4d83fe21d1075)。当日下载其 License、TouchSimulator.m、CGEventHIDEventBridge.h，与研究快照逐字节相同。固定版本比浮动 master 链接更适合后续复核。
- 实际比较了 749 个上游 .m/.h/.mm/.swift/.c 文件与本项目 18 个 Sources 文件、8 个测试文件及 BuildGuard.c，共 27 文件；另逐项检查构建/签名脚本与资源。
- 机械检查：去空白，保留长度至少 20 的行，比较单行和连续四行窗口；没有发现连续四个此类行完全一致。Bridge 有 7 个相同行出现次数（含重复），主要是 import、CGEventCreate、catch；MouseInput 2，main 1，LoginItemController 1，其余 0。原始结果在 `build/productization-experiments/evidence/source-comparison.json`。
- **机械零匹配不能证明原创。**另人工检查函数名、注释、常量、调用顺序、字段结构及历史研究笔记，发现下面的协议级对应。没有采用“重命名变量就不算衍生”的判断。

## 关键结构对比

| 本项目位置 | 上游位置 / 对应 | 相同与不同 | 来源判断 |
|---|---|---|---|
| SystemGestureBridge.m:64–85、134–154 | [TouchSimulator.m:196 起](https://github.com/noah-nuebling/mac-mouse-fix/blob/a7ac3ecc86acf4ddb309ce1007472439a2f9d42a/Helper/Core/Touch/TouchSimulator.m#L196) | DockSwipe constructor → phase options → motion/flavor/progress → terminal Velocity child → CGEvent type 30 wrapper，结构高度对应；本项目用独立 ObjC wrapper、动态符号、不同时间戳和按轴速度 | **Adapted（协议实现层面的保守判断）；Needs review** |
| Bridge:43–47、84、154 | [FixDockSwipes.m:263–304](https://github.com/noah-nuebling/mac-mouse-fix/blob/a7ac3ecc86acf4ddb309ce1007472439a2f9d42a/Tests/FixDockSwipes.m#L263) | SLEventSetIOHIDEvent 附加路径一致；本项目通过 dlsym，未照搬观察/克隆实验 | Inspired / Adapted；Needs review |
| Bridge:11–24 | [Apple HIDEvent.h](https://github.com/apple-oss-distributions/IOHIDFamily/blob/IOHIDFamily-1633.120.12/HID/HIDEvent.h)、MMF 私有声明/研究 | selector 和 ABI 必须对应；本项目用 uint32_t、id 和自有类名表达；并无证据足以断言这些最小声明完全不受任何许可影响 | **Adapted ABI / Unknown 权利范围；Needs review** |
| Bridge:30–32、67–77、137–147；GesturePhase | Apple IOHIDEventTypes/FieldDefs；MMF DockSwipe 使用 | 类型23/9、field base、offset、flavor3、motion1/2、phase1/2/4/8 与 shift24 相同，是同一协议事实 | Inspired by external implementation / 声明改写；需区分协议事实与表达 |
| Bridge 的 attach 实现 | [CGEventHIDEventBridge.m](https://github.com/noah-nuebling/mac-mouse-fix/blob/a7ac3ecc86acf4ddb309ce1007472439a2f9d42a/Shared/IOKit/CGEventHIDEventBridge.m) | 上游有低层内存偏移桥接；本项目没有复制或执行这些偏移操作 | 未发现该部分复制；不消除其他衍生风险 |
| InputMailbox 合并与 120 Hz timer | 历史 research.md 引用了 [MMF PR #2025](https://github.com/noah-nuebling/mac-mouse-fix/pull/2025) 的节流思路 | 项目为有界队列、边沿唤醒、独立帧节奏；没有发现成块代码相同 | Inspired by external implementation |
| GestureMachine / VerticalGestureTracker | MMF TouchSimulator 与 ModifiedDragOutputThreeFingerSwipe 作为概念参照 | 项目独立状态机和速度窗口、上下动作锁定；没有复制上游 delay-end 重发或拟合组件的证据 | Inspired；状态机具体实现暂列 Original 候选，非版权清白证明 |
| 注释和命名 | 全量归一化比较及重点人工阅读 | 未发现长段原注释或 MMF 特有函数名照搬；HID selector 与 SLEvent 名本来就是外部 ABI 名称 | 不把通用 API 同名当复制证明 |

现有 `THIRD_PARTY_NOTICES.md` 已署名并指向自定义 MMF License，但“implementation is new”属于历史声明，不能替代此轮来源审计。公开前应校准该声明，不应据其推出“非衍生、可任意发二进制”。本轮保留原文件以免把未解决结论改写成既成事实。

## 逐文件来源登记

Original = 本次比较未见特定外部表达来源的**暂定判断**，不等于证明从未借鉴；只有单提交历史，无法重建作者每次决策。没有将任何完整文件判为 Copied verbatim；私有 ABI 和协议细节保守列入 Needs review。

| 本项目文件（相对目录） | 分类 | 依据 / 后续 |
|---|---|---|
| Sources/SystemGestureBridge/SystemGestureBridge.m | Adapted / Unknown — Needs review | 上表协议、ABI 与实现结构对应；P0 |
| Sources/SystemGestureBridge/include/SystemGestureBridge.h | Original wrapper / Inspired | 自有 MG 函数接口，封装上游启发协议 |
| Sources/SystemGestureBridge/include/module.modulemap | Original（暂定） | 简单模块声明，通用构建语法 |
| Sources/GestureCore/GestureMachine.swift | Inspired by external implementation | 连续手势/phase 语义有外部依据，具体纯 Swift 状态机未见成块复制 |
| Sources/GestureCore/VerticalGestureTracker.swift | Inspired by external implementation | 项目上下方向实验；依赖相同 Dock 协议 |
| Sources/MouseGesturePOC/MouseInput.swift | Inspired by external implementation | 高速输入合并思路；2 个通用相同行，无连续块 |
| Sources/MouseGesturePOC/GestureEngine.swift | Inspired by external implementation | 输入/状态机/桥接编排；历史明确参考节流思路 |
| Sources/MouseGesturePOC/HIDInputBackend.swift | Original（暂定） | Apple 公开 HID manager 用法；无专有块匹配 |
| Sources/MouseGesturePOC/AppConfig.swift | Original（暂定） | 本项目配置类型、持久化和校验 |
| Sources/MouseGesturePOC/AppViewModel.swift | Original（暂定） | 本项目状态绑定 |
| Sources/MouseGesturePOC/AutoStartState.swift | Original（暂定） | 本项目生命周期状态 |
| Sources/MouseGesturePOC/Diagnostics.swift | Original（暂定） | 有界内存日志 |
| Sources/MouseGesturePOC/RuntimeMetrics.swift | Original（暂定） | 本项目计数与恢复预算 |
| Sources/MouseGesturePOC/PerformanceSampler.swift | Original（暂定） | 公开 Darwin/Mach 采样 |
| Sources/MouseGesturePOC/PresentationState.swift | Original（暂定） | 产品状态和滑块映射 |
| Sources/MouseGesturePOC/SettingsView.swift | Original（暂定） | 中文 SwiftUI 表单，无上游 UI 复制证据 |
| Sources/MouseGesturePOC/LoginItemController.swift | Original（暂定） | 公开 SMAppService；一个通用相同行 |
| Sources/MouseGesturePOC/main.swift | Original（暂定） | 本项目菜单栏与生命周期；一个通用相同行 |
| Tests/CoreRegression/AutoStartTests.swift | Original（暂定） | 针对本项目状态 |
| Tests/CoreRegression/BoundaryTests.swift | Original（暂定） | 针对本项目边界 |
| Tests/CoreRegression/ConfigTests.swift | Original（暂定） | 针对本项目配置 |
| Tests/CoreRegression/GestureMachineTests.swift | Original / Inspired | 项目状态机；触及外部手势协议语义 |
| Tests/CoreRegression/InputPipelineTests.swift | Original（暂定） | 输入管线检查 |
| Tests/CoreRegression/MissionControlPOCTests.swift | Original / Inspired | 私有后端 probe，继承协议来源问题 |
| Tests/CoreRegression/PresentationTests.swift | Original（暂定） | 产品状态映射 |
| Tests/CoreRegression/main.swift | Original（暂定） | 本项目检查入口 |
| scripts/BuildGuard.c | Original（暂定） | POSIX 锁与 exec，未见上游块匹配 |
| scripts/build.sh、toolchain.sh、test.sh | Original（暂定） | 本项目 swiftc/clang 与 bundle 管线 |
| scripts/signing.sh、setup-local-signing.sh、signing-experiment.sh、install-signing-sample.sh | Original（暂定） | 本机稳定签名工作流；不能向用户分发钥匙串 |
| Package.swift、Resources/Info.plist、Entitlements.plist | Original / 标准配置 | 无第三方包依赖；无第三方 icon/字体资源 |
| docs、README、THIRD_PARTY_NOTICES、baselines 的小型 manifest | Original 研究记录 / 引用外部资料 | 非上游源码，保留引用；有历史断言需要本报告限定 |

## 许可证与未来许可证兼容性

| 来源 | 核实的 license | 受影响实现 | Attribution / Source disclosure | 未来许可证判断 |
|---|---|---|---|---|
| Mac Mouse Fix | [MMF License，固定当前提交](https://github.com/noah-nuebling/mac-mouse-fix/blob/0c0fc99e65b3b09e083cbedc71c4d83fe21d1075/License)，不是 MIT/Apache/GPL | DockSwipe 桥接及可能的衍生实现 | 衍生作品需说明来源；发布含复制/衍生代码的 executable 有恶意内容、收费及保留原 monetization 系统等限制和 substantial improvements 例外。文本没有一般性的完整源码公开条款；不能据此忽略其他限制 | **Needs review**：不能直接把整体改挂 MIT/Apache/GPL；是否属于例外不能由本项目自行断言 |
| Apple IOHIDFamily / IOHIDEventTypes.h | 头部明确 APSL 2.0；[Apple APSL](https://opensource.apple.com/apsl/) | 最小 ABI、常量、field 编码的来源 | 若实际复制/修改受覆盖代码并外部分发，应复核保留声明及 APSL 的外部分发/源码义务；这里只确认最小声明/协议引用，不判定触发范围 | 逐文件复核；HIDEvent.h 本地副本头部未写许可证，不因同仓库就笼统判每个文件都相同，标 Unknown / Needs review |
| MMF 仓库内其他第三方内容 | 上游 License 还提到特定分支的 GPL polynomial regression 与作者例外授权 | 本项目未发现该回归库、付费系统、UI 或资源被编译/打包 | 不把上游整个依赖树许可自动套到本项目；一旦发现代码来源须追溯 | 没有证据支持本项目当前已成为 GPL；同样不代表无 MMF 风险 |
| Swift / 系统 frameworks | 系统/SDK 链接，无复制完整实现入源码 | 公共开发工具与平台运行时 | 按实际打包内容核查；不是给项目自动授予一种开源许可证 | 现有 Package.swift 无外部 package，Resources 无第三方素材 |
| Sparkle 2 | 本轮仅研究，未集成 | 当前无 | 集成时单独固定版本、审查其 license/附带第三方 notices | 不能把未来依赖写作当前组成 |

P0 关闭路径可选择：获得权利人针对当前实现和预期发布/商业模式的书面许可；或由合适的许可复核明确衍生范围和可用条件；或在独立设计约束下替换有问题的实现并保留来源记录。不能以删除 attribution、简单改名、只发免费版或把 repo 开源当作许可自动解决。当前仅技术分析，未作法律合规/违法结论，也未发送联系消息。

## Git 历史、研究副本和敏感资料

实际执行 `git log --all`、`git rev-list --all`、逐 tree/blob 检查、`git for-each-ref` 和 `git fsck --full --no-reflogs`：

- 普通可达提交只有 1 个 `e69aded…`，main/origin/main/本审计分支起点一致；tag 解引用同一提交。56 个跟踪文件。不是“没有检查早期历史”，而是该仓库本来没有逐 build 的开发提交。
- 另有 Codex 本地内部 tree refs（不是提交），检查到的 tree 同样为 56 文件；没有发现额外研究副本。`fsck` 未报告 dangling 对象。
- 扫描所有上述文本 blob：私钥 PEM 标记、常见 GitHub/AWS token 模式、`/Users/<name>` 实际路径，以及研究目录/钥匙串/证书包/.env 等路径。**未发现命中**。模式检查不是所有密钥或高熵秘密的穷尽证明；公开前仍需一次专门 secret scan 和人工 review。
- `.gitignore` 仍排除 `references/`、build、.local-signing、keychain、PEM、p12 等。研究 clone、Apple headers、实验日志和公开 DER 都在忽略目录；未添加到 Git。历史 baselines 只跟踪少量说明、校验清单和测试输出，未跟踪 app/tar/源码研究副本。
- **现有证据不要求为清理研究副本/已知秘密立即重写 Git 历史。**但当前桥接源码本身的许可问题仍在可达历史中；若以后决定必须移除受限表达，是否保留原历史/另建公开仓库也需许可复核。未 reset、force、重写历史或更改仓库可见性。

边界：本次检查覆盖本地所有可达 refs 和对象完整性，不声称检索 GitHub 的不可达缓存、别人克隆、历史 artifact 或账号侧删除对象。公开前复核范围应包括计划发布的文档和打包产物，而不是只看 Sources。
