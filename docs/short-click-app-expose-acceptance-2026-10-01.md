# App Exposé 短按专项修复与验收

状态：自动化 PASS；2026-10-02 用户回复 A，Build 21 真机 App Exposé 短按 PASS，执行路径冻结。

## 前置验收

显示桌面：Build 19 真机 PASS，冻结。Mission Control：Build 20 真机 PASS，用户回复 A，冻结。当前只处理 App Exposé，其他动作未同时修改。

## 审计与修复

旧实现同一同步调用发出 began(-1)、ended(-1)，没有更新帧或真实帧间隔。与正常连续下拖的时序不一致；这是本轮修复依据，是否解决真机问题仍由用户验收确认。

新增 AppExposeAction，复用已通过 Mission Control 真机验收的独立单次驱动，将 progress 和 velocity 同时取负，发送现有 App Exposé 下拖 HID 方向。约 0.2 秒、120 Hz，先 began(-0.02)，逐步 changed，最后 ended(-1)。MissionControlAction.swift 文件保持 Build 20 哈希一致，没有第二套 CGEvent 私有字段实现。

执行前通过 NSWorkspace 取得前台应用，使用公开 AX focused/main/windows 属性确认存在窗口（允许只有已最小化窗口的应用），不切换或激活其他应用；读取 com.apple.dock 的 showAppExposeGestureEnabled。本机显式为 1，已启用。显式 false 安全返回 systemFeatureUnavailable；没有存储覆盖值时记录 notOverridden，不伪称已确认系统启用，也不误将键盘快捷键开关当作手势开关。

没有应用、没有窗口、AX 不支持、AX 读取失败、权限缺失/丢失、后端不可用、投递失败均给出类型化结果与原因；窗口检查中前台切换则取消，不向错误应用投递。日志仅包含按钮、动作、路径、应用标识、系统开关、阶段、帧数、结果、原因，不读取或记录窗口标题与用户内容。

新的物理按钮按下、进入已有拖动、tap 恢复、停止/退出均取消 App Exposé 单次动作。两种短按纵向动作不能同时提交；互相取消未完成序列。原有 Mission Control 物理拖动优先策略保持不变。

请求 success 只表示异步请求已接受，stage=complete success 只表示 HID 序列完整提交，不能证明 Dock 已打开概览。真实响应须由下方验收确认。

## 自动化

新增 19 项，覆盖下拖初始进度、更新时序、负进度/负速度、一次完成、延迟交付、无重复、权限否决/丢失、前台与窗口缺失、AX 不支持/失败/前台变化、系统禁用/无覆盖值、后端不可用、重叠请求保护原目标、开始/更新/结束失败、取消和重启、非法时间、诊断字段、executor 互斥与生命周期取消。

更新原动作映射检查，确认 App Exposé 转交给渐进单次封装。原 Mission Control 的 14 项专项全部继续 PASS，原短按/拖动及手势回归继续 PASS。

结果：144 项回归 + 15 项原生 Bridge 合约 = 159 PASS，0 FAIL，0 SKIP。测试投递均被拦截，无真实系统动作注入。输出：build/short-click-acceptance/app-expose-test-output.txt。

## 开发包核验

- Build 21，PID 46636.
- 实际内核可执行路径：build/short-click-acceptance/build21/MacMouseGesture Short Click Dev.app/Contents/MacOS/MacMouseGesture
- 编译前/后源码哈希一致；构建清单：build/short-click-acceptance/build21/build-manifest.json。
- GestureMachine、VerticalGestureTracker、原生 Bridge、SideButtonClickTracker、AppConfig、MissionControlAction 与 Build 20 冻结哈希一致；手感参数和短按/拖动规则未修改。
- GestureEngine 仅增加 App Exposé 动作取消调用；executor 仅接入 App Exposé 封装和两种单次纵向动作互斥，其他动作实现保持原样。
- 原有固定证书签名验证通过；辅助功能已开启，服务正在运行。
- 已保存并核验：侧键 4 = 应用 Exposé，侧键 5 = 显示桌面；两颗侧键与四方向均启用，原手感设置保留。
- 稳定 /Applications/MacMouseGesture.app 仍为 Build 17，Info.plist 与可执行文件哈希未变；Build 20 和其他旧开发包保留。
- 未创建 tag、Release，未 push。

## 一次真机验收

正常短按侧键 4，不拖动。预期：打开当前前台应用的窗口概览一次。用户选择 A 正常打开一次 / B 没有反应 / C 其他现象。

结果：PASS。2026-10-02 用户回复 A，确认当前应用窗口概览正常打开一次。冻结 AppExposeAction.swift，进入最小化专项。
