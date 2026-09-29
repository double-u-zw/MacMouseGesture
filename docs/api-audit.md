# API 审计 — 0.2.0 Productization Phase 0

审计日期：2026-09-29。基线：`e69aded137b3a8ed6dc635732fcb4926fe811ce9`（`v0.1.6-build12` 解引用后），0.1.6 / Build 12。没有修改运行时代码。

## 结论

**当前左右 Spaces、上调度中心、下应用 Exposé 均依赖 private / undocumented API。**公开的 CGEventTap 负责捕获输入，公开的 CGEventPost 负责投递外壳；中间生成可被 Dock 理解的连续手势，依赖私有 HID 对象、SkyLight 附加函数及未公开的事件协议。动态加载不会使私有 API 变为公开 API。

**No documented equivalent found**：在下述 Apple 文档与 SDK 检索范围中，没有找到能连续、可逆、按 progress 控制这三类系统动画的公开等价接口。此结论不是“绝对不存在任何未来或遗漏接口”。分发条款的适用范围另见 [分发审计](distribution-audit.md)，不能只凭这个技术分类作法律结论。

## 范围、方法与证据

逐文件阅读 `Sources/` 全部 18 个文件，检查 `Tests/`、`scripts/`、Package.swift、资源与构建链接项；检查字符串符号、Objective-C runtime、手写 ABI、枚举、field 编码、系统设置 URL、C 桥接与测试入口。纯 Swift 状态机不直接访问系统。

本机 macOS 27.0 (26A428)，Xcode macOS 27 SDK。对 CoreGraphics、IOKit、AppKit、Foundation、CoreFoundation、ServiceManagement、ApplicationServices 的显式公开 Headers 根目录扫描了 725 个头文件；目标私有类/符号/字段命中 0、读取错误 0。最初宽范围 `rg -L` 有 SDK 链接遍历错误，**不使用那次零结果作为证据**。重做后的本地记录：`build/productization-experiments/evidence/public-header-search.txt`。Apple OSS 头文件仅证明源码/协议可以阅读，不等于第三方应用的公开 SDK 合同。

分类：A = Apple documented public API；B = 公开 framework 中未公开的 symbol/API；C = 明确 private / undocumented；D = 尚不能确认。当前发现的高风险项有明确 PrivateFrameworks 路径或未公开协议证据，归 C；没有为了填满分类而虚构 B 项。

表中“文档”指公开应用开发合同；Apple OSS 中的说明单独标注。SDK 栏中的“是”包含公开 C header / Swift interface；“核心”指当前四方向交互路径的直接或基础依赖。“否”不表示可在本轮删除。相关同族函数合并列举，未省略私有 selector。

## 核心注入 API / 协议明细

文件简称 Bridge = `Sources/SystemGestureBridge/SystemGestureBridge.m`。

| Symbol / API | Source file / 位置 | Purpose | Framework | Apple documented? | Public SDK header? | Dynamic? | Core required? | 分类 / Possible replacement | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| `/PrivateFrameworks/HID.framework/HID`、`HIDEvent` | Bridge:42–44 | 创建事件负载类 | private HID | 非公开应用 API；OSS 有接口 | 否 | dlopen + NSClassFromString | 是 | C；无已找到的公开等价 | [HIDEvent OSS][hid]；本机 SDK 扫描 |
| `initWithType:timestamp:senderID:` | Bridge:12、65、72、135、142 | DockSwipe/Velocity 对象构造 | HID | OSS 声明，不是公开 SDK | 否 | ObjC 类动态获取后消息发送 | 是 | C；不能用 IOHIDManagerCreate 替代 | [HIDEvent OSS][hid] |
| `setOptions:`、`options`、`type` | Bridge:13–15、67、99–100、137、171–172 | phase 写入、probe 回读类型 | HID/IOKit 内部 HIDEvent | OSS 继承接口 | 否 | ObjC | 是；读回为当前启动门槛 | C；没有公开事件模型等价 | [IOHIDEventTypes][types] |
| `setIntegerValue:forField:`、`integerValueForField:` | Bridge:16–17、68–69、101–102、138–139、173–174 | motion/flavor 写入与回读 | HID | OSS 有说明 | 否 | ObjC | 是 | C；公开 CGEvent 字段没有同等 Dock 合同 | [HIDEvent OSS][hid] |
| `setDoubleValue:forField:`、`doubleValueForField:` | Bridge:18–19、70、74–76、103、140、144–146、175 | progress 与终结速度 | HID | OSS 有说明 | 否 | ObjC | 是 | C；无公开 progress setter | [HIDEvent OSS][hid] |
| `appendEvent:` | Bridge:20、77、147 | terminal 挂载 Velocity 子事件 | HID | OSS 有说明 | 否 | ObjC | 是 | C；未找到公开等价 | [HIDEvent OSS][hid] |
| `SLEventSetIOHIDEvent` / `AttachFunction` | Bridge:23、43、46、84、154 | HID 附加到 CGEvent | private SkyLight | 未找到公开文档 | 否 | dlopen / dlsym | 是，所有四方向必经 | C；无公开 attachment setter | 明确私有 framework 路径；SDK 无声明；probe 成功 |
| `SLEventCopyIOHIDEvent` / `CopyFunction` | Bridge:24、47、97、169 | 负载回读 | private SkyLight | 未找到公开文档 | 否 | dlsym | 当前启动 probe 必须；不是 post 的必要步骤 | C；删除 probe 不会消除其他私有依赖 | 同上 |
| DockSwipe=23、Velocity=9 | Bridge:31–32、65、72、135、142 | HID 事件类型 | IOKit/HID 私有事件协议 | OSS 可见 | 否（目标 app SDK） | 常量否 | 是 | C；不得因 Apple 开源而写 A | [IOHIDEventTypes][types] |
| `type << 16`；Motion=(23<<16)+1、Progress=+2、Flavor=+5；Velocity X/Y/Z=0/1/2 偏移 | Bridge:31–32、68–76、138–146 | private field 编码 | IOKit/HID 协议 | OSS 可见 | 否 | 否 | 是 | C；重命名 enum 不改变协议来源 | [IOHIDEventFieldDefs][fields] |
| HorizontalX=1、VerticalY=2、DockPrimary=3、phase=1/2/4/8、options `phase << 24` | Bridge:67–69、137–139；`GestureCore/GestureMachine.swift` 的 GesturePhase | 轴、Dock flavor 与生命周期 | IOKit/HID 协议 | OSS 有 phase/type 定义；Dock 消费语义非公开合同 | 否 | 否 | 是 | C；NSEvent.Phase 的相似值不能授权该注入协议 | [types]、[fields]；源代码 |
| `(CGEventType)30` | Bridge:81、151 | 私有 HID wrapper 事件类型 | CoreGraphics 参数的未公开用法 | 不在公开 CGEventType 枚举 | 否 | 否 | 是 | C；即便 AppKit 某枚举有数字 30，也不构成 CG Dock 注入合同 | SDK `CGEventTypes.h:102` 起 |
| `MGBackendProbe/MGVerticalProbe/MGPostHorizontal/MGPostVertical` | Bridge 及 include/SystemGestureBridge.h | 项目自己的封装，不是 Apple API | 项目模块 | 不适用 | 项目 header | 否 | 是 | 内部 API；风险继承上述 C 依赖 | 声明明确写 undocumented |

**没有实际调用** `IOHIDEventCreateDockSwipeEvent`、`IOHIDEventCreate` 或其他 C constructor，也没有 `IOHIDEventSystemClient`。实现使用 Objective-C `HIDEvent` constructor。没有 CGEvent 内存偏移写入、Dock 进程注入、隐藏快捷键 fallback、未声明的额外 framework 链接。

## 公开输入捕获与基础系统 API

下面各行的动态栏“否”指没有 dlopen/dlsym 手动查找；AppKit 自身的消息派发不据此视为私有。

| Symbol / API | Source file | Purpose | Framework | Apple documented? | Public SDK header? | Dynamic? | Core required? | 类别 / Possible replacement | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| `CGEvent.tapCreate` / `CGEventTapCreate`、`CGEventMask`、`.cghidEventTap`、`.headInsertEventTap`、`.defaultTap/.listenOnly` | MouseInput.swift:171 起 | 全局鼠标捕获/拦截；手势时加 keyDown | CoreGraphics | 是 | CGEvent.h / CGEventTypes.h | 否 | 是 | A；NSEvent 监视器不能等价吞事件 | [CGEvent][cg]、[tapCreate][tap] |
| `tapEnable`、`tapIsEnabled`、tapDisabledByTimeout/UserInput | MouseInput.swift | 开关、健康检查与恢复 | CoreGraphics | 是 | 是 | 否 | 是 | A；保留有界恢复 | [cg] |
| `getIntegerValueField`：mouseEventButtonNumber、mouseEventDeltaX/Y、keyboardEventKeycode；`getDoubleValueField`：scrollWheelEventDeltaAxis1/2；`timestamp` | MouseInput.swift | 输入数据、Esc 中止、诊断 | CoreGraphics | 是 | 是 | 否 | 是；scroll 仅观察模式 | A；不使用键盘文本 API | [cg]、SDK CGEventTypes.h |
| `CGEventCreate`、`CGEventSetType`、`CGEventSetTimestamp`、`CGEventSetIntegerValueField(kCGEventSourceUserData)`、`CGEventPost(kCGSessionEventTap)` | Bridge | 公开事件外壳/标记/投递 | CoreGraphics | 函数是 | 是 | 否 | 是 | A 函数；type 30/HID 用法仍 C；可发送公开键鼠事件但无连续 Dock 等价 | [cg] |
| `AXIsProcessTrusted` | main.swift、GestureEngine.swift | 辅助功能预检查、撤销检测 | ApplicationServices/HIServices | 是 | AXUIElement.h | 否 | 当前实现是 | A；未来保留，不自动 reset TCC | [AXUIElement][ax] |
| `CGPreflightListenEventAccess` | main.swift、GestureEngine.swift | 可选输入监控检查 | CoreGraphics | 是 | CGEvent.h | 否 | 核心否 | A；可不启用 HID 观察路径 | [preflight] |
| `IOHIDManagerCreate/SetDeviceMatching/Open/Close` | HIDInputBackend.swift | 匹配普通鼠标、非 seize 观察 | IOKit | 是 | hid/IOHIDManager.h | 否 | 否，可选 | A；核心已使用 CGEventTap | [IOHIDManager][manager] |
| `IOHIDManagerRegisterDeviceMatchingCallback/RegisterDeviceRemovalCallback/RegisterInputValueCallback` | HIDInputBackend.swift | 设备添加、移除、HID 值 | IOKit | 是 | 同上 | 否 | 否；影响拔出即时取消 | A；未来取消观察需评估断连保护 | [manager] |
| `IOHIDManagerSetDispatchQueue/SetCancelHandler/Activate/Cancel` | HIDInputBackend.swift | 异步队列和生命周期 | IOKit | 是，SDK header 内有说明 | 同上 | 否 | 否 | A；无需私有 IOHIDEvent 注入能力 | SDK IOHIDManager.h:231–350 |
| `IOHIDDeviceGetProperty`、VendorID/ProductID keys | HIDInputBackend.swift | 设备型号类标识 | IOKit | 是 | IOHIDDevice.h / IOHIDKeys.h | 否 | 否 | A；不读 SerialNumber | SDK hid headers |
| `IOHIDValueGetElement/GetIntegerValue`、`IOHIDElementGetUsagePage/GetUsage` | HIDInputBackend.swift | 鼠标轴、按钮 usage 观察 | IOKit | 是 | IOHIDValue.h / IOHIDElement.h | 否 | 否 | A；不是 IOHIDEvent 私有字段接口 | SDK hid headers |
| kHIDPage_GenericDesktop/Button、kHIDUsage_GD_Mouse/X/Y、kIOHIDOptionsTypeNone、kIOReturnSuccess、DeviceUsagePage/DeviceUsage keys | HIDInputBackend.swift | HID 匹配与结果解释 | IOKit | 是 | IOHIDUsageTables.h / IOHIDKeys.h / IOReturn.h | 否 | 否 | A；不能与私有 DockSwipe 常量混淆 | SDK hid headers |
| CFMachPortCreateRunLoopSource/Invalidate/IsValid；CFRunLoopGetCurrent/AddSource/Run/RemoveSource/PerformBlock/Stop/WakeUp；commonModes | MouseInput.swift | tap 的 run loop | CoreFoundation | 是 | CFMachPort.h / CFRunLoop.h | 否 | 是 | A；无产品级替代需求 | [CoreFoundation][cf] |
| CFRelease、CFGetTypeID、CFBooleanGetTypeID、kCFAllocatorDefault | Bridge、AppConfig.swift、HIDInputBackend.swift | 所有权与配置类型检查 | CoreFoundation | 是 | CFBase.h / CFNumber.h | 否 | 是 | A | [cf] |
| `dlopen/dlsym`、RTLD_NOW/LOCAL | Bridge:41–47 | loader | libSystem | 是 | dlfcn.h | 本身就是动态加载 | 当前是 | A 函数；加载目标 C | SDK dlfcn.h / `man dlopen` |
| `NSClassFromString`、`class_getInstanceMethod`、`sel_registerName` | Bridge:44、56 | 类及 selector 存在检查 | Foundation / ObjC runtime | 是 | NSObjCRuntime.h / objc/runtime.h | 是 | 当前是 | A 函数；查找对象 C | [Objective-C runtime][objc] |
| NSObject alloc、NSException.name/UTF8String、@autoreleasepool/@try | Bridge | 对象分配、异常捕获 | Foundation/ObjC | 是 | 是 | 常规消息 | 是 | A；不能捕获所有 ABI 崩溃 | [Foundation][foundation] |
| mach_absolute_time、clock_gettime_nsec_np(CLOCK_UPTIME_RAW) | Bridge | 两种时间戳单位 | Darwin | 是（SDK/man） | mach/mach_time.h / time.h | 否 | 是 | A；不改变已验收时钟算法 | SDK / `man clock_gettime` |
| DispatchQueue、DispatchSource timer/userDataAdd/signal、dispatch_once、NSLock、Thread、DispatchSemaphore | GestureEngine/MouseInput/HIDInputBackend/main/Diagnostics/Bridge | 合并、线程与生命周期 | Dispatch/Foundation | 是 | 公开 C/Swift 接口 | 否 | 是 | A | [Dispatch][dispatch]、[foundation] |
| `getrusage(RUSAGE_SELF)`、`task_info(mach_task_self_, MACH_TASK_BASIC_INFO)` | PerformanceSampler.swift | 本进程 CPU/RSS | Darwin/Mach | 是（SDK/man） | sys/resource.h、mach/task_info.h | 否 | 否 | A；不读别的进程 | SDK / `man getrusage` |
| ProcessInfo operatingSystemVersion/String、systemUptime | main/SettingsView/Diagnostics | 系统版本、单调时间 | Foundation | 是 | 公开接口 | 否 | 时间核心是；报告否 | A；架构字符串当前硬编码 | [foundation] |
| UserDefaults dictionary/set、Bundle info/bundleURL、URL、String.write | AppConfig/main/SettingsView | 配置、版本、诊断保存 | Foundation | 是 | 公开接口 | 否 | 产品持久化是 | A；绝对路径导出需脱敏 | [UserDefaults][defaults] |
| NSApplication delegate/run/terminate/activationPolicy/activate；NSMenu/NSMenuItem；NSStatusBar/NSStatusItem；NSWindow；NSHostingView | main.swift | 菜单栏、设置窗口 | AppKit/SwiftUI | 是 | 公开接口 | 否 | UI 生命周期是 | A；自己的 @objc 菜单 selector 不是私有 selector | [AppKit][appkit] |
| NSImage(systemSymbolName:)/isTemplate、SwiftUI Form/TabView/Toggle/Slider/Label/Binding、ObservableObject/@Published | main/SettingsView/AppViewModel | 图标与 UI | AppKit/SwiftUI | 是 | 公开接口 | 否 | 否（产品 UI） | A | [appkit]、[SwiftUI][swiftui] |
| NSWorkspace.shared.notificationCenter 与睡眠/唤醒/会话/屏幕通知、NSApplication.didChangeScreenParametersNotification | main.swift | 取消/恢复输入 | AppKit | 是 | NSWorkspace.h / NSApplication.h | 否 | 安全生命周期是 | A | [NSWorkspace][workspace] |
| NSWorkspace.open(URL) | main.swift | 打开系统设置 | AppKit | 是 | 是 | 否 | 否 | A；下面 URL 协议另算 | [workspace] |
| `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility/Privacy_ListenEvent` | main.swift:248–250 | 跳到权限页 | System Settings URL | 未找到稳定公开合同 | 非 SDK symbol | 字符串 URL | 否 | D；未来提供手工路径兜底 | 源码；本轮未把网络惯例视为 Apple 保证 |
| NSPasteboard clearContents/setString、NSSavePanel begin/allowedContentTypes、UTType.plainText | main.swift | 用户主动导出诊断 | AppKit/UniformTypeIdentifiers | 是 | 公开接口 | 否 | 否 | A；输出内容有隐私 blocker | [appkit] |
| SMAppService.mainApp/status/register/unregister/openSystemSettingsLoginItems | LoginItemController.swift | 登录启动 | ServiceManagement | 是 | SMAppService.h | 否 | 否 | A；身份迁移单独验证 | [SMAppService][sm] |
| Darwin open/flock/close/signal、SIGINT/SIGTERM；execvp/perror | main.swift；scripts/BuildGuard.c | 单实例锁、信号；构建互斥 | libSystem/POSIX | 是（SDK/man） | fcntl.h/sys/file.h/unistd.h/signal.h | 否 | 当前启动是 | A；锁放 app 父目录是分发问题 | SDK / `man flock` |
| codesign/security/openssl/PlistBuddy/xcrun/swiftc/clang/ditto/tar | scripts/ | 本地构建签名工具，不是应用注入 API | 开发工具 | Apple 工具官方手册；openssl 另有许可证 | 不适用 | 外部进程 | 构建是 | 非 A–D 运行时 symbol；没有打包这些程序 | [分发审计](distribution-audit.md) |

## 三条手势路径和不可替代点

`鼠标 → CGEventTap → InputMailbox → GestureMachine/VerticalGestureTracker → MGPost… → HIDEvent(DockSwipe) → SLEventSetIOHIDEvent → CGEventPost → Dock`。

- 左右：`createEvent` Motion=1，进度写入 Progress，结束/取消附 Velocity X。
- 上/下：`createVerticalEvent` Motion=2；正/负进度分别驱动调度中心/应用 Exposé，终结速度写 Y。动作选择由项目状态机固定。
- 私有类缺失、SkyLight attach/copy 缺失或 selector 不存在，会令 probe 不可用；当前启动拒绝注入。copy 只是自检依赖，attach/字段才是连续交互的直接协议依赖。
- 不能用 `IOHIDManager` 替换：它在本项目只接收硬件鼠标值，不提供 Dock progress 控制器。`CGEventPost` 成功返回不代表 Dock 接受，统计 `postFailures=0` 也不等于交互验收。

## 公开等价接口检索范围（2026-09-29）

| 检索范围 / 实际检索词 | 阅读结果 | 是否满足 continuous / interactive / reversible / progress-driven |
|---|---|---|
| Apple CoreGraphics CGEvent、CGEventType、tapCreate、post；`Spaces Mission Control gesture progress API` | 公开键鼠事件和事件流；没有 DockSwipe 公共构造及 attach 合同 | 未找到 |
| AppKit NSEvent、trackSwipeEvent、NSResponder swipe tracking；`trackSwipeEvent options dampenAmountThresholdMin` | 给应用自己的视图提供滚动手势进度和动画回调 | 不能据此控制系统 Dock 动画 |
| NSWorkspace、activeSpaceDidChangeNotification、NSWindow Spaces 相关行为；`Spaces NSWorkspace` | 工作区通知、窗口参与 Spaces 的行为；没有系统动画进度 setter | 未找到 |
| Accessibility AXUIElement.h、AXUIElementPerformAction/SetAttributeValue；`Mission Control progress` | 通用 accessibility action/attribute，不是文档化的 Dock 进度接口 | 未找到 |
| IOKit IOHIDManager.h、公开 SDK headers；Apple OSS IOHIDEventTypes/FieldDefs/HIDEvent | 硬件输入管理与内部事件定义是不同层；OSS 不能补足公开应用合同 | 未找到 |

参考：[NSEvent swipe tracking][swipe]、[Space notification][space]、[AX actions][actions]。没有通过未公开 AX action 名、私有 `CGS*`/`SLS*` 替代并重新命名为“公开架构”。未来可提交 Apple 技术支持/Feedback 请求确认，或设计应用自己的公开 UI；后者不是原生 Spaces/调度中心等价体验。

未来 documented fallback 可保留公开输入捕获、方向识别、设置、菜单栏和用户配置的离散系统快捷键发送；需要逐项验证快捷键映射、冲突和权限。会失去半程停住、反向收回、随 progress 跟手以及与手速匹配的 terminal 动画。**本轮没有实现 fallback。**

[cg]: https://developer.apple.com/documentation/coregraphics/cgevent
[tap]: https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)
[hid]: https://github.com/apple-oss-distributions/IOHIDFamily/blob/IOHIDFamily-1633.120.12/HID/HIDEvent.h
[types]: https://github.com/apple-oss-distributions/IOHIDFamily/blob/IOHIDFamily-1633.120.12/IOHIDFamily/IOHIDEventTypes.h
[fields]: https://github.com/apple-oss-distributions/IOHIDFamily/blob/IOHIDFamily-1633.120.12/IOHIDFamily/IOHIDEventFieldDefs.h
[manager]: https://developer.apple.com/documentation/iokit/iohidmanager_h
[preflight]: https://developer.apple.com/documentation/coregraphics/cgpreflightlisteneventaccess()
[ax]: https://developer.apple.com/documentation/applicationservices/axuielement_h
[actions]: https://developer.apple.com/documentation/applicationservices/1462091-axuielementperformaction
[cf]: https://developer.apple.com/documentation/corefoundation
[objc]: https://developer.apple.com/documentation/objectivec
[foundation]: https://developer.apple.com/documentation/foundation
[dispatch]: https://developer.apple.com/documentation/dispatch
[defaults]: https://developer.apple.com/documentation/foundation/userdefaults
[appkit]: https://developer.apple.com/documentation/appkit
[swiftui]: https://developer.apple.com/documentation/swiftui
[workspace]: https://developer.apple.com/documentation/appkit/nsworkspace
[sm]: https://developer.apple.com/documentation/servicemanagement/smappservice
[swipe]: https://developer.apple.com/documentation/appkit/nsevent/trackswipeevent(options:dampenamountthresholdmin:max:usinghandler:)
[space]: https://developer.apple.com/documentation/appkit/nsworkspace/activespacedidchangenotification
