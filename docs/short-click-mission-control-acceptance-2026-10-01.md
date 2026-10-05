# Mission Control 短按专项修复与验收

状态：自动化 PASS；Build 20 真机短按 PASS，执行路径冻结。

## 审计结论与范围

完整动作表见 `short-click-action-audit-2026-10-01.md`。本轮只处理 Mission Control；显示桌面在 Build 19 的真实侧键测试已 PASS，执行路径保持冻结。

旧短按在一次同步调用内发出 began(1)、ended(1)，省略了已有连续上拖路径中的更新帧和真实时间间隔。该差异是当前首要失败原因假设，不能在真机确认前宣称 Dock 已正常响应。

修复使用独立 `MissionControlAction` 单次封装，在约 0.2 秒中以 120 Hz 逐步推进现有 VerticalGestureTracker，调用既有 MacOS27GestureBackend.sendVertical；开始进度为 0.02，最终进度为 1，再结束。既有 GestureMachine、VerticalGestureTracker、原生 Bridge、deadZone、短按判定和连续手势参数均未修改。

新的物理侧键按下或已有待点击按钮进入拖动时，取消尚未结束的单次动作，让原有物理手势优先；服务停止、tap 恢复、退出和权限丢失时清理单次序列，避免叠加或残留。原 App 失焦的待点击清理逻辑保持不变；启动 Mission Control 本身造成的焦点变化不会中途取消已接受的动作。

App Exposé、窗口、导航、媒体、快捷键、锁屏、原 Launchpad 执行路径本轮未修复，也未标记真机 PASS。

## 诊断

引入 ActionExecutionResult：success、unsupported、permissionDenied、noFrontmostApplication、noFocusedWindow、systemFeatureUnavailable、eventPostFailed、unknownFailure，另有 cancelled。本轮 Mission Control 接入该结果路径，其他动作将在各自修复轮次接入。

日志记录按钮、动作、执行器、前台应用 bundle identifier（缺少时仅 PID）、请求/调度/完成阶段、帧数、结果和原因，不记录窗口标题、用户输入或文档内容。

请求阶段的 success 表示接受异步执行；只有 stage=complete 表示序列已完整提交。CGEventPost 无 Dock 响应确认，完整提交仍须用本项真机反馈验收。

## 自动化

新增 14 项 Mission Control 专项检查，覆盖初始小进度、真实时间驱动的多帧渐进、延迟交付时最终更新、一次开始/结束、无重复、权限否决/丢失、缺少前台应用、后端不可用、重复请求防交错、开始/更新/结束投递失败、取消清理与重新执行、非法时间、诊断字段。

更新原动作映射测试，验证 executor 真的转交给渐进单次封装；原 App Exposé 双帧行为仍如审计记录，留待下一轮。

结果：125 项回归检查全部 PASS；15 项原生 Bridge 合约全部 PASS。总计 140 PASS、0 FAIL、0 SKIP。投递边界被测试拦截，无真实系统动作注入。输出：`build/short-click-acceptance/mission-control-test-output.txt`。

## 真机

只进行一次：侧键 4 短按 → Mission Control。预期松开后打开调度中心一次，无需拖动。等待用户选择：正常打开一次 / 无反应 / 其他异常。

本项真机结果：PASS。用户回复 A，确认侧键 4 短按正常打开 Mission Control 一次。

Mission Control 真机 PASS 后才冻结本项、进入 App Exposé；若无效，保持本项进行中，读取当前单次执行结果并继续定位，不同时推进其他动作。

稳定 Build 17 保留，不创建 tag、不发布 Release、不 push 发布构建。

## 开发包准备完成

- Build 20，实际 PID 45278。
- 内核核实实际可执行路径：`build/short-click-acceptance/build20/MacMouseGesture Short Click Dev.app/Contents/MacOS/MacMouseGesture`。
- 源码哈希与构建记录一致；GestureMachine、VerticalGestureTracker、Bridge 哈希与冻结 Build 19 一致。
- 签名验证通过；辅助功能已开启，服务正在运行。
- 侧键 4 短按：调度中心；侧键 5 保留显示桌面。已确认实际保存配置。
- 稳定 Build 17 的 Info.plist 与可执行文件哈希保持不变；旧开发包均保留。
- 用户一次真实短按侧键 4 已确认 PASS；冻结 MissionControlAction.swift，随后进入 App Exposé 专项。
