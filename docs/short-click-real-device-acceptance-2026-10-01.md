# Short Click Real-device Acceptance

日期：2026-10-01（Asia/Shanghai）
状态：用户决定结束本轮真机验收；Build 19 Test 1–4 PASS，其余未执行。自动化测试 123 PASS 不计入真机 PASS。

## 运行身份与保护措施

- 初始运行进程：PID 1586。
- 初始路径：`/Applications/MacMouseGesture.app/Contents/MacOS/MacMouseGesture`。
- 初始版本：`0.2.0-beta.1 / Build 17`。
- 初始稳定版指定签名要求已读取并记录；不替换、不删除该 App。
- 旧 `build/MacMouseGesture.app` 不是本次最新短按产物。
- 本轮用当前源码重新编译，开发包单独存放于 `build/short-click-acceptance/`。
- 源码与稳定包哈希记录：`build/short-click-acceptance/build-manifest.json`。
- 未创建 tag、未发布、未 push。

## 开发版启动确认

- 测试包：`build/short-click-acceptance/MacMouseGesture Short Click Dev.app`。
- 实际可执行路径（内核 proc_pidpath 核实）：`build/short-click-acceptance/MacMouseGesture Short Click Dev.app/Contents/MacOS/MacMouseGesture`。
- 测试版本：`0.2.0-beta.1-shortclick-dev / Build 18`（仅测试包 Info.plist；源码版本号未修改）。
- 当前 PID：40734；原 Build 17 通过 SIGTERM 的正常退出路径退出。
- 重新构建前后源码 SHA-256 均一致；签名后严格验证通过。
- 开发版和稳定版使用同一 Bundle ID 及固定证书指定要求；设置已备份至 `build/short-click-acceptance/pre-acceptance-settings.plist`。测试配置会共用本机设置域，稳定 App 文件保持原样。
- 实际 UI：辅助功能“已开启”、服务“正在运行”，没有出现路径变更后的辅助功能失效。
- 实际 UI 初始配置已设为：侧键 4 短按“显示桌面”，侧键 5 短按“无操作”；两键、横纵手势均启用。
- 稳定版 Info.plist 及可执行文件 SHA-256 与操作前完全一致。
- Input Monitoring 为可选诊断权限，当前服务正常运行；不需要为 Test 1 额外开启或重置权限。

## 第一阶段：短按与拖动冲突

初始目标配置：侧键 4 = 显示桌面；侧键 5 = 无操作。

| 测试 | 内容 | 结果 |
|---|---|---|
| Test 1 | 正常短按侧键 4，只显示桌面一次 | PASS（Build 19 复测；Build 18 曾 FAIL） |
| Test 2 | 连续短按侧键 4，无漏触发/双触发 | PASS（Build 19） |
| Test 3 | 轻微自然抖动后松开仍为短按 | PASS（Build 19） |
| Test 4 | 侧键 4 左拖 Space，无额外显示桌面 | PASS（Build 19） |
| Test 5 | 侧键 4 右拖 Space，无额外显示桌面 | PENDING |
| Test 6 | 侧键 4 上拖 Mission Control，无额外短按 | PENDING |
| Test 7 | 侧键 4 下拖 App Exposé，无额外短按 | PENDING |
| Test 8 | 越过阈值后回起点松开，不恢复短按资格 | PENDING |
| Test 9 | 手势取消，无短按且状态释放 | PENDING |
| Test 10 | 快速交替点击两键，配置与状态独立 | PENDING |

## 后续阶段

- 第二阶段：10 个系统动作逐项测试，第一阶段全 PASS 后才开始。
- 第三阶段：快捷键录制、执行、修饰键限制、取消、清除、重启持久化。
- 第四阶段：原有四方向、两键、反转、连续操作、无残留、空闲 CPU 回归。
- 每次仅提供一个测试动作，收到用户实际反馈后才记 PASS/FAIL。
- 异常立即停止后续验收，记录复现、预期、实际和原因假设；不直接大改代码。

## 当前总结

第一阶段：4/10 PASS（Build 19；6 项待执行）
第二阶段：0/10 PASS（未开始）
第三阶段：未开始
第四阶段：未开始
总体：PARTIAL（用户决定结束本轮验收）

## Test 1 失败记录

- 用户反馈：没反应。
- 复现条件：开发验收版 Build 18，侧键 4 短按为显示桌面、侧键 5 为无操作；正常短按侧键 4，不拖动。
- 预期：松开时执行一次显示桌面。
- 实际：没有可见响应。
- 初步原因：待检查实际动作配置、侧键输入、短按执行日志和系统显示桌面绑定；暂不归因。
- 是否增加日志：现阶段先读取已有诊断信息，不修改代码。

### Test 1 只读定位结果

- 从运行中的开发版 UI 导出现有诊断至 `build/short-click-acceptance/test1-failure-diagnostics.txt`。
- 权限：Accessibility=true、Input Monitoring=true；Event tap=enabled；gestureState=idle；open=0、sequenceErrors=0、postFailures=0。
- 当前配置文件和 UI 一致：CG 3（侧键 4）=showDesktop，CG 4（侧键 5）=none。
- 整个进程输入计数：Button4Downs=0，Button5Downs=49。现场日志有多次 Button5 DOWN/UP（cg=4），部分点击 dx=0、dy=0、emitted=0；没有 Button4 输入证据。
- 初步怀疑：正在用于测试的物理侧键被系统/鼠标驱动识别为侧键 5，因此按当前 none 配置不会执行显示桌面；需要单独点另一颗物理侧键确认映射。尚不认定系统 F11 回退是本次根因。
- 显示桌面系统绑定 36 缺失，后端会回退 F11，仍是后续待验证限制。
- 现有日志足以定位到按钮映射疑点，暂不需要增加日志或改代码。
- 下一步仅进行一次按钮映射定位：短按另一颗物理侧键一次；不进入 Test 2 或后续阶段。

### 两颗物理侧键复核反馈

- 用户反馈：两个按键都没反应。
- Test 1 继续 FAIL，按钮映射疑点尚不足以解释全部现象。
- 后续验收保持暂停；继续读取最新输入日志、系统显示桌面实际绑定和动作执行路径。
- 暂不修改代码或系统设置。

### 第二轮定位证据

- 最新 UI 显示两颗侧键现在均设置为“显示桌面”（用户在复核期间调整）。
- 最新进程诊断：Button4Downs=5，Button5Downs=63；两颗均有正常 DOWN/UP。多次点击 total dx=0、dy=0、emitted=0，输入确实到达且未形成拖动手势。Event tap=enabled，gestureState=idle，Accessibility=true、Input Monitoring=true、open=0。
- 单独只读查询 WindowServer 当前系统热键：显示桌面 id=36，enabled=true，result=0，keyCode=103（F11），modifierFlags=8388608（0x800000，功能键/secondaryFn 标记）。
- 持久化偏好中 id=36 缺失；当前执行器因而回退为 keyCode=103、modifierFlags=0。keyboard() 显式覆盖事件 flags，所以输出与系统实际运行绑定不一致。
- 初步原因转为显示桌面输出的功能键标志/系统默认绑定读取不完整；不再仅归因于两颗物理按钮映射。现有日志未记录成功动作输出，所以执行路径仍保留有限不确定性。
- 只读查询同时发现启动台 id=160 disabled=true、keyCode=65535；未开始启动台真机测试，不计 FAIL/PASS。
- 未修改源码、系统设置或稳定版。辅助只读程序位于 build/short-click-acceptance/read-system-hotkeys，未集成到 App。
- 下一步一个诊断动作：由用户物理键盘按 Fn（🌐）+F11 一次，确认系统原生显示桌面能否响应。Test 1 仍 FAIL，后续阶段暂停。
- 是否增加日志：当前证据已足够指出动作输出不匹配；若以后进行小范围修正，可补实际解析键码/flags 与点击抑制原因日志，不需要重构手势核心。

### 原生系统快捷键确认结果

- 用户手动按 Fn（🌐）+F11：正常显示桌面。
- 诊断动作结果：PASS；该结果仅证明系统显示桌面功能和原生快捷键可用，不将侧键 Test 1 改为 PASS。
- 根因定位：本机 WindowServer 默认显示桌面绑定为 keyCode=103、modifierFlags=8388608（0x800000，secondaryFn）。持久化偏好缺少 id=36，开发版回退为 keyCode=103、modifierFlags=0，并覆盖键盘事件 flags。该回退与系统实际绑定不一致；两键输入正常，权限正常，用户原生快捷键响应正常，共同支持此输出缺陷为本次失败原因。
- 建议最小修复：只修正显示桌面回退的功能键标记；增加缺省系统偏好时功能键 flags 保留的回归测试，以及简洁的短按动作解析/执行日志。保留原有手势核心、阈值、时序、稳定版和系统设置。
- 修复后应先运行全部自动化测试，再生成独立开发验收包，从 Test 1 重新验收；当前未执行修复。
- 后续阶段仍全部暂停。

## Build 19 最小修复

- 用户授权直接处理定位明确的工作，无需逐项确认。
- 显示桌面缺省绑定改为 keyCode=103、modifierFlags=0x800000；显式系统绑定保留自己的修饰键。
- 增加短按 accepted/suppressed、系统动作实际 keyCode/flags 与提交结果日志；不记录用户键盘输入或自定义快捷键内容。
- 新增 3 项回归检查：真实设备默认绑定、显式绑定修饰键保留、提交成功/失败诊断。
- 111 项回归 + 15 项 Bridge 合约 = 126 PASS，0 FAIL、0 SKIP。结果：`build/short-click-acceptance/f11-fix-test-output.txt`。
- 手势核心与原生 Bridge 未改，系统偏好和稳定版未改。
- 原 Test 1 FAIL 保留；修复后从 Test 1 重新验收，不能用自动化结果替代真机结果。

### Build 19 启动与复测准备

- PID：42186；proc_pidpath 核实路径：`build/short-click-acceptance/build19/MacMouseGesture Short Click Dev.app/Contents/MacOS/MacMouseGesture`。
- 源码哈希与构建前记录相符；签名验证通过；稳定 Build 17 可执行文件与 Info.plist 哈希不变。Build 18 验收包保留。
- UI：服务正在运行，辅助功能已开启；侧键 4=显示桌面，侧键 5=无操作，两键及横纵手势均开启。
- Build 19 Test 1：PENDING，等待用户正常短按侧键 4 一次反馈。

### Build 19 Test 1 复测结果

- 用户反馈：A（正常显示桌面，只触发一次）。
- Test 1：PASS。原 Build 18 失败及诊断历史保留。
- F11 功能键标记修复经本次真实侧键点击验证有效。
- 下一项 Test 2：侧键 4 连续短按 5 次，每次间隔约 1 秒，观察每次仅触发一次显示桌面/恢复窗口切换，无漏触发或双触发。

### Build 19 Test 2 结果

- 用户反馈：A（连续短按 5 次，每次间隔约 1 秒，全部正常，无漏触发或双触发）。
- Test 2：PASS。
- 下一项 Test 3：按住侧键 4，产生很轻微的自然抖动后松开；预期仍执行一次显示桌面/恢复窗口切换。

### Build 19 Test 3 结果

- 用户反馈：A（轻微自然抖动后松开，正常切换显示桌面，只触发一次）。
- Test 3：PASS。
- 下一项 Test 4：侧键 4 按住左拖并松开，预期原有 Spaces 手势正常，松开后不额外显示桌面。

### Build 19 Test 4 结果

- 用户反馈：A（左拖切换 Space 正常，松开后没有额外显示桌面）。
- Test 4：PASS。
- 下一项 Test 5：侧键 4 按住右拖并松开，预期原有 Spaces 手势正常，松开后不额外显示桌面。

## 本轮真机验收结束

用户表示“不用测试了”，停止后续手动验收，不再要求用户执行 Test 5 或后续步骤。

- 第一阶段：4/10 PASS（Test 1–4）；Test 5–10 未执行。
- 第二阶段：0/10 PASS，未执行。
- 第三阶段：未执行。
- 第四阶段：未执行。
- 总体：PARTIAL。
- 已确认：普通短按、连续 5 次短按、轻微抖动后的短按、左拖切换 Space 且无额外短按。
- 已修复并真机确认：显示桌面默认 F11 输出遗漏功能键标记。
- 自动化：111 项回归及 15 项 Bridge 合约全部 PASS（共 126 项）；不能替代未执行的真机项。
- 稳定 Build 17 未覆盖或删除；未创建 tag、未发布 Release、未 push 发布版本。
- 本次结束只停止验收流程，不退出或切换当前运行的开发版。
