# 现有短按动作审计（macOS 27）

审计基线：Build 19。先审计后修改。本轮只处理 Mission Control；“显示桌面”已经真机 PASS，冻结。其他动作尚未完成逐项真机验收，不能因事件提交或自动化测试通过而宣称可用。

| 动作 | 当前实现（修改前） | 真机状态 | 依赖快捷键 | 依赖前台 App / 系统条件 |
|---|---|---|---|---|
| 无操作 | 不发送输入 | 按钮配置逻辑自动化已覆盖 | 否 | 否 |
| 显示桌面 | 读取系统绑定；缺省 F11 + secondaryFn | PASS（Build 19） | 是 | 系统显示桌面绑定 |
| Mission Control | VerticalGestureTracker 一次从 0 移至 1，立即 finish；sendVertical 发送 began(1)、ended(1) | PASS（Build 20，已改为 0.2 秒 / 120 Hz 单次渐进 HID，已冻结） | 否 | macOS 27 HID/Dock 后端、辅助功能 |
| App Exposé | 同上，负进度；同一调用内 began(-1)、ended(-1) | UNKNOWN | 否 | 纵向后端、当前应用窗口；尚无专门前置检查 |
| Launchpad | 旧 symbolic hotkey 160 / 缺省 F4 | 未验证；本机运行时 hotkey 160 disabled、keyCode=65535，旧模型不适配现系统 | 是 | 传统启动台入口；后续应改“应用浏览”或明确不支持，保留旧解码 |
| 最小化 | ⌘M 键盘事件 | UNKNOWN | 是 | 前台 App 的快捷键支持；当前没有 AX 窗口检查 |
| 全屏 / 退出全屏 | ⌃⌘F 键盘事件 | UNKNOWN | 是 | 前台 App 的快捷键支持；当前没有 AX full-screen 检查 |
| 锁屏 | ⌃⌘Q 键盘事件 | UNKNOWN | 是 | 系统会话快捷键；尚未核实实际锁定/解锁恢复 |
| 播放 / 暂停 | systemDefined subtype 8，NX_KEYTYPE_PLAY 的 down/up | UNKNOWN | 否（媒体键） | 系统媒体接收者，音乐与浏览器均待测试 |
| 返回 | ⌘[ | UNKNOWN | 是 | App/键盘布局；当前不是原生 mouse back |
| 前进 | ⌘] | UNKNOWN | 是 | App/键盘布局；当前不是原生 mouse forward |
| 自定义快捷键 | keyDown/keyUp 均附配置 flags；未显式发送 modifier down/up | UNKNOWN | 是 | 前台 App；录制、修饰键释放、重启完整验收待做 |

## Mission Control 与连续手势的差异

当前连续上拖：已有机器负责按钮、deadZone、轴锁定；VerticalGestureTracker 在现有 120 Hz 定时器中逐帧产生 began、小幅 changed、继续 changed，最终 ended/cancelled；调用既有 MacOS27GestureBackend.sendVertical → MGPostVertical，原生 Bridge 每次构建独立 HID payload、时间戳与 phase。

当前短按：在一次同步调用中直接设置 totalY=-300，使 progress=1，再立即 finish。得到 began(1)、ended(1)，没有中间 changed，也没有真实帧间隔。后端 Bool 只证明成功构建并请求投递，不是 Dock 的执行确认。

已明确找到短按时序与已工作的连续路径不一致。缺少真实渐进帧是当前首要原因假设；是否为 Dock 不响应的全部原因仍须修复后真机验证，不能仅凭代码推断已经修好。

## 本轮边界

只为 Mission Control 增加有真实时间间隔的 one-shot 封装，复用现有 VerticalGestureTracker 与 sendVertical，不复制旧 undocumented CGEvent gesture fields。GestureMachine、VerticalGestureTracker、Bridge、deadZone、短按判定规则均冻结。

新增必要的类型化执行结果和轻量诊断，仅将 Mission Control 接入该结果路径。其他动作保留审计结果，等待用户逐项确认后依次修复。日志不得包含窗口标题、文档名或用户输入内容。

修复顺序：Mission Control → 真机 PASS 后冻结 → App Exposé。其他动作不在本轮同时改动。

## 当前验收进度

显示桌面：Build 19 真机 PASS，冻结。Mission Control：Build 20 真机 PASS（用户回复 A），冻结。接下来仅修复 App Exposé，其余动作继续 UNKNOWN。

App Exposé：Build 21 自动化 PASS（19 项新增，总计 159 PASS），已改为渐进单次下拖 HID、前台 AX 窗口检查及 Dock 开关诊断。真机 PENDING，尚未冻结。

2026-10-02：用户回复 A，确认 Build 21 App Exposé 真机 PASS，冻结。现在仅处理最小化；全屏及其后动作继续 UNKNOWN。

2026-10-02：最小化已在 Build 22 改为公开 AX focused/main window + AXMinimized 写入与能力/焦点检查。新增 20 项测试，总计 179 PASS。真机 PENDING。其余动作未同时修复。

2026-10-04：用户回复 A，Build 22 最小化真机 PASS，冻结。现在仅处理全屏；后续动作继续 UNKNOWN。

2026-10-04：全屏 Build 23 自动化 PASS（24 项新增，总计 203 PASS），采用运行时可写全屏属性或公开全屏按钮。进入/退出真机均 PENDING，尚未冻结。

全屏专项最新反馈：用户回复 A，进入全屏 PASS；退出全屏 PENDING。保持 Build 23 和相同动作配置，不修改代码、不推进返回动作。

全屏进入和退出均收到用户正常反馈，完整切换 PASS，冻结 Build 23 路径。接下来只处理返回；前进及其后动作继续 UNKNOWN。

返回 Build 24：已替换为带标记的原生 button 3 down/up；监听入口仅放行本进程的合成侧键事件，原物理输入/连续手势未变。新增 20 项测试，总计 223 PASS。独立开发包已启动、权限开启、实际路径已核实；Chrome 独立三页历史已准备，停在第 3 页。Chrome/Safari/Finder 真机均 PENDING，尚未冻结，不推进前进。

2026-10-04：用户回复 A，确认 Chrome 第 3 页短按侧键 4 后只返回一次至第 2 页，Chrome 返回 PASS。继续准备 Finder 单项验收；Safari、Finder 仍 PENDING，返回动作尚未冻结。

2026-10-04：用户回复 B，Finder 返回没有反应，记为 FAIL。暂停后续验收，仅检查现有诊断和 Finder 历史/兼容性；Chrome PASS 保留，不推进前进，不直接修改代码。

Finder 定位：Build 24 内存日志确认 short-click accepted、frontmost=com.apple.finder、nativeMouse-button3 配对事件 submitted；权限开启、引擎 idle、open=0。Finder 自带返回按钮启用且实际可导航，检查后前进恢复原位置。初步为当前合成返回事件与 Finder 的兼容问题；不能凭投递 success 宣称应用处理成功。日志暂不需增加；代码/配置未改，验收暂停。
