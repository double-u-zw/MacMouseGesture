# Implementation record — Build 15

路线 `REPLACE_WITH_INDEPENDENT_IMPLEMENTATION` 已实施。`CURRENT_IMPLEMENTATION_MMF_DERIVATIVE_NOT_PRESENT` 是工程源码范围结论，非法律保证。先写规格、再记录旧 C API 黑盒行为契约、最后实现新的声明式请求映射与完整分配事务；没有以旧函数为模板。旧构造器完整移除，对外四个 C API 和 Swift 调用方保持不变。

原有 67 项及新增 15 项全部通过；Build 15 隔离编译通过。包检查及真机待验项目见 [验证记录](build15-validation.md)。真人验收仍待用户执行，不把自动 payload 回读等同于 Dock 行为通过。用户本轮指令允许先生成候选包供验收，取代下方旧计划中“真人通过后才构建”的顺序。

当前发布树与旧 Git history 分开处理，保留历史 MMF attribution。Apple private API 仍存在，无 documented 等价替代的原结论未变。

---

# Historical proposal (Build 14; preserved)

以下“本轮未实施”等措辞属于替换前方案。

# MMF decoupling plan — review before implementation

日期：2026-09-30；基线 `856891d` / Build 14。**本轮未实施任何替换。**目标是在维持现有行为的前提下，将 MMF 工程派生范围从发行版构建输入移除；不能承诺简单重写就自动获得法律上的独立性。

建议路线：**REPLACE_WITH_INDEPENDENT_IMPLEMENTATION**。派生风险集中在 204 行 Bridge 内的两个构造器及与其紧邻的协议定义；无需重写输入层、状态机或 UI。分析者已经阅读 MMF，不能把随后自己对该文件的改名/重排声称为 clean-room。

## A — 独立最小实现（推荐的工程路线）

先形成仅含接口、可观察事实和项目行为要求的规格，每项 ABI/协议数值记录独立 runtime 观测或 Apple 公开定义。用正常原生触控板事件和项目既有真人验收约束重新验证必要字段；实验必须另经用户安排，不在此次分析中注入事件/捕获输入。现有 probe 只能证实自写 payload 能回读，不能独立证明 native 协议或 ownership。

如果需要有力的独立创作证据，由没有阅读 MMF/MIT 实现的实现者只按经审查规格完成新实现，并保留输入材料、提交和设计记录。规格不可把 MMF 构造顺序翻译成伪代码后称为独立来源。若无法建立这样的来源记录，不应宣布已经去 MMF 化，应转书面许可方案。这里是工程隔离方案，不是版权安全港保证。

| 旧文件 / 函数 | 来源问题 | 替代文件 / 方式 | License / notice | 必须保持的行为 | 必须重跑的检查 |
|---|---|---|---|---|---|
| `Sources/SystemGestureBridge/SystemGestureBridge.m` / createEvent、createVerticalEvent | C：研究记录 + MMF payload 组装组织 | 在同一个 `.m` 中由独立规格重新实现两个 C ABI 的内部 payload builder；无需新 target、库或 Swift 状态机 | 新代码按 owner 选择的项目许可；保留历史 MMF attribution，记录哪些当前部分被替换，不在本轮选择项目 LICENSE | 输入 progress/velocity 不改变；横/纵 motion、轴向速度、phase、时间语义、CG 标记、投递位置一致；遇失败返回 false | 67 回归、6 包故障、横纵四 phase 含正负进度/终结速度回读、真人停顿/反向/松手 |
| 同 `.m` / MGHIDContract、AttachFunction、CopyFunction、enum 与 raw numbers | ABI/数值来源需逐项追溯，不能从 MMF 再抄一遍 | 同 `.m` 的独立最小 ABI 声明；根据 runtime selector/type encoding、公开接口事实建立记录 | 如果实际采用 Apple 受覆盖声明/实现，按核实许可证保留相应通知；是否仅接口事实需独立判断 | 类型宽度、返回值、所有权、options/field 编码准确；不增加私有接口 | 非投递 symbol/selector/encoding 检查及对象生命周期验证 |
| 同 `.m` / loadAPI | MMF 给出 attach 思路，本项目防护实现独立 | 可保留已有独立装载/selector 验证；逐项记录 symbol 来源 | 技术研究 attribution 保留；不宣称接口由本项目发明 | macOS 版本 gate、缺 class/symbol/selector 时停用；库 handle 生命周期不变 | 缺符号安全失败（不在真实系统删除库）、正常加载/probe |
| 同 `.m` / MGBackendProbe、MGVerticalProbe | 测试组织 E，但当前调用 C builder | 保留接口和非投递约束，接入新 builder；必要时独立增加验证 terminal 子字段的检查 | 项目测试来源说明 | 不能为了绿灯跳过字段检查；probe 永不投递 | 现有两个 HID probe 和将来针对独立规格的检查 |
| 同 `.m` / MGPostHorizontal、MGPostVertical | 包装 E，调用 C builder | 保留公开 C 函数和校验/释放规则，仅替换内部 builder | 项目通知记录具体切换提交 | 有限数校验、phase 集合、异常返回、一次投递与释放；不改手势频率/完成阈值 | 状态机/序列平衡及真人回归；CGEventPost 无 ack 的边界不变 |
| `include/SystemGestureBridge.h` / 四个 MG 函数；module.modulemap；GestureEngine.swift 的 MacOS27GestureBackend | 自有 ABI 和调用编排，未识别 MMF 表达块 | 保持原样；不新增 wrapper 层 | 不因调用替换而重标整项目来源 | Swift 调用签名、功能、失败处理完全保持 | 编译、67 回归、包验证 |
| `THIRD_PARTY_NOTICES.md`、本报告与来源登记 | 旧 Bridge 和旧 commits 仍有 MMF 来源 | 在替换通过后按“历史参考/当前实现”准确记录；记录新源文件 revision 与证据 | 不删除历史 attribution；当前 release 采用何许可另做明确决定 | 去 MMF 化不能靠删版权说明完成 | 审查最终 tag 的源码树和可达历史，确认归因一致 |

时间戳会随运行变化，等价验证应比较语义与字段，不要求不同运行的绝对时间完全相等。独立实现不得偷偷使用旧 Bridge 输出作为唯一协议来源；旧行为可作为产品验收参照，但来源事实需独立材料支持。

### 完成判据

1. 新实现的每段代码和每项必要 ABI/常量有可审查来源；MMF/MIT 文件不作为模板、构建输入或未声明的间接代码来源。
2. 当前发行版 C builder 已被替换，保留的 D/E 部分有明确边界；没有仅重命名/语言翻译即改标 E。
3. 67 回归和 6 包故障检查在正常 macOS 环境通过；本轮前 ConfigTests.swift:78 的环境问题单独核实。真实两侧键四方向、停顿、反向、终结通过；此时才重新构建 Preview。
4. MMF 历史源码的 attribution 继续保留。若 owner 希望公开历史也完全无此代码，需要额外授权的历史方案；新 HEAD 干净不会自动清洗旧 commits。
5. 仅可以据证据关闭 MMF 二进制条件适用问题。Apple private API Gate 仍独立存在。

## B — MIT 来源候选（当前不直接采用）

候选为 [timmyagentic 的固定 `src/main.m`](https://github.com/timmyagentic/mac-mouse-fix-macos-27-fix/blob/9cf987ef070707fd8651475f78223403fca34ce6/src/main.m)：声明/常量（17–54）、`MMFLoadPrivateAPIs`（172–185）和 `MMFAttachDockSwipePayload` 中的 HID 组装（244–266）。不用其整套 App、安装器、event tap、legacy 字段解码或 Mac Mouse Fix 运行依赖。

采用前应明确这些片段自身的来源/授权范围。该项目的 MIT 声明真实存在，但其技术谱系关联 MMF PR；没有证据据此否定 MIT，也没有充分证据让它自动为本项目已有派生部分解除 MMF 条件。

若后续确认为可复用：创建 `licenses/MMF27-MIT.txt` 保留完整 MIT 和 `Copyright (c) 2026 Timmy ZHOU`，在采用源码旁标出原仓库、固定提交和修改，在随 App 打包的 THIRD_PARTY_NOTICES 中声明。MIT 本身不额外要求单独 NOTICE 文件；代码被改写仍保留所需许可通知。

精确适配差异：其函数读取现有 CG legacy fields 并修补原事件；本项目接收 `(axis, progress, velocity, phase)` 并创建新事件。需要去除 legacy 输入、反转归一化及已有 payload 幂等逻辑，保留本项目的当前时间语义和 X-only/Y-only terminal 速度，并保留分配失败返回 false。此改动不再是直接替换一个函数；不能凭 payload 看起来相似保证无行为变化。采用后的完整回归要求与 A 相同。此方案也不解决 Apple private API。

## C — 保留 MMF derivative

MMF 源码发布 attribution 路径已明确。对二进制，仅在确认现有免费独立项目适用其 substantial-improvements/additions 例外，或得到作者针对无 MMF 许可/试用/支付系统的明确书面许可后，再考虑保留。现阶段 `BINARY_RELEASE=UNCERTAIN`，不能自称例外已经成立。

如果独立来源记录无法建立，现实备选是 许可请求草稿（历史内部草稿，仅本地保留）。获得许可可避免运行时改动，但未来超出获准范围的收费/再许可仍需另行确认。
