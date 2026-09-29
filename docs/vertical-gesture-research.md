# 纵向连续手势：Phase 1/2 研究与 POC 边界

更新：2026-09-29。Build 7 横向 Spaces 是可回退基线；`baselines/build7/` 校验和全部通过。Build 9 已现场证明“侧键 + 上拖 → 连续调度中心”，Build 10 已现场证明“侧键 + 下拖 → 连续应用 Exposé”，Build 11 普通模式四方向真人回归通过，Build 12 定版为 0.1.6。事件构造成功始终不能替代 Dock 动画实测。

## 已核对的协议线索

现有横向桥接构造 `HIDEvent(DockSwipe=23)`，附加到 type 30 的 CGEvent，再经 session tap 投递；本机 Build 7 的四阶段负载回读与真实横向 Spaces 均已通过。`references/mac-mouse-fix/Helper/Core/Touch/TouchSimulator.m` 的 macOS 27 分支对横纵使用同一 DockSwipe 类型、同一 `DockPrimary=3` flavor、同一 began/changed/ended/cancelled options 编码和累计 progress。它用 motion `HorizontalX=1` 表示 Spaces，`VerticalY=2` 表示 Mission Control / App Exposé。motion、flavor、progress 分别在 DockSwipe 字段基值 `(23 << 16)` 上加 `1`、`5`、`2`；结束时附加 Velocity 子事件。类型与字段编号同仓库的 `Shared/IOKit/External/IOHIDEventTypes.h`、`IOHIDEventFieldDefs.h` 相符。

纵向不是把横向 `dx` 简单替换为 `dy` 就能证明成功：需要 motion=2、Y 轴结束速度、经相同四阶段附加事件路径，且由 Dock 实际呈现连续动画。参考实现把 CG 原始 `deltaY` 按屏幕高度缩放；该比例不是本项目已标定的值。本 POC 独立使用 `verticalPixelsPerProgress`，不改横向 600。Build 8 初始假设“上拖产生正 `deltaY`”被现场诊断证伪：用户实际连续上拖时，侧键和移动事件均被收到，CG `dy` 为负（例如 -424、-323），却被记为 `unsupportedDown`，纵向投递 0 次。Build 9 将向上符号修正为负，用户随后验证了正 progress 对应调度中心的连续展开、停顿、回退、松手和快速上甩。Build 10 下拖使用负 progress，实际开合程度与手感继续在本机确认。

Mac Mouse Fix 的公开实现和 [3.1.0 发布说明](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.1.0)支持 macOS 27 上纵向 DockSwipe 这一路径，但不构成本应用的实测。另一份 [dockswipe 项目说明](https://github.com/oomol-lab/dockswipe)也明确标注其 macOS 27 纵向映射仍依赖源码推断、未独立复现。因此本阶段以真人看到“拖动、停住、回退、松开”的 Dock 响应为唯一 PASS 依据。

## POC 设计

- Build 9/10 通过显式 `--vertical-poc` 隔离验证上拖调度中心和下拖应用 Exposé。Build 11 普通启动根据持久化“启用纵向手势”开关运行四方向，开发参数仍可用于诊断。
- 复用现有 CGEventTap、双侧键仲裁、死区/锁轴、120 Hz coalescing、冻结指针、权限和异常取消路径。既有 `GestureMachine.swift` 与横向 HID payload 保持原样。Build 9 向下首次锁轴只记录“未在 Phase 1 支持”；Build 10 开始选中应用 Exposé，反向拖动不会在同一次手势里变成调度中心。
- 纵向独立累积 progress 和速度，单次动作在锁轴后固定。Build 9 上拖的正进度和 Build 10 下拖的负进度都通过 Dock 动画实测；四阶段 HID 正负进度的附加负载回读也通过。无快捷键 fallback。
- Phase 1 用户确认调度中心连续展开、半程停住、继续跟手、反拖关闭、小幅回弹和快速上甩；Phase 2 用户在两个访达窗口前台确认应用 Exposé 的相同行为。两阶段都核对两颗侧键横向左右正常，始末计数平衡、无 open/投递失败/序列错误。Build 11 普通模式再确认两颗实体侧键四方向正常；快照为 `started=244`、`ended+cancelled=244`、`open=0`、两键 DOWN 29/216、投递失败和序列错误为零。
- 外接 4K/120 Hz 屏幕上的 macOS 全屏窗口中，下拖应用 Exposé 后偶尔有不到半秒的收尾延迟。原生触控板同场景也偶尔出现拖延；用户认为不影响使用。证据不足以把延迟归因于注入路径，故不改已经现场通过的 release 进度与速度参数。

参考文件只读，不参与构建；本项目没有复制 Mac Mouse Fix 的实现。其许可见 `THIRD_PARTY_NOTICES.md`。
