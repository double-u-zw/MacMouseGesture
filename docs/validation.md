# 本机验证记录

日期：2026-09-28—2026-09-29。环境：macOS 27.0 (26A428)，arm64，Apple Swift 6.4，macOS 27 SDK。

本文按开发历史追加。下方早期阶段表及 Build 4 记录保留当时状态；当前版本结论见末尾“2026-09-29 · 0.1.4 / Build 6”及 [项目状态](project-status.md)，不要将历史的 ad-hoc 签名、未保存配置或授权等待当作当前状态。

## 阶段状态

| 阶段 | 当前实现状态 | 实际验证 |
|---|---|---|
| Phase 0 Research | 已核对 master、3.1.0、指定 issues、f92d2d53a、PR #2025、Apple HID 接口 | **PASS：资料与运行时 ABI 核对**；桌面响应不包含在该 PASS 中 |
| Phase 1 Input POC | CG button/down/up/move/drag/scroll；只读 HID usage 与 vendor/product；诊断复制 | **PASS：用户实测 CG tap、Button 4/5 down/up、鼠标移动**；**PENDING：scroll、HID、吞事件与延迟对照** |
| Phase 2 Horizontal POC | 连续累计 progress、120 Hz 合并、dead zone/锁轴、release velocity、terminal/cancel；Build 4 双侧键与持续运行 | **PASS：构建、启动、回读、状态机测试；用户确认 Build 4 双键及方向可以正常使用**；**PENDING：完整边界验收** |
| Phase 3 Full Gesture | 纵向未实现 | 横向基本功能已获用户确认；本轮按要求先整理当前版本 |
| Phase 4 App | 只有 POC 实验面板，未做正式设置/菜单栏 | 按要求暂不推进 |
| Phase 5 Stability | 自动化基础检查完成 | 真实硬件、Dock、CPU/内存与长期稳定性未验收 |

## 已实际运行

- `./scripts/build.sh`：PASS，生成 `build/MacMouseGesture.app`，arm64 Mach-O，ad-hoc codesign verify PASS。首次交付 bundle 约 248 KB（后续编译大小可能变化）。
- `open build/MacMouseGesture.app`：PASS，原生实验窗口出现；通过 UI accessibility tree 看到所有输入字段、启动/停止按钮、诊断与默认 Stopped 状态。沙箱内 LaunchServices 首次返回 -10827，经获准的本地启动工具正常打开，不是 executable 缺失。
- `--probe`：PASS，输出见 `build/probe-output.txt`。实际权限为 Accessibility=false、Input Monitoring=false；四个 phase 的 type/options/motion/flavor/progress 回读正确。没有 post。
- 首次交付 `./scripts/test.sh`：17 项检查，0 失败。Build 2 为 19 项，Build 3 为 24 项；Build 4 当前 **28 项检查，0 失败**，完整输出见 `build/test-output-build4.txt`。所有 CGEvent 测试对象仅在内存中创建，从未投递到系统。

检查包括按钮映射、死区、垂直拒绝锁轴、横向锁轴/反向移动、8,000 Hz 模拟输入守恒且约 120 帧输出、松手尾部位移、停住后速度归零、flick 与慢拖区分、进度结束、取消后重置、100 个独立 sequence、反转/无效数据、私有桥接回读、8,000 条输入压缩及 down/up 顺序、无关输入透传、观察模式/队列溢出放行、Escape/冻结开关。

## 明确未运行或尚无证据

1. HID usage、两个输入后端实际事件延迟与硬件 polling rate。实体侧键的 CG 编号已通过下述用户日志验证。
2. 用户确认 Build 4 双键及方向“可以正常使用了”；半程反向、松手回弹与 flick 等全部边界项目尚无逐项验收。CGEventPost 不会返回 Dock 接受确认。
3. 真实 500 / 1000 / 8000 Hz 鼠标测试、100 次真实 Spaces 切换。合成数据测试不能替代它们。
4. 辅助功能撤销、锁屏、睡眠、设备断开、屏幕配置变化时的真实系统恢复；代码有取消入口，但还没有执行这些系统操作。
5. 空闲和活动 CPU / resident memory 稳态、leak profiling；尚未给出“接近 0%”或“低 CPU”实测承诺。
6. 纵向 Mission Control / App Exposé、全屏 Space、多显示器标定、端点桌面边界、其他工具冲突。
7. 假设系统内部拒绝 cancelled / ended 时的自动恢复；当前仅发送一次 terminal，不强制重启 Dock 或 WindowServer。

## 当前验收结论与后续范围

用户已在双键和方向调整后确认 Build 4 可以正常使用，本轮横向基本功能记录为 PASS。后续完整边界测试仍需覆盖慢拖停顿、反向、回弹、两键同时按住和睡眠唤醒。Build 4 横向模式持续运行，CG / HID 观察模式才有 120 秒限时。

当前只整理已通过的横向版本；纵向与正式 MVP 尚未实现，未将未执行的边界项目预填为 PASS。

## 用户反馈后的权限排障（2026-09-28）

用户诊断记录中：49.751/49.950 秒捕获 Button5 DOWN/UP cg=4；52.435/52.589 秒捕获 Button4 DOWN/UP cg=3，此后均有重复按键成功。移动连续到达，部分 0.1 秒窗口约有 100 个事件，但这只能证明当时观测到约 1,000 events/s，不能单凭此确认硬件 polling rate。此次没有进入 horizontal 实验，也没有 gesture began；所以不能判定 Dock 注入失败。

用户确认系统辅助功能开关已开启，但应用仍显示 false。只读查询 tccd 后获得明确原因：2026-09-28 22:49:47 的日志为 `Failed to match existing code requirement ... kTCCServiceAccessibility`，旧 requirement 的 cdhash 是 `f2fbaafca0ee71682eb92be605da296da0dc1c8b`，当时当前 bundle 是 `25be781eebedbf460020d537d1bea52451848e5d`，验证状态 -67050。来源为 `build/permission-system-log.txt`。上轮末尾重新构建改变了 ad-hoc 签名，已有授权没有匹配新代码；不是根据 false 猜测用户没有操作。

修正：0.1.1 / build 2 将权限拒绝与后端不可用分开报告，诊断增加版本与实际 bundle 路径；构建脚本与运行中应用共享 flock，应用在运行时拒绝覆盖 bundle。该保护已实际触发，退出状态 2；测试前后旧 bundle 的 cdhash 保持不变。不创建宽松的自定义签名 requirement，不修改 TCC 数据库，也不增加 Apple 私有权限 entitlement。

另一个独立问题：旧日志出现约 82,093,709 ms 的 callback age。当前机器 ProcessInfo.systemUptime 和 CLOCK_UPTIME_RAW 一致，不能归因于它们时基不同；`CGEventCreate(NULL)` 实测 timestamp=0，日志未保存原始 timestamp，无法确认具体是哪条原始事件造成最大值。修正后状态机统一使用回调到达的单调时间，防止零/旧/外部时间戳影响 20 秒安全限时和速度；事件年龄只对 0…1 秒可比较样本统计，其余计为 rejected，且不称为硬件延迟。新增两个回归检查通过。

权限恢复需要用户在系统设置移除旧应用条目、重新添加最终 build 2 的相同 .app 路径并开启，再重启应用。完成后再验证真实横向手势；目前仍为 PENDING。

最终 build 2 已重新构建并通过 `codesign --verify --strict`，cdhash=`f8bf464b90ede065232b430c8a4d6d38106928bd`；四 phase 的 probe 仍 PASS，Accessibility 仍 false（待重新添加授权）。旧进程已正常退出，新版本保留为关闭状态，供用户先修复系统授权再启动。

### Build 2 再次反馈：开关已开启但旧 requirement 仍被使用

用户随后启动 Build 2 并报告 Accessibility=false。本轮未重建或重新签名：bundle 的 cdhash 仍为 `f8bf464b90ede065232b430c8a4d6d38106928bd`，PID 67220 的路径也正确。

直接读取系统设置 accessibility tree，当前 macOS 27 中文页名为“设备控制和数据访问”，`MacMouseGesture.app` 的开关确为 on。`build/permission-system-log-latest.txt` 显示：23:01:21，tccd 为该 bundle 写入 Allowed (System Set) (v1)，CodeReq 为当前 f8bf…；23:01:32，应用启动后的检查仍拿最初构建 f2fb… 的 requirement 比较并返回 -67050。因此不是简单的“用户未开开关”。日志证实新授权写入与后续旧 requirement 校验不一致；尚不能仅从这些日志区分持久记录和 daemon 缓存。

同一二进制新进程 `--probe` 仍返回 false（`build/permission-fresh-process.txt`），所以只重新读取应用内变量不能解决。用户随后明确允许仅对 `local.macmousegesture.poc` 做系统授权重置，授权了本次对项目目录外系统权限记录的例外修改。已执行 `tccutil reset Accessibility local.macmousegesture.poc`，退出码 0，输出 `Successfully reset Accessibility approval status for local.macmousegesture.poc`。已正常退出 PID 67220 的本项目进程，并打开权限页面及 Finder 中的当前 bundle，等待用户重新添加并开启授权。未重置其他应用、未重启 WindowServer/Dock、未直接修改 TCC 数据库或签名策略，也没有重新构建。实际授权恢复和横向手势仍待验证。

### Build 2 授权恢复：用户确认 Accessibility=true

重置后曾再次收到 false；当时系统设置中该应用开关为 off，重置后的系统日志也只有 Denied。用户随后开启并重新启动，最新诊断已为 `Accessibility: true`、`Input Monitoring: false`，同一 Build 2、同一 bundle 路径，应用仍为 `Stopped — no mouse events consumed`。**辅助功能授权恢复 PASS（用户提供的应用诊断）**。

当前横向实验使用主动 CGEventTap，启动条件检查辅助功能；输入监控用于可选 HID 对照/设备观察，不作为横向实验的预先阻断条件。下一步直接进行 Button 4（CG=3）的左右慢拖、停顿、松手测试；若实际 CGEventTap 创建失败，再按错误处理权限。此轮没有重新构建或签名。仅权限已恢复，真实事件拦截和连续 Dock 响应仍为 PENDING。

### Build 2 横向反馈：侧键映射与方向待校准

用户反馈“5 键可以用，4 键还不行，方向好像有点问题”，原始诊断保存在 `build/horizontal-feedback-build2.txt`。该截取包含 cg=3 的 80 条按键边沿和 cg=4 的 2 条边沿；cg=3 按住时持续生成 began/changed/ended，cg=4 的一次按下松开没有手势。直接读取当前实验面板确认 CG button=3、Invert horizontal=off；实验已在 120 秒后正常停止，overflow=no。说明两个 CG 编号都已识别，当前仅绑定 cg=3，不能据此称另一颗按键捕获失败。

结合用户对实体按键的称呼，推测其“5 键”对应 cg=3、“4 键”对应 cg=4，尚待本人验证。本轮已将运行中面板的 CG button 改为 4 并读回确认，等待重新开始后的实体按键测试；没有重建、签名或修改授权。方向问题已向用户询问具体表现，暂不根据含糊描述改动方向算法。

日志中另有一次总位移 dx=-637、dy=-29 但 emitted=0，以及一次 progress=0.9633、velocity=-0.439 的 cancelled。前者可能为初始垂直锁轴，后者符合当前反向速度取消条件；截取没有锁轴时的原始序列及屏幕状态，不能直接认定为用户所说的方向问题。用户已报告一颗侧键可用，但半程停住、反向跟随、两侧松手行为仍需明确确认，Phase 2 暂不整体标为 PASS。

### 用户确认左右反向：应用现有反转配置

用户随后明确“就是左右反了”。新诊断显示 640.207 秒以 CG button=4 启动，之后该键连续产生 began/changed/ended，左右位移均有记录；改绑定后的事件路径已工作，实体键名仍以用户称呼为准。

已在现有 Build 2 面板停止实验、开启 `Invert horizontal`、重新开始横向实验；直接读回 CG button=4、Invert horizontal=1、Running 状态，启动日志为 734.391 秒。现有实现从复选框读取配置并同时反转 progress 与派生 velocity，因此本次无需修改算法或重新构建。当前进程内设置已应用，实际方向和半程停顿仍等待用户体验确认；退出应用后配置仍会恢复 POC 默认值。

### Build 3：两个侧键均可作为手势键

用户确认反转后“没问题”，并明确要求两个键都能用。本轮将输入绑定扩为 CG 编号集合，默认 `3,4`；面板默认开启反转，保留已确认方向。物理键边沿继续各自记录，输入层仅在首个绑定键按下和最后一个绑定键松开时产生逻辑手势边沿，两键重叠按住时不重复开始、不提前结束、不重置进度。重复 DOWN、未配对 UP 和非绑定键不会改变当前逻辑按住状态。Escape / tap disabled 立即放行后续输入，防止队列处理取消前被第二颗键重新冻结。

新增五项回归覆盖两个键独立使用、两个按下顺序与两个松开顺序组合、重复/未配对边沿及交替使用、双键取消即时放行、双键观察模式透传。连同原有测试共 24 项，0 失败。Build 3（0.1.2）构建及签名验证通过，cdhash=`816551579de63b46ddc69b52b6540e60990985a7`；原 Build 2 bundle 保留在 `build/MacMouseGesture-build2.tar`。

已正常退出旧进程后替换 bundle，启动新版本并直接读回 Build=3、CG buttons=3,4、Invert horizontal=1、Stopped 状态。四 phase HID 回读仍 PASS。新版本 Accessibility=false，需重新授予当前签名权限后实测双键；尚未在缺少权限时宣称运行或双键真人通过。仍只交付横向 POC。

按用户此前允许的同一应用授权重置范围，已退出 Build 3，确认进程不再运行，再执行 `tccutil reset Accessibility local.macmousegesture.poc`，退出码 0。重新打开同一 bundle，请求辅助功能并打开系统设置后，已确认“设备控制和数据访问”中新的 MacMouseGesture.app 条目存在、开关 off。当前等待用户开启；未替用户授予权限，未修改其他应用的授权。该步骤之后没有重新编译或签名。

### Build 3 用户日志：双侧键输入与手势序列通过

用户最新诊断显示 Accessibility=true、Input Monitoring=false，399.086 秒以 `CG buttons=3,4; invert=true; freeze=true` 成功启动横向实验。399.903–401.948 秒，cg=4 完成 5 次手势；402.293–403.796 秒，cg=3 完成 4 次手势。9 次均有按下、began、changed、松开和 ended，两颗键各自都有正负方向的 progress，且 progress 与 dx 的符号一致，符合开启反转后的配置。所提供片段没有 ERROR 或 tap disabled。

**PASS：Build 3 授权恢复、主动 CGEventTap 启动、两个侧键独立触发完整手势序列及反转配置生效（用户日志证据）。** 本片段每次拖动约 0.13–0.18 秒，没有双键重叠按住或半程停顿的实测序列；实际屏幕连续跟随及双键操作体验仍待用户确认，不以事件日志替代 Dock 验收。本轮仅更新记录，没有重新编译或更改应用签名。

### Build 4：取消横向会话限时，授权后自动开启

用户要求一直开启，避免反复手动启动。横向模式已移除 120 秒 session deadline，输入观察模式仍保留该限时；20 秒连续按住上限及 Escape、权限丢失、输入异常的释放保护保留。默认启动意图为横向模式，缺少权限时等待，授权生效后自动启动一次；不会持续重试输入后端失败。用户点“停止”或选择输入观察会清除自动启动意图，避免被后续轮询或唤醒覆盖。

新增 `AutoStartState` 管理启动意图及睡眠、屏幕休眠、会话非活动三个暂停原因，全部恢复且权限有效时才重新启动。窗口关闭不再退出进程，重新打开应用会显示原面板，⌘Q 仍完全退出。没有创建系统登录项或辅助进程。

验证：28 项回归全部通过（`build/test-output-build4.txt`）；新增检查包括授权生效后仅启动一次、失败不进入重试循环、手动停止覆盖待启动、多个暂停原因全部恢复、观察模式不会被唤醒覆盖。Build 4（0.1.3）构建和 codesign verify 通过，cdhash=`f48b3ff46e9a7c0ca578ac0b7685fc3bac240966`，原 Build 3 保存在 `build/MacMouseGesture-build3.tar`。真实 UI 验证了等待授权提示、关闭面板后进程仍运行、重新打开显示原窗口、点停止后显示 `Stopped: user stop`，以及 ⌘Q 后进程退出。

当前新签名 Accessibility=false。尝试只重置本应用授权时，工具自动审批拒绝，理由是此前旧版本的许可不覆盖本次重复撤销；该重置没有执行。已向用户请求本次明确确认，应用已打开并等待授权。真实授权后自动启动、持续超过 120 秒的系统运行、真实睡眠/唤醒恢复仍待验证，不以生命周期逻辑测试替代上述实测。此后未重新签名。

### Build 4 授权重置完成（2026-09-29）

用户在本次明确的单应用重置确认请求后回复“你帮我”。核对 bundle cdhash 仍为 f48b3ff46e9a7c0ca578ac0b7685fc3bac240966，正常退出并确认进程停止后，已执行 `tccutil reset Accessibility local.macmousegesture.poc`；本次获准执行，退出码 0，输出 `Successfully reset Accessibility approval status for local.macmousegesture.poc`。

已重新打开相同 Build 4、请求辅助功能并打开“设备控制和数据访问”页面。直接读取系统设置确认 MacMouseGesture.app 新条目存在且开关 off，其他应用未重置；应用显示等待授权后自动开启。当前等待用户开启该开关，尚未把实际自动运行标为通过。本次没有重新编译、重新签名或改动手势配置。

### Build 4 授权恢复及用户验收（2026-09-29）

最新用户诊断保存在 `build/continuous-feedback-build4.txt`：Accessibility=true，Running，`CG buttons=3,4; invert=true`，`Continuous — no session timeout`。79.093 秒记录首次启动；该次启动前没有鼠标点击记录，符合授权后自动启动流程。119.001 秒另有一次 `Stopped: restart` / Start 对，表示重新应用，不是 120 秒超时停止；该截取本身不足以证明单次会话已持续超过两分钟。

该片段包含 40 次 began/ended 完整序列，其中 cg=4 为 38 次、cg=3 为 2 次，未记录 ERROR、cancelled 或队列溢出。随后用户明确反馈“可以正常使用了”，据此将 Build 4 双侧键与已选方向的基本横向体验记为 PASS。此轮保持原 Build 4 签名及运行配置，只读观察并更新文档。

持续运行实测：在不点击启动/停止、不修改配置的情况下，两次直接读取应用 UI 状态，观察间隔 **130 秒**。前后均为 `Running ... CG buttons=3,4; invert=true. Continuous — no session timeout`，最新启动记录均为 119.001 秒，期间没有新的启动/停止记录或 ERROR。**PASS：当前横向会话跨过原 120 秒截止点仍持续运行。** 此结果验证了本次会话限时修复，不代替长期稳定性和睡眠/唤醒验收。


## 2026-09-29 · 0.1.4 / Build 6

本轮稳定签名、配置持久化、横向边界验收已整理于 [project-status.md](project-status.md)。保留旧 Build 4 为 First confirmed working horizontal gesture baseline，原始 app 和源码在 `baselines/build4/`。

- A / B 不同 cdhash、相同证书 DR、交叉验证通过。首次迁移经用户批准仅 reset 此应用 Accessibility 一次并由用户授权；后续 B、Build5、Build6 均直接继承授权。
- 配置 UserDefaults 跨进程测试通过，真实 UI 720/13 → Quit/Open 恢复、停止意图保存均通过，最终恢复600/8。
- 自动回归40 PASS / 0 FAIL，原28项保留；最终输出 `build/test-output-build6.txt`。
- 用户确认半程停顿2秒、双键交替20次和之后连续操作正常。累计141 began = 139 ended + 2 cancelled，open=0、sequenceErrors=0、postFailures=0。
- 第二批前49、之后141，增量92；用户手动反馈100，记录两种口径，不补写事件。整个进程超过100条完整真实手势，无引擎重启。
- RSS：启动85.2 MiB → 49次124.8 → 101次112.0 → 141次112.1；采样峰值133.5。此样本未见持续线性增长，仍需长期观察。
- 操作时 top CPU有效采样10.4%–15.5%；内置采样最高17.44%，不声称为瞬时峰值。空闲专项结果见项目状态。
- 关闭面板后最终后台 CPU 有效区间样本3.1%–7.5%；没有同窗输入计数不变的证据，严格空闲接近0%未验收。一次原进程已正常退出的无进程采样已排除；重新启动同一Build6后权限和配置保留，16段新手势均正常结束。保留完整样本，不以一次0.0%宣称达标。
- GestureMachine.swift 与 SystemGestureBridge.m 对比 Build4 逐字节不变。无纵向功能或新的非横向扩展。
- 旧的偶发失效未定位根因，本轮未复现；Tap有界恢复和输入/终止计数为后续定位提供证据，不能宣称根因已修复。
