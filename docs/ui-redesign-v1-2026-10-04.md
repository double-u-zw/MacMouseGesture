# UI Redesign v1 / Legacy Settings Cleanup — Build 29

本轮只整理现有设置 UI，未新增 Trigger、Action、Profile、映射导入导出或云同步。开发完成后停在 Build 29 设置页，等待用户检查，不进入下一开发阶段。

## 1–4. Legacy UI 审计、删除、移动与合并

实施前的完整控件清单见 [Legacy UI Inventory](ui-redesign-v1-legacy-inventory-2026-10-04.md)，已逐项标记 KEEP / MOVE / MERGE / REMOVE FROM UI。

旧界面在同一个“设置”页中混合应用设置、按钮映射、独立的“现有拖动手势”、固定侧键 4/5 Toggle、横向/纵向总开关和“调整手感”。拖动同时出现在 Mapping 行和独立配置 section 中，是重复入口。旧侧键专属短按动作 section 在 Build 28 中已不存在，本轮未虚构这一删除项。

删除独立“现有拖动手势”、物理侧键整体开关、横纵动作总开关和拖动只读“查看”入口。服务开关、登录启动、状态/权限和向导移动到通用页；方向反转、灵敏度、触发距离、指针冻结和参数重置移动到手势页。拖动启停、按钮选择、触发方向与删除合并到 Mapping 行及统一 Sheet。

## 5–7. 新导航、映射结构与四方向表示

沿用原 SwiftUI TabView / 系统 toolbar 和 NSWindow，主入口是“鼠标映射 / 手势 / 通用”，帮助与关于保留辅助入口。打开设置及完成向导默认进入鼠标映射。

映射页顶部显示标题、简短说明和“＋ 添加映射”。MappingPresentation 从 MouseMappingStore 动态生成物理 Input 分组，以一基按钮编号排序：中键、侧键 4、侧键 5、其他额外按钮。修饰键显示在 Trigger 行内，不再生成独立按钮分组；行显示 Trigger、Action 和独立 Enabled。键盘动作显示快捷键符号。行点击进入统一 MappingEditorView，context menu 和编辑器提供删除。

短按、长按、上/下滚轮和左/右/上/下拖动全部出现在同一列表及同一编辑器。编辑器沿用已验收的鼠标/快捷键录制器，支持重新录入 Input、选择 Trigger、逐条启停及保存。重复 Input + Modifiers + Trigger 会显示“检测到已有映射”，提供“编辑现有”；不覆盖或创建第二条有效映射。

拖动当前的 Action 由原方向语义决定：水平左右对应前后桌面（跟随全局反转），向上为调度中心，向下为应用 Exposé。编辑器明确显示方向动作，并指向手势页的全局反转；不提供运行时无法执行的任意 Action 替换。修饰键拖动仍不支持，录入此组合会显示说明并禁用保存。

没有实际 Mapping 时显示“还没有鼠标映射”及添加入口。兼容数据中的旧空短按占位行不显示；用户明确保存的“无操作”映射有独立身份，继续显示、启停和编辑。

## 8–10. 原 Drag 链、单一数据源与兼容字段

UI 的行、启停和编辑均以 config.mappingStore 为来源，没有 Button4Section / Button5Section 或按钮专属 View。LegacyDragSettingsAdapter 在旧配置状态下读取原按钮/轴/反转投影，第一次实际编辑拖动映射时才采用完整 MappingStore 快照，并设置 dragMappingsManaged；启动不进行批量迁移或重写旧偏好。

采用映射管理后，adapter 从启用的拖动行推导 gestureButtons、horizontalEnabled、verticalEnabled 给原引擎；删除方向不会在重启后自动复活，关闭短按不影响长按、滚轮或拖动。所有拖动都关闭时轴旗标为 false，保留合法的兼容按钮集合供既有配置边界使用，不再启动拖动。

GestureMachine → VerticalGestureTracker / horizontal frames → Native Bridge 的执行链仍保留。外围 LegacyDragDelivery 只在原机器发出 began 后判断此物理按钮/起始方向是否启用，允许的序列原样传递，禁用序列整体不投递，终止事件与开始事件保持配对。反向运动仍属于原序列；不改变识别阈值、速度、进度、deadZone、冻结指针机制或连续 Space 逻辑。旧配置未采用逐行管理时 filter 完全透传。

保留的 legacy 字段为 gestureButtons、horizontalEnabled、verticalEnabled、button4ClickAction/button5ClickAction 的兼容访问器与序列化别名；它们用于旧配置加载、旧开发版兼容和原运行时 adapter。全局 horizontalInvert/sensitivity/deadZone/freezePointer 继续是现有手势参数。dragMappingsManaged 是配置来源标记，不是用户设置，不引入新的 Mapping 文档版本；Wheel 文档仍为 v4。

Build 28 不认识逐方向管理标记，回退旧版时只能使用兼容轴/按钮投影，不能保留 Build 29 的逐方向粒度。项目保存了实施前完整偏好快照，Build 28/27/17 应用本体不改动。

## 11. Dead UI code

删除 AppViewModel.buttonBinding、仅被该旧 UI 使用的 GestureSettings.changingButton、MappingSettingsSection 旧 section 包装及其按 RecordedMouseInput 分组 helper、旧拖动只读编辑分支、“查看”按钮和导向旧 section 的说明。现有 GestureMap 仍被帮助/Onboarding 引用，保留。KeyboardShortcut.display 仅移动到 MappingPresentation.swift，录制捕获逻辑不变。

恢复默认手势参数只恢复方向、灵敏度、触发距离和指针冻结，不修改 Mapping 的启停、删除、按钮集合或轴来源。

## 12–14. 验证

新增 **54** 项 UI / ViewModel / adapter 回归，最终 **528/528 PASS**（513 core/application checks + 15 Bridge contract checks），0 failure、0 skip。原 474 项测试集合保留，涉及已移除界面语义的预期调整见下。

新增覆盖物理分组/排序、全部 Trigger 标签及修饰键、快捷键、空状态与显式无操作、独立启停、添加/编辑/删除、重复冲突、保留帮助/关于及默认导航、旧控件不暴露、统一按钮业务、adapter 懒采用、运行时轴/按钮读写、持久化、方向反转、参数重置、退休 Wheel/Long owner、释放前末帧、取消/反向/双按钮生命周期，以及原 GestureCore 产生的四方向真实帧序列原样投递与收尾配对。

原生 UI 已检查鼠标映射动态分组、添加 Sheet（未录制输入前禁止添加）、拖动统一 Sheet（Input / Trigger / 固定 Action / Enabled / 删除）、手势页全局参数、通用页应用设置，以及关于页显示 Build 29。所有 agent 编辑检查均取消，未提交映射修改；第一次检查后的配置与实施前快照完全一致。后续用户自行检查时的状态不回滚。UI 检查不代替新 adapter 逐方向启停的真机验收；本轮按要求停在设置 UI 检查，不启动动作验收。

原测试集合保留数量；三个与已移除 UI 语义有关的测试更新为：单行拖动启停互不影响、设置绑定经现有 ConfigStore 保存、拒绝无法执行的拖动 Action；原参数重置测试的预期随“只恢复全局参数”调整。手势、Bridge、输入录制、长按、滚轮及动作执行器回归不改写或删减。

受保护文件哈希核对记录保存在 build/ui-redesign-v1/build29/protected-files-check.json；涵盖 GestureMachine、VerticalGestureTracker、Native Bridge、录制器底层、press/轮滚链及已安装/旧开发版关键文件。

## 15–16. 开发包与用户检查

独立包：`build/ui-redesign-v1/build29/MacMouseGesture UI Redesign Dev.app`，版本 `0.2.0-beta.1-ui-redesign-dev (29)`。

构建入口：`zsh scripts/build-ui-dev.sh`。新输出目录不覆盖 Build 28、Build 27、稳定 Build 17、Resources/Info.plist 或 /Applications/MacMouseGesture.app。没有创建 tag、发布 Release 或部署。

首先检查“鼠标映射”页：物理按钮分组、修饰键行、四方向行与滚轮行是否清楚；点击任意行检查统一 Sheet。然后检查“手势”只有全局参数、“通用”只有应用行为与状态。这里只检查新界面，不开启新一轮真机动作验收。
