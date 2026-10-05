# 全屏 / 退出全屏专项修复与验收

状态：自动化 PASS；独立 Build 23 已启动。进入全屏 PASS（用户回复 A），退出全屏 PASS（用户确认可以退出）；完整切换真机 PASS，执行路径冻结。

## 已冻结动作

显示桌面：Build 19 PASS。Mission Control：Build 20 PASS。App Exposé：Build 21 PASS。最小化：Build 22 PASS（2026-10-04 用户回复 A）。本轮只处理全屏，不修改其他动作或原有手势。

## 审计与实现

旧实现仅发送 ⌃⌘F，依赖应用快捷键，未确认目标窗口支持全屏。新 FullScreenWindowAction 通过 AX 获取 frontmost application 的 focused window；缺少值/不支持时才回退 main window，不任意选择其他窗口。

检查窗口是否已最小化，并检查实际全屏能力：

1. 只有窗口 AXUIElementCopyAttributeNames 明确暴露 AXFullScreen、其值为 CFBoolean、属性可写时，读取当前状态并写入相反值：普通→true，全屏→false。
2. 不能写该属性时，读取官方 kAXFullScreenButtonAttribute，确认按钮启用并支持 AXPress，调用一次 AXUIElementPerformAction。
3. 两者都不支持，返回 unsupported。权限、AX 通信、类型异常直接失败，不把错误隐藏为另一种成功。不使用键盘 fallback，也不在 setter/press 失败后重试另一种方式，避免重复动作。

AXFullScreen 是运行时兼容属性，本机 SDK 未提供公开常量，不能宣传为公开且保证稳定的标准。写入仅限目标应用明确暴露且可写的能力。全屏按钮使用 SDK 文档中的公开属性与 AXPress；没有新增私有 C API、Shell、AppleScript 或修改用户系统快捷键。

依据：本机 macOS SDK AXAttributeConstants.h 的 kAXFullScreenButtonAttribute 注释及 Apple 官方文档 https://developer.apple.com/documentation/applicationservices/kaxfullscreenbuttonattribute 。

操作前再次确认权限、前台应用、窗口身份和已读取的全屏状态。它们在检查期间改变就取消，避免切换错误窗口或反向翻转已变化状态。最小化的目标窗口直接返回 unsupported。

日志分别标明 nativeAX-preflight、nativeAX-attribute 或 nativeAX-fullScreenButton，并记录按钮、应用标识、目标方向、windowFound、结果、AXError 和失败阶段；不读取窗口标题或用户文本。

AX API 接受请求后记录 observedFullScreen。应用动画可能异步，success 只表示 API 请求被接受，未观察到动画完成时不会据此标记真机 PASS。进入和退出各需一次用户反馈。

## 自动化

新增 24 项，覆盖普通进入、全屏退出、交替方向、focused/main 选择、无窗口/无应用、不支持、权限否决/丢失、最小化窗口、异常状态/通信错误、只读或无全屏状态时的官方按钮路径、按钮禁用/缺少 AXPress、无可用路径、应用/窗口/全屏状态变化保护、setter/press 拒绝时不重试、异步/不可用 readback、日志字段、executor 路由和无键盘 fallback。

旧泛化键盘映射中的全屏 ⌃⌘F 断言由新的 AX executor 路由测试取代，没有删减测试项目。

结果：188 项回归 + 15 项原生 Bridge = 203 PASS，0 FAIL，0 SKIP。AX 使用注入假对象，原生投递被拦截，没有切换真实窗口。输出：build/short-click-acceptance/full-screen-test-output.txt。

## 代码与冻结保护

新增 Sources/MouseGesturePOC/FullScreenWindowAction.swift、Tests/CoreRegression/FullScreenWindowActionTests.swift。更新 MouseButtonActionExecutor 的全屏接线、测试注册、测试编译列表与旧键盘映射断言。

从 executor 源码逆向移除仅这几处全屏接线后，哈希与 Build 22 一致，证明其他执行路径未变。GestureEngine、GestureMachine、VerticalGestureTracker、Bridge、SideButtonClickTracker、AppConfig、MissionControlAction、AppExposeAction、MinimizeWindowAction 均与 Build 22 冻结哈希一致。未改动阈值、方向、连续手势、收尾、短按判定或最小化代码。

## 开发包准备

- Build 23，PID 18180.
- 内核核实实际路径：build/short-click-acceptance/build23/MacMouseGesture Short Click Dev.app/Contents/MacOS/MacMouseGesture
- 当前源码哈希与构建清单一致；已有固定证书签名验证通过。
- 设置界面确认服务正在运行、辅助功能已开启。
- 保存配置：侧键 4=全屏 / 退出全屏；侧键 5=显示桌面。除侧键 4 的短按动作外，其他配置与启动前备份完全一致。
- 切换开发包前看到用户当前侧键 4 配置为锁屏，已备份；不据此推断锁屏已验收。本轮 A 仍按用户对上一项最小化测试的反馈记录。
- 稳定 /Applications/MacMouseGesture.app 的 Build 17 plist/可执行文件哈希未变；Build 22 与旧开发包保留。
- 未创建 tag、Release，未 push。
- Finder 自动测试窗口准备失败：CUA getApp 返回 cgWindowNotFound。没有宣称已准备 Finder 窗口；需要用户让普通 Finder/浏览器窗口处于前台再做一次短按。该工具错误不属于全屏动作真机 FAIL。

## 分步真机验收

进入全屏：PASS。用户回复 A，确认正常短按侧键 4 后，当前窗口正常进入全屏。

退出全屏：PASS。用户回复“可以推出”（按本项上下文记录为可以退出），确认正常恢复普通窗口。完整全屏切换 PASS，冻结 FullScreenWindowAction.swift。

两次反馈都 PASS 后才冻结本动作并进入返回专项；任一异常就停在本项定位，不开始下一动作。

限制：仅支持暴露可写全屏属性或可按全屏按钮的应用窗口；未宣称所有应用或窗口全局可用。
