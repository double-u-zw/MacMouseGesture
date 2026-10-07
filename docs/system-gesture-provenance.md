# 系统手势桥接：契约与来源

当前实现位于 `Sources/SystemGestureBridge/SystemGestureBridge.m`。2026-09-30 的 Build15 替换移除了 Build14 及以前的两个旧构造器，改为按项目规格和行为契约实现的 `SystemGestureEventBuilder`。公开历史中的替换提交为 [37b3e5eea99c13243e0cbf1000ee8a3f263c862b](https://github.com/double-u-zw/MacMouseGesture/commit/37b3e5eea99c13243e0cbf1000ee8a3f263c862b)。本次整理保留该实现与协议，不为收敛项目改动手感或注入路径。

## 当前与历史来源

| 来源 | 固定版本与范围 |
|---|---|
| Mac Mouse Fix，Noah Nuebling | 早期研究快照 `a7ac3ecc86acf4ddb309ce1007472439a2f9d42a`；阅读过 TouchSimulator、FixDockSwipes、CGEventHIDEventBridge、ModifiedDragOutputThreeFingerSwipe。自定义 [MMF License](https://github.com/noah-nuebling/mac-mouse-fix/blob/0c0fc99e65b3b09e083cbedc71c4d83fe21d1075/License)，不是 MIT/Apache/GPL。 |
| Apple IOHIDFamily | [IOHIDFamily-1633.120.12](https://github.com/apple-oss-distributions/IOHIDFamily/tree/IOHIDFamily-1633.120.12) 的 IOHIDEventTypes.h、IOHIDEventFieldDefs.h、HIDEvent.h，为必要 ABI 声明/类型/字段编号的来源；未将完整头文件或 Apple 实现打包。 |
| MIT 比较项目 | [timmyagentic/mac-mouse-fix-macos-27-fix@9cf987ef070707fd8651475f78223403fca34ce6](https://github.com/timmyagentic/mac-mouse-fix-macos-27-fix/tree/9cf987ef070707fd8651475f78223403fca34ce6) 仅用于来源比较，没有采用其 main.m 作为替换模板或构建输入；不能借其 MIT 标签给旧派生实现重新授权。 |

旧 Bridge 两个 DockSwipe 构造流程保守登记为工程结构派生：研究记录、payload 组装组织及 terminal Velocity 子事件存在组合来源证据。输入合并/120Hz 节流和连续体验也有 MMF 概念启发；没有发现整文件复制、低层固定 CG 内存偏移、GPL 拟合库、MMF 付费系统或资源进入产品。

Build15 先记录本项目四个 C API 的规格与旧实现黑盒行为，再实现无状态请求描述、完整对象集分配、统一字段写入和最终封装。替换期间未重新阅读 MMF、MIT 比较源码或旧构造器作为编码模板。当前源码工程审计未发现剩余 MMF 代码级派生；这不是法律保证，也不是作者从未接触 MMF 或法律 clean-room 的声明。历史源码/二进制的归因不能因替换而删除。

项目自有代码采用根 [MIT License](../LICENSE)；历史 MMF 说明、Apple 声明来源及图标来源保留在 [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)。Apple 相关头文件的 APSL 通知与最小接口事实的覆盖范围不能笼统当成已经完成的权利结论。

## 必需的非公开接口

连续 Spaces、调度中心和应用 Exposé使用 private HID.framework 的 HIDEvent、SkyLight 的 `SLEventSetIOHIDEvent` 和 `SLEventCopyIOHIDEvent`，以及未文档化 DockSwipe 协议。`dlopen/dlsym`、公开 CGEvent 外壳和投递函数不改变其非公开性质。

研究对公开 CoreGraphics、AppKit/NSEvent/NSWorkspace、Accessibility、IOKit 与目标 SDK 的检索未找到可连续、可逆、按 progress 控制这些原生系统动画的文档化等价接口。这是限定范围的研究结果，不是证明所有可能接口不存在。一次性键盘动作不能保留半程停住/反向收回体验。

系统更新可能删除符号或改变协议语义；签名、公证和 probe 不是 Apple 私有接口授权或未来兼容保证。窗口全屏另用目标明确暴露的运行时 `AXFullScreen` 属性（本机 SDK 未提供公开常量）及公开全屏按钮/AXPress；权限页 `x-apple.systempreferences:` 深链接也没有已确认的稳定合同，应保留手工路径。

## C ABI 与行为契约

`MGBackendProbe(char *, unsigned long)`、`MGVerticalProbe(char *, unsigned long)`、`MGPostHorizontal(double progress, double velocity, uint32_t phase)`、`MGPostVertical(double progress, double velocity, uint32_t phase)` 均返回 bool。

调用入口决定轴；参数为绝对有符号 progress、progress/秒 velocity 及 phase（1 began、2 changed、4 ended、8 cancelled）。NaN、Infinity 和其他 phase 拒绝且不 post。Bridge 不接收 delta/按钮/阈值，不缩放、反转或裁剪调用者数值；Swift 状态机负责 deadZone、轴锁定、动作选择、速度失效和恰好一次结束。

| 原生负载 | 契约 |
|---|---|
| 根对象 | DockSwipe type23；options 为 phase 左移 24 位。 |
| Motion | 字段 `(23<<16)|1`，横向 1、纵向 2。 |
| Progress/Flavor | 字段 `(23<<16)|2` 为原有符号 double； `(23<<16)|5` 为 DockPrimary=3。 |
| Terminal velocity | 仅 end/cancel 附一个 type9 子事件；字段 `(9<<16)|{0,1,2}` 为横向(v,0,0)或纵向(0,v,0)。取消速度由调用者决定。 |
| CG 外壳 | type30，session event tap，source-user-data 标记 `0x4D47504F43`。 |
| 时间 | 每个 HID 对象使用当前 mach time；CG timestamp 使用单调 uptime 纳秒，不继承外部旧时间戳。 |

横向 progress 可反号；已记录纵向正 progress 为调度中心、负 progress 为应用 Exposé。原始上拖 CG dy 为负，符号转换属于 Swift 层。纵向动作锁定后反向只收回同一动作，不切换另一个动作。

每次调用独立描述和分配完整对象集，字段全部应用/附加后才允许一次 post；无部分负载进入投递边界。成功/失败/异常均平衡 CF 所有权，Objective-C 对象由 ARC 管理。无后台 timer、自治 begin/end 或跨请求继承字段。缺类/符号/selector、分配失败或异常失败关闭。

Probe 仅构造、附加、回读和释放，**永不 post**。当前启动回读覆盖正负 progress、phase 及根字段；原生契约测试还检查 Velocity 子事件、单次投递、异常参数、分配失败与释放。Build15 记录旧接口 12/12、新契约 15/15 通过，投递由测试边界拦截。当前测试入口为 `scripts/test.sh`，历史数量不代替最新运行结果。

返回 true 只表示构造与 CGEventPost 调用完成，系统没有 Dock 交付确认。真正连续动画仍须物理鼠标验收，见[兼容性矩阵](compatibility-matrix.md)。

## 维护约束

保持四个 C 入口、phase/符号/时间/速度语义、失效保护和非投递 probe。不要以符号重命名、删除归因、加入快捷键 fallback 或修改核心阈值冒充兼容修复。协议与来源变更应记录固定来源、实际测试系统以及自动/真机各自范围；不得用相似度零匹配证明原创或法律许可。
