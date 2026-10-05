# Mapping System v1 开发完成报告

日期：2026-10-04。开发包 Build 25，版本 0.2.0-beta.1-mapping-dev。自动化 274 PASS，真机用户验收 PENDING。这是配置架构与 UI 升级，没有把未验收动作改称已完成。

## 1. 架构

物理 CGEvent（零基按钮编号）→ 既有短按/拖动识别 → MouseInput（用户一基编号）+ MouseTrigger → MouseMappingStore 的不可变运行快照 → MouseAction → 既有 MouseButtonActionExecutor。

映射是全局设置；没有应用/设备 Profile、条件引擎、双击、长按、滚轮组合、宏、Shell 或 AppleScript。

## 2. 文件

新增：

- Sources/MouseGesturePOC/MouseMapping.swift：Input/Trigger/Action/Mapping 与 Codable。
- Sources/MouseGesturePOC/MouseMappingStore.swift：集中 CRUD、冲突处理、解析、持久化文档与旧拖动投影。
- Sources/MouseGesturePOC/StandaloneShortPressTracker.swift：仅短按按钮复用原状态机的观察器，不发送手势。
- Sources/MouseGesturePOC/MappingSettingsView.swift：分组列表、编辑 Sheet 与快捷键草稿。
- Tests/CoreRegression/MouseMappingTests.swift：51 项新增测试。
- docs/mapping-system-v1-2026-10-04.md：本报告与逐项验收记录。

本轮修改：AppConfig.swift、AppViewModel.swift、GestureEngine.swift、MouseInput.swift、MouseButtonActionExecutor.swift、SettingsView.swift、main.swift、Tests/CoreRegression/main.swift、scripts/test.sh、README.md。

此前短按修复已有的未提交文件保留，没有重置或删改既有工作。

## 3. MouseInput

采用 `.button(Int)`，v1 接受鼠标按钮 3...32，对应 CGEvent 2...31。用户按钮 3 是中键；4/5 是常见侧键。不为每个编号添加 enum case，不支持拦截主左/右键。存储带 kind/number，明确区分一基 UI 与零基事件。

## 4. MouseTrigger

`.shortPress` 与 `.drag(.left/.right/.up/.down)`；kind/direction 独立编码。未知触发方式不会降级为短按。没有实现其他触发方式。

## 5. MouseAction

`.none`、`.system(SystemAction)`、`.window(WindowAction)`、`.navigation(NavigationAction)`、`.media(MediaAction)`、`.keyboardShortcut(KeyboardShortcut)`。

保留旧动作的解码表达能力，包括旧 Launchpad、锁屏、媒体、返回/前进等；previousSpace/nextSpace 用于表示现有拖动。短按不会把这些桌面拖动动作交给 one-shot executor。

快捷键保存 keyCode 与 modifierFlags，解码经过原有效性校验，拒绝纯修饰键。未知 action kind/value 安全成为 none。

常规菜单只有无操作、显示桌面、自定义快捷键。完整快捷键真机验收仍待完成，界面注明基础实现。迁入的动作可以继续保留，列表与编辑器显示验收/兼容状态，不把它们伪装为常规已验证选项。

## 6. MouseMapping

Codable、Identifiable、Equatable；包含 id: UUID、input、trigger、action、isEnabled。旧数据转换和拖动投影使用稳定 UUID；新映射使用随机 UUID。没有提前引入未来 scope/condition 数据。

## 7. Mapping Store

集中管理 add、update、delete、setEnabled、mapping 查询与 action 解析。每个 Input+Trigger 仅保留一个条目（包括禁用条目），避免启用后产生重复。重复添加返回已有 UUID，编辑冲突不覆盖。

Store 编解码 version=1 的文档；ConfigStore 将该文档与旧手势配置在同一个 UserDefaults 值中提交。UI 主线程编辑、引擎串行队列持有值快照，不共享可变列表。

## 8. 旧配置迁移和保存

继续使用 UserDefaults 的 gesture.configuration.v1，新增内部字段 mouseMappingsV1，值为 JSON Data（version/mappings）。旧 button4ClickAction/button5ClickAction 自动转成短按映射，快捷键数值与其他手势参数保持原值；同一次写入保存新文档。新文档的存在代表迁移完成。

有效空文档是“用户已删除”，不会因空列表再次迁移而复活旧动作。多次启动保持 UUID、条目数和迁移文档不变。未知旧 action 降为 none。

旧按钮字段不再是独立状态，只保留兼容访问器与降级写出；禁用/删除映射对旧字段写 none。既有稳定版忽略新字段，不修改其 .app。

损坏/未来版本的新文档不会回退旧动作：短按解析失败关闭。原数据在只读 load 时保持；后续用户保存将写回 v1。这不是跨未来版本无损编辑的承诺。

本机完整迁移前备份：build/mapping-v1/build25/pre-mapping-settings.plist。

新安装沿用稳定产品：短按默认无操作；两个侧键的既有四方向、反转、600 灵敏度、8 deadZone 保持，未擅自把默认短按改成显示桌面。

## 9. 短按运行时

原拖动按钮继续通过原 SideButtonClickTracker 观察 GestureMachine。松开确认短按后，用 `.button(cgNumber+1), .shortPress` 查询 Store，最多执行一个动作。禁用或删除的短按没有动作，不影响同按钮拖动。

仅短按按钮由 StandaloneShortPressTracker 复用 GestureMachine + SideButtonClickTracker、同一 deadZone、同一 120 Hz 引擎计时器；不向 Bridge 发送帧。越过阈值后粘性抑制，返回起点仍不点击。加入已开始的现有手势时也抑制。取消、失焦、退出、tap 恢复清理状态；没有第二套阈值。

InputMailbox 分离“需要拦截的按钮”和“可驱动拖动的按钮”。短按按钮不会产生旧手势的 modifier 边界，不冻结指针；额外按住短按按钮不会延长原手势的结束。两个拖动轴都关闭后，仍可运行有效短按映射。

## 10. 拖动的迁移范围

Phase B：为现有拖动生成 mapping representation，反映当前按钮、轴开关、方向反转。基础 4/5 及旧配置里的额外按钮均可表达。运行时没有通过 Action Resolver 执行拖动。

GestureMachine / VerticalGestureTracker / Bridge 仍执行原连续手势。拖动映射是只读投影；按钮、轴与反转仍在“现有拖动手势”中调整。拒绝保存、禁用或删除任意拖动行，防止 UI 显示已修改而实际执行没变。Phase C 不在本轮实现。

## 11. UI 结构

“按钮映射”按鼠标按钮编号分组，每条显示触发方式、动作、状态。短按有启用开关、编辑、删除；拖动显示现有手势/未启用和查看按钮。下方保留“现有拖动手势”和原手感设置。

旧固定式 SideButtonActionView 已移除；全部简体中文。独立 Sheet 的按钮选择支持 3/4/5 和其他 6...32，本轮采用下拉与数字选择，不增加下一鼠标事件捕获器。

## 12. 添加、编辑、删除、禁用

“＋ 添加映射”→ 输入 → 触发方式 → 动作 → 保存。重复短按转入已有映射并显示提示，需要编辑后保存，不同时执行两条。

编辑器的快捷键录制写入草稿；取消录制/取消编辑不覆盖原配置。清除后草稿变成无操作，保存才生效。禁用保留原 action 与 UUID；删除不会在重启后复活。

拖动触发方式可以查看，但保存按钮禁用并说明本轮边界；已有拖动条目没有假编辑入口。

## 13—14. 测试

基线实际为 223 项（208 回归 + 15 Bridge），不是用户早期提示中的 126。原 223 项全部继续 PASS。

新增 51 项，覆盖四层 Codable、无效输入/未知类型、快捷键、CRUD/冲突/唯一解析、按钮/触发独立性、旧动作/快捷键迁移、默认值、幂等、新格式优先、损坏格式安全、禁用/删除重启恢复、独立进程持久化、原字段保留、反转/轴投影、仅短按运行、显示桌面原 executor 接线、混合按键边界、阈值后回原点、取消、重复边缘、加入现有手势、Escape/tap 隔离，以及原/显式拖动按钮集合的事件顺序一致。

结果：259 回归 + 15 Bridge = 274 PASS，0 FAIL，0 SKIP。测试输出：build/mapping-v1/build25/test-output.txt。原生投递被拦截，不声称自动化就是物理鼠标验收。

完整 SwiftUI/运行时应用编译成功；已有固定证书签名验证通过。只出现项目原有的 Swift legacy driver 废弃警告。

## 15. 受保护代码

哈希确认本轮未修改 GestureMachine.swift、VerticalGestureTracker.swift、全部 Native Bridge 文件、HIDInputBackend.swift、SideButtonClickTracker.swift、ShortcutRecorderView.swift，以及 Mission Control/App Exposé/最小化/全屏/返回的实现。

移除新增的 MouseAction 转接入口后，executor 文件哈希与本轮前一致；显示桌面、键盘/媒体和其他执行路径未重写。

GestureEngine 与 InputMailbox 有短按解析、独立监听和状态清理接线变更；不能说这两个文件完全未变。但既有连续帧生成、进度/速度、方向、阈值与 Bridge 算法未改。

## 16. 风险与真实验收状态

- 新 Build 25 的物理输入、短按/拖动冲突、四方向与手感回归仍需用户逐项验收。
- 泛用按钮模型支持 3...32，实际鼠标/应用是否提供对应 CGEvent 仍依硬件而定。
- 拖动投影暂不可任意替换，不声称已完成 Phase C。
- 返回保留 Chrome PASS、Finder FAIL；本轮没有修复 Finder，不能发布为全局可用。
- 显示桌面、Mission Control、App Exposé、最小化和全屏的既有专项 PASS 保留；其他未完成的动作继续未完成。
- 自定义快捷键已验证本机 UI 录制与数值保存，不代表 ⌘T/⌘W/⇧⌘4 执行链和修饰键释放的完整真机验收。
- 未来未知触发方式/损坏文档当前不执行，不承诺未来格式可由 v1 无损修改。

## 17. 独立开发构建

build/mapping-v1/build25/MacMouseGesture Mapping Dev.app；与稳定版相同 bundle ID 与固定证书，只运行一个实例。启动与重启均确认服务正在运行、辅助功能开启。

旧 Build 24 正常退出，所有旧开发包保留。/Applications/MacMouseGesture.app 的 Build 17 plist 和可执行文件 SHA256 与迁移前一致。未创建 tag、Release、push 或覆盖稳定包。

构建清单：build/mapping-v1/build25/build-manifest.json，包含源码哈希、冻结路径、测试结果与实际进程核验。源 Resources/Info.plist 没有改变 Build 17；仅独立包使用 Build 25。

## 18. 当前 UI 检查与第一轮用户验收

工具驱动 UI 检查已通过：分组列表/独立 Sheet 可读，常规菜单仅三类；重复添加打开旧映射，取消保留配置；临时按钮 6 录制 ⌘T，实际保存 keyCode=17、modifierFlags=1048576、isEnabled=false；正常退出后同一包重启恢复；临时条目删除；关闭按钮 4 的旧拖动只更新拖动投影，短按仍启用，随后恢复原拖动配置；拖动查看窗口明确只读。

这些是 UI/配置检查，不等价于真实鼠标动作 PASS。启动前本机实际旧配置为按钮 4 全屏/退出全屏、按钮 5 显示桌面，两项均保留；没有根据更早返回测试时的配置擅自覆盖。

临时条目删除后又正常退出/重启一次：确认列表只有 10 条迁移映射，按钮 6 没有复活，映射文档字节与退出前一致；所有旧字段与迁移前完整备份一致。最终内核路径来自 Build 25 独立包，界面已滚动到按钮 5 编辑入口，等待 UI 1 的用户反馈。

用户验收逐项进行，每次只给一个动作。首项：打开鼠标按钮 5 的短按编辑器，确认输入=鼠标按钮 5、触发=短按、动作=显示桌面，启用开关开启；用户回复后才进入下一项。

| 检查 | 当前结果 |
|---|---|
| 自动化 274 项 | PASS |
| 工具驱动 UI / 保存 / 正常重启检查 | PASS |
| UI 1：用户核对迁移后的按钮 5 编辑器 | PASS（2026-10-04 用户回复 A：按钮 5、短按、显示桌面、启用均一致） |
| 实机 2：按钮 5 短按经 Mapping Store 执行一次显示桌面 | PASS（2026-10-04 用户回复 A：正常显示桌面，仅一次） |
| 实机 3：禁用按钮 5 短按后正常点击不执行显示桌面 | PASS（2026-10-04 用户回复 A：没有触发任何动作） |
| 实机 4：短按禁用时，按钮 5 向左拖动仍正常切换桌面 | 未验证（2026-10-04 用户要求跳过这组测试） |
| UI 5：自定义快捷键录制 ⌘T | PASS（2026-10-04 用户回复 A；界面确认已记录 ⌘T） |
| 实机 6：按钮 5 短按执行 ⌘T，浏览器只新增一个标签页 | PASS（2026-10-04 用户回复 A：只新增一个标签页） |
| 实机 7：正常退出并重启同一开发版后，按钮 5 的 ⌘T 仍执行一次 | PASS（2026-10-04 用户回复 A：仍只新增一个标签页） |
| 实机 8：按钮 5 短按执行 ⌘W，只关闭一个测试空白标签页 | PASS（2026-10-04 用户回复 A：只关闭这个标签页） |
| UI 9：多修饰键 ⇧⌘4 真机录制 | FAIL（2026-10-04 用户回复 B：没有录到；原因待定位） |
| Build 25 真实鼠标短按与四方向回归 | PENDING |

总体：工程实现完成；真机验收 PARTIAL，尚不建议发布。

UI 1 已收到用户确认。下一项只测试按钮 5 正常短按一次是否显示桌面且不重复；不据此提前宣称拖动、其他按钮或快捷键回归完成。

第 2 项收到用户回复 A，按钮 5 的映射执行显示桌面 PASS。第 3 项暂时仅关闭按钮 5 短按行的启用开关，保留动作和原拖动开关；随后让用户正常短按一次，确认无动作。测试禁用状态需在后续检查结束后恢复，不能当成用户永久配置偏好。

第 3 项收到用户回复 A，禁用短按后无动作 PASS。下一项保持当前临时配置，只验证按钮 5 向左拖动及松开：原桌面切换正常，松开无额外显示桌面。通过后恢复按钮 5 的短按启用状态。

用户随后表示“不用测这些”，停止这组拖动验收，未测项目不记为 PASS。停止时重新检查实际界面：按钮 5 短按已恢复启用，动作仍为显示桌面；按钮 4 短按仍为全屏 / 退出全屏；两个按钮的拖动及两个拖动轴均保持启用，无需再次切换。自动化结果仍为 274 PASS，真机总体仍为 PARTIAL。未发布、未创建 tag、未覆盖稳定版。

用户表示“继续吧”，继续 UI / 配置验收，跳过前述拖动组。第 5 项已打开按钮 5 编辑器中的自定义快捷键录制窗口，只录制 ⌘T 草稿，尚未保存或覆盖原显示桌面配置；等待用户反馈。

第 5 项用户回复 A，⌘T 录制 PASS。随后通过录制窗口保存、映射编辑器保存，将按钮 5 短按暂时改为启用的 ⌘T；读取实际持久化文档确认 input=button(5)、trigger=shortPress、keyCode=17、modifierFlags=1048576。按钮 4 与拖动设置保持原值。第 6 项等待用户在浏览器中短按一次，确认新增一个标签页；临时快捷键验收结束后恢复按钮 5 显示桌面。

第 6 项用户回复 A，⌘T 执行一次 PASS。随后用开发版应用菜单正常退出，确认无 MacMouseGesture 进程后重新打开同一个 Build 25 包。界面仍显示按钮 5 启用 ⌘T、服务运行、辅助功能权限开启；第 7 项等待用户验证重启后的实际执行。

重启后的内核路径确认仍为 Build 25 独立包，PID 39653；映射文档 SHA256 与重启前完全一致。第 7 项用户回复 A，重启后 ⌘T 执行一次 PASS。随后通过录制器将按钮 5 临时改为启用的 ⌘W；录制界面及保存后的列表确认 ⌘W。第 8 项只让用户关闭刚才新增的空白测试标签页，不操作有编辑内容的页面。

第 8 项用户回复 A，⌘W 只关闭一个测试标签页 PASS。实际持久化值已核对为 keyCode=13、modifierFlags=1048576。第 9 项已打开录制窗口，等待用户按 ⇧⌘4；当前保存的临时映射仍为 ⌘W，尚未保存多修饰键草稿。

### 第 9 项失败定位（暂停后续验收）

- 复现条件：打开按钮 5 的快捷键录制窗口，显示“请按下快捷键”，原值 ⌘W；提示用户按 ⇧⌘4。
- 预期：显示“已记录快捷键”与 ⇧⌘4，尚未保存到映射。
- 实际：用户回复 B“没有录到”。随后工具检查时录制及编辑窗口已关闭，仅设置主窗口可见；不能据此确定按键时的焦点或关闭原因。
- 配置检查：已保存映射仍为 ⌘W，keyCode=13、modifierFlags=1048576，未被失败的录制覆盖。
- 初步怀疑：录制窗口焦点/生命周期，或系统截图快捷键先收到组合键；目前没有证据证明是哪一项。
- 日志：现有录制器没有事件接收/焦点/生命周期诊断日志，无法还原这次操作。先重新打开录制窗口做一次明确聚焦的复现；若仍失败，再评估增加仅限录制期间的技术诊断，不记录普通键盘输入、页面或窗口内容。
- 未修改代码，未继续后续验收。临时 ⌘W 配置仍需在验收结束后恢复为显示桌面。

### 第 9 项确认与范围收敛

用户再次回复 C，并明确补充“系统截图的十字光标”：确认 ⇧⌘4 执行了系统截图，未被录制器捕获。现有 NSEvent 应用内录制路径没有抑制系统快捷键。已查到 SDK 公开 PushSymbolicHotKeyMode / PopSymbolicHotKeyMode 接口作为可能修复方向，但尚未修改任何源码，也未构建新版本或证明该方向在当前系统可行。

用户随后表示“这些都不重要，大概率用不上”，因此停止这部分修复和相关验收。⇧⌘4 保留为已知录制限制，不能记为 PASS；⌘T、⌘W 及 ⌘T 重启持久化的已确认 PASS 保留。当前基础真机结果共 7 项 PASS，1 项用户跳过、1 项 FAIL 后暂缓；不宣称完整快捷键或拖动回归已通过。

界面已确认测试前配置恢复：按钮 4 短按全屏 / 退出全屏、按钮 5 短按显示桌面，两项启用；现有拖动设置启用。开发包仍为 Build 25、自动化仍为此前 274 PASS。未新增修复代码、未覆盖 Build 17、未创建 tag 或发布 Release。
