# Phase 0 — macOS 27 continuous Dock Swipe research

调查日期：2026-09-28。目标：个人使用的原生鼠标手势工具。当前只交付输入实验与横向 Spaces POC，不把符号探测、编译、合成输入测试当作真人验收。

> 本文件保留 Phase 0 时的研究与初始 POC 行为快照。后续 Build 4 已支持双侧键、反转默认值、授权后自动开启和持续运行；最新用户验收、权限状态及后续计划以 [项目总结](project-status.md) 和 [验证记录](validation.md) 为准。下文初始“120 秒停止”“关闭窗口退出”等描述不代表当前版本。

## 本机事实

实测 `sw_vers`：macOS **27.0 / 26A428**；`uname -m`：**arm64**。Apple Swift 6.4，macOS 27 SDK，安装的是 Command Line Tools。

本项目的原生 `.app` 已构建、ad-hoc 签名并实际启动。运行时 `--probe` 确认所需符号存在；四种 phase 的 HID 负载附加与回读通过。首次探测时 Accessibility / Input Monitoring 都是 false。没有自动授予权限，也没有自动注入 Spaces 手势。

## 上游版本与线索核对

只读参考仓库在 `references/mac-mouse-fix/`，不会参与构建。研究时 master 为 `a7ac3ecc86acf4ddb309ce1007472439a2f9d42a`。单独 fetch 并检查了 `3.1.0` tag；该版本已于 2026-09-15 发布，不能沿用旧帖子里“尚无官方发布”的说法。[3.1.0 release](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.1.0)

| 线索 | 已核对的内容 | 对本项目的意义 |
|---|---|---|
| [#1871](https://github.com/noah-nuebling/mac-mouse-fix/issues/1871) | macOS 27 beta 下 Spaces / Mission Control 失效，普通点击、拖动滚动仍工作 | 应区分输入捕获故障和手势注入故障 |
| [#1887](https://github.com/noah-nuebling/mac-mouse-fix/issues/1887) | 同类横向侧键拖动失效；后续讨论提到附加 HID 和节流 | 是定位线索，评论中的临时构建不作为已验证依赖 |
| [#2007](https://github.com/noah-nuebling/mac-mouse-fix/issues/2007) | 3.0.8 用户升级 27 后侧键手势失效 | 老发布的失败不代表 HID 路径不可用 |
| [#2048](https://github.com/noah-nuebling/mac-mouse-fix/issues/2048) | 3.1.0 / macOS 27 / G305，纵向动画卡顿，报告者称横向正常 | 横向成功以后仍须独立验证纵向 |
| [#2050](https://github.com/noah-nuebling/mac-mouse-fix/issues/2050) | Logitech 横向滚轮翻页与滚动边界需求 | 不是 Dock Swipe 修复证据 |
| [#2046](https://github.com/noah-nuebling/mac-mouse-fix/issues/2046) | G502 多个侧键都显示为 Button 4 的报告 | 保留 CG 原始编号，并提供 HID usage 对照，不能保证所有设备可区分 |
| [f92d2d53a](https://github.com/noah-nuebling/mac-mouse-fix/commit/f92d2d53a) | 新增 macOS 27 HID Dock Swipe 方案和实验文件；提交自己也指出卡住与重复 end 尚需验证 | 可以依据事件协议重写最小实现，不能宣称 upstream 解决全部稳定性问题 |
| [PR #2025](https://github.com/noah-nuebling/mac-mouse-fix/pull/2025) | 作者报告高频鼠标在约 8 ms 内发送多个 Dock Swipe，提出保留累计 progress 并合并 changed | 本 POC 单独实现有界累计器与约 120 Hz 输出，作者的性能数字不算本机数据 |

已逐文件查看 `Helper/Core/Touch/TouchSimulator.m`、`Tests/FixDockSwipes.m`、`Shared/IOKit/CGEventHIDEventBridge.*`、`ModifiedDragOutputThreeFingerSwipe.m`。`3.1.0` 与上述 master 的 TouchSimulator 差异仅为调试日志时间格式，不能假定 master 已合并高频节流补丁。

## 为什么旧路径失效；怎样注入

上游实验与报告一致指向：macOS 27 不再按旧方式解释某些合成 CGEvent 的隐藏 gesture 字段，Dock Swipe 改为依赖附带的 HID 负载。这是上游研究结论；本机尚未做旧路径/新路径的桌面动画 A/B 对照。

本 POC 的候选路径：`HIDEvent(DockSwipe) → SLEventSetIOHIDEvent(CGEvent type 30, HIDEvent) → CGEventPost(session)`。

使用 Apple 公布的 [IOHIDEventTypes](https://github.com/apple-oss-distributions/IOHIDFamily/blob/IOHIDFamily-1633.120.12/IOHIDFamily/IOHIDEventTypes.h) 与 [HIDEvent interface](https://github.com/apple-oss-distributions/IOHIDFamily/blob/IOHIDFamily-1633.120.12/HID/HIDEvent.h) 核对类型与签名，另外在本机加载真实类、检查方法存在。相关原始头文件已下载到 references，未编译进应用。

| 字段 | 最小横向实现 |
|---|---|
| HID 类型 | DockSwipe = 23 |
| gesture motion | HorizontalX = 1 |
| flavor | DockPrimary = 3 |
| progress | 从鼠标位移累计产生，使用 Double；停止移动时不再更新 |
| phase | began=1 / changed=2 / ended=4 / cancelled=8，编码到 options 高 8 位（shift 24） |
| 结束速度 | 结束负载附带 Velocity 类型子事件，X 为 progress/s，Y/Z 为 0；单位与实际效果仍需实测标定 |
| 时间戳 | HID 使用 mach_absolute_time，CG 使用单调时钟纳秒 |
| 外层事件 | CGEvent type 30，经 session event tap 投递 |

使用 `dlopen` / `dlsym`，不直接链接私有 framework；不读写 CGEvent 对象的固定内存偏移。桥接模块 `SystemGestureBridge` 独占所有私有类声明、常量与函数指针。启动时为四种 phase 构造事件、附加 HID、通过 `SLEventCopyIOHIDEvent` 回读检查，完成后释放，不 post。

**能构造/回读 ≠ Dock 接收 ≠ 连续动画成功。** CGEventPost 无交付确认。实际可用性必须看真人拖动结果。若 probe 失败则禁用注入、明确显示 unavailable；本阶段不启用快捷键 fallback，以保持交互式 POC 的验收结果明确。正式 fallback 与 LegacyGestureBackend 在核心验收后实现。

没有照搬上游延时重发 end。延时 terminal 可能影响下一次手势，当前先保证每个 sequence 只有一个终结；若本机出现卡住，再带 sequence 标识研究有界恢复机制。

## 输入方案和权限

| 方案 | 实现 / 权限 | 能否吞事件 | 证据边界 |
|---|---|---|---|
| CGEventTap listenOnly | 输入实验；Input Monitoring 或当前系统允许的监听权限，以 tap 创建结果为准 | 否 | 尚待物理侧键操作 |
| CGEventTap defaultTap | 手势实验；先检查 Accessibility，再创建 tap | 能返回 nil；只针对配置的侧键及可选冻结移动 | 本机尚未授权，不能宣称已吞掉浏览器 Back |
| IOHIDManager | 只读设备观察；通常需 Input Monitoring；记录 vendor/product 和 Button usage | 当前 non-seize 实现不阻止原输入 | 与 CG 的按钮/时延/频率对比待实测 |
| IOHIDEventSystemClient | 研究候选，未实现 | 不能凭接口名称推断有安全可用的 suppress 能力 | 额外私有权限和 ABI 成本暂不引入 |

CG button number 为零起算，常见 Button 4=3、Button 5=4；HID Button usage 通常从 1 开始，但不把二者强行一一对应。可手动指定 CG 2…31，故某个特殊侧键编号仍可测试。若两个实体键在 CG 层已坍缩为同一编号，本 POC 不声称能恢复区分，先收集 HID 对照。

“可靠/更低延迟”的选择还不能由文档决定。当前优先 CGEventTap 是因为它支持精确 suppress，并提供桌面事件语义。回调仅提取字段、短锁累计、通知边沿、返回。事件创建、状态机、日志在独立串行队列；HID 使用独立 dispatch queue。详见 Apple [CGEvent tapCreate](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)) 与本机 SDK `IOHIDManager.h`。

## POC 行为与安全边界

- 状态机：idle → buttonHeld → detectingAxis → horizontal / rejectedVertical → ending → idle。死区默认 8；锁轴后不改变方向。
- 选定侧键在横向实验期间专用，down/up 均消费；不实现 short click replay。左右主键和滚轮透传。
- 有界 256 段队列；相邻运动合并但保留按钮边界；溢出立即停止消费并取消。目标键按下才启动 120 Hz timer，空闲没有 gesture timer。没有每个原始事件一个异步闭包。
- 保留最后一帧以后的移动量，terminal 携带最终 progress。最近 100 ms 估计速度；停住超过 75 ms 不沿用旧 flick。距离、速度、反向运动决定 ended/cancelled。当前阈值为实验值，不能视作 Apple 原生曲线。
- progress 默认 `-dx/600`，支持反转和比例调整。这个值是系统协议 progress，**不是**已经标定的“一个 Space 的百分比”；多 Spaces、屏幕宽度和自然方向需要真人标定。
- Freeze 模式只尝试在 HID tap 吞掉移动，不调用全局指针解绑、不 warp、不隐藏指针。避免进程退出留下全局指针状态；是否能完全冻结及边缘是否仍有 delta 必须 A/B 实测。
- Escape / Stop / 关闭窗口 / SIGTERM / sleep / inactive session / display change / 事件钩子失效会取消。获准的 HID 观察器发现鼠标移除时也取消；没有 HID 权限时依靠松键及安全时间限制，设备断开即时检测不保证。
- 每次实验 120 秒自动停止，单次按住超过 20 秒取消；这是 POC 防护，不是最终交互限制。事件 tap timeout 后先停止，手动重启，不在输入回调重试。
- 两个进程用 build 下 flock 防止重复运行。没有登录项、helper 安装、配置持久化、第三方依赖或网络请求。
- 日志仅内存 300 行；运动日志合并，gesture changed 最多约 10 行/s。不存按键内容、窗口标题、前台 App 或鼠标屏幕坐标。

## 尚未解决 / 下一步入口

必须先确认物理 Button 4/5 和左右连续桌面跟随，再继续 Phase 3。仍未验证：手势取消的 Dock 行为、真实 flick、1000 Hz 外设、100 次真实切换、CPU/内存稳态、断连/睡眠/锁屏/权限变化、多屏、全屏应用。纵向、正式菜单栏、完整 PermissionManager / 设置与 fallback 都尚未进入交付范围。

上游使用自定义 MMF License，不是 MIT。参见 `THIRD_PARTY_NOTICES.md`；当前为个人本地 POC。参考协议和研究保留来源，构建不复制上游授权/付费/UI/配置组件。公开发布前须重新核对衍生作品的许可要求。
