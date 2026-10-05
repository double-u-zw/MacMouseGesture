# 最小化当前窗口专项修复与验收

状态：自动化 PASS；2026-10-04 用户回复 A，Build 22 最小化真机 PASS，执行路径冻结。

## 已冻结动作

显示桌面：Build 19 PASS。Mission Control：Build 20 PASS。App Exposé：Build 21 PASS，2026-10-02 用户回复 A。后两者实现文件保持原哈希一致。

## 审计与修复

旧最小化只发送 ⌘M，依赖前台应用的快捷键处理，没有窗口或能力检查。当前用户尚未验收这一动作，不能将旧实现标记为可用，也不能声称已经证明某个真机失败的唯一原因。

新增 MinimizeWindowAction，使用公开 macOS AX API。先获取当前前台应用，再读取 AXFocusedWindow；仅在该属性缺少值/不支持时回退 AXMainWindow。不会任意选择窗口列表中的其他窗口，不切换应用，不发送键盘 fallback。

读取 AXMinimized，已最小化时保持不动；检查 AXUIElementIsAttributeSettable 后，通过 AXUIElementSetAttributeValue 设置 AXMinimized=true。执行前重新核对辅助功能权限、前台应用和 focused/main 窗口身份，焦点变化就取消，避免操作错误窗口。

没有前台应用、没有窗口、不支持/不可写、权限失效、AX 消息超时或失效对象、setter 拒绝均返回可诊断结果。读取与设置使用有界 AX 消息超时。窗口标题和用户内容不被读取或记录。

setter 返回成功后读取属性并记录 observedMinimized；某些应用的动画异步完成，因此 success 明确表示 AX 请求被接受，不将尚未完成的动画或不可用 readback 静默冒充真机 PASS。日志记录 button/action/nativeAX/frontmost/windowFound/result/失败阶段与 AXError；实际表现继续等待用户一次物理点击。

## 自动化

新增 20 项，覆盖 focused/main 选择及回退、无窗口、无前台应用、权限否决/丢失、不支持/不可写、AX 查询及 setter 错误、只设置一次、已最小化幂等、应用/窗口变化保护、执行前重新检查失败、异步及不可用 readback 的显式诊断、日志字段、executor 真正走 AX 且失败时不发送键盘 fallback。

旧泛化键盘映射测试移除最小化的旧 ⌘M 断言，由新 executor AX 路由检查取代，未删减测试项目。其他动作映射、短按/拖动、Mission Control、App Exposé、连续手势回归保持通过。

结果：164 项回归 + 15 项原生 Bridge = 179 PASS，0 FAIL，0 SKIP。AX 边界使用注入假对象；原生事件投递被拦截；测试没有最小化真实窗口。输出：build/short-click-acceptance/minimize-test-output.txt。

## 代码范围

- 新增 Sources/MouseGesturePOC/MinimizeWindowAction.swift。
- MouseButtonActionExecutor.swift 仅增加最小化封装注入，替换 minimizeWindow 分支；逆向移除这几处接线后，源码哈希与 Build 21 完全一致，证明其余动作执行路径未变。
- 新增 Tests/CoreRegression/MinimizeWindowActionTests.swift；更新动作映射测试、测试注册和 scripts/test.sh 编译源列表。
- GestureEngine、GestureMachine、VerticalGestureTracker、Bridge、SideButtonClickTracker、AppConfig、MissionControlAction、AppExposeAction 均与 Build 21 冻结哈希一致。没有改动手感、deadZone、短按/拖动规则或原有动作生命周期。

## 开发包

- 独立 Build 22，实际 PID 56708.
- 内核核实实际执行路径：build/short-click-acceptance/build22/MacMouseGesture Short Click Dev.app/Contents/MacOS/MacMouseGesture
- 源码哈希与当前构建清单一致，签名使用已有固定证书并通过验证。
- 辅助功能已开启，服务正在运行。
- 已核对实际保存：侧键 4=最小化窗口；侧键 5=显示桌面。配置备份与当前配置对比，仅侧键 4 短按动作变化，其他设置保持一致。
- 稳定 /Applications/MacMouseGesture.app 仍为 Build 17，plist/可执行文件哈希未变，所有旧开发包保留。
- 未创建 tag、Release，未 push。

## 一次真机验收

普通窗口处于前台时，正常短按侧键 4 一次，不拖动。

A 当前窗口正常最小化一次 / B 没有反应 / C 其他现象。

结果：PASS。2026-10-04 用户回复 A，确认当前窗口正常最小化。冻结 MinimizeWindowAction.swift，进入全屏专项。

限制：需要目标应用通过 AX 暴露 focused/main window 和可写 AXMinimized；不支持的窗口返回 unsupported，不为了追求全局可用修改其他动作或引入私有实现。
