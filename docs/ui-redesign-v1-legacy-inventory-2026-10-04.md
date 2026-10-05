# Legacy UI Inventory — UI Redesign v1

审计时间：2026-10-04，实施前基线为 Build 28。Sources/SettingsView.swift、MappingSettingsView.swift、AppViewModel.swift、main.swift、OnboardingView.swift 与配置读写已审阅；完整源码与偏好快照保存在 build/ui-redesign-v1/build29。

| 当前 section / control | 分类 | 新位置或处理 |
|---|---|---|
| 设置 / 帮助 / 关于 toolbar tabs | MOVE | 原 TabView 保留，新增鼠标映射、手势、通用三个主入口；帮助/关于保留辅助入口 |
| 产品标题和介绍 | KEEP / MOVE | 通用页；映射页使用自己的标题及一句操作说明 |
| 启用 MacMouseGesture | MOVE | 通用页，仍为应用总开关 |
| 登录时启动及登录项批准提示 | MOVE | 通用页；不增加菜单栏图标开关等未实现选项 |
| 按钮映射列表，按 Button + Modifiers 分组 | MERGE | 主鼠标映射页；改为按物理 Input 分组，修饰键显示在行内 |
| 映射行启用/编辑/垃圾桶 | MERGE | 所有 trigger 的统一行开关、编辑 Sheet 和删除映射入口 |
| 添加映射、鼠标输入录制、快捷键录制 | KEEP | 映射页与统一 Sheet；录制器底层不改 |
| Mapping 行里的四方向拖动只读投影与“查看”按钮 | MERGE | 同一 Mapping Editor，支持行启停和删除；方向对应的现有动作由 adapter 表示 |
| “现有拖动手势”独立 section | REMOVE FROM UI | 与映射列表重复，删除整个独立入口 |
| 固定侧键 4 / 侧键 5 Toggle 与 buttonBinding | REMOVE FROM UI | 不再把某个按钮作为一个整体开关；各 Mapping 独立配置 |
| 左右拖动总开关 / 上下手势总开关 | MERGE | 映射行 Enabled；legacy axis flags 仅由 adapter 推导给原运行时 |
| 反转左右拖动方向 | MOVE | 手势页，“反转水平手势”；映射中的左右动作同时更新 |
| 调整手感 DisclosureGroup | MOVE | 手势页 |
| 横向灵敏度、触发距离、手势期间保持指针不动 | KEEP / MOVE | 现有参数移入手势页，不扩展参数范围或算法 |
| 恢复默认手势设置 | MOVE | 手势页，改为只恢复全局手感参数，不重新启用/覆盖 Mapping |
| 运行状态、辅助功能权限、错误重试、用户提示 | MOVE | 通用页；帮助页保留诊断及问题处理 |
| 设置向导 | KEEP / MOVE | 通用页；帮助页也可进入现有向导 |
| 帮助：使用手势示例、状态、权限、重新尝试 | KEEP | 帮助辅助页；引导用户在鼠标映射中选择按钮和操作，不作为第二个映射配置入口 |
| 更多权限、诊断复制/导出/详细报告 | KEEP | 现有帮助页；这是已有诊断功能，不新增映射导入导出 |
| 关于、版本、项目链接、许可与致谢 | KEEP | 原关于页 |
| 旧侧键 4 / 5 专属短按动作 section | 已不在当前 UI | Build 28 已合并到通用 Mapping，无此控件需要再删除；不虚构重复入口 |
| Onboarding 的手势说明与按钮识别 | KEEP | 不是配置源；完成/前往设置进入鼠标映射页，录制流程保留 |

实施约束：不修改 GestureMachine、VerticalGestureTracker、Native Bridge、deadZone 算法和连续 Space 逻辑。Drag 单行配置通过外围 adapter 传给既有链，禁止让 UI 保存实际不会执行的任意拖动 Action。旧字段保留供兼容加载及运行时 adapter 使用，不进行启动时的大规模迁移。空状态与动态按钮分组从 MouseMappingStore 值生成。
