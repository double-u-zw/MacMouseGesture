# General Mouse Input Recorder v1

日期：2026-10-04。独立开发包 Build 26。本轮冻结 Build 25 的快捷键问题，不继续修复 ⇧⌘4，不发布。

## 1. 统一编号与名称

MouseButtonIdentifier 是应用层唯一的编号转换边界。CGEvent/HID raw 0...31 对应用户编号 1...32；映射存储继续使用现有一基 MouseInput.button(number)，原侧键身份不变。

| 物理身份 | 原始编号 | 持久化编号 | 界面名称 | 本版允许映射 |
|---|---:|---:|---|---|
| 主按键 | 0 | 1 | 左键 | 否 |
| 辅助按键 | 1 | 2 | 右键 | 否 |
| 中键 | 2 | 3 | 中键 | 是 |
| 现有侧键 4 | 3 | 4 | 侧键 4 | 是 |
| 现有侧键 5 | 4 | 5 | 侧键 5 | 是 |
| 其他额外按键 | 5...31 | 6...32 | 鼠标按钮 N | 是 |

MouseInput 可表达主按键身份，Mapping Store 和解码仍禁止主按键有效映射，保持原保护边界。异常编号（包括整数极值）安全拒绝。GestureCore 中旧 MouseButton enum 保持不动；当前应用解析、显示、录制和旧配置投影使用新转换层。

## 2. 录制截获与生命周期

新增 MouseInputRecorder（有锁的截获状态）、MouseInputRecorderService（主运行循环上的临时 CGEventTap）、MouseInputRecorderView（中文 Sheet）。

进入录制时，暂时暂停普通输入引擎并清理旧待定点击/手势，创建临时 HID head tap。录制结束后按原启用配置重启普通服务，不修改任何手感参数。主页面的一秒刷新不会在录制期间偷偷重启普通引擎。

录制层只监听鼠标按钮边沿。第一次合法额外按钮 down 捕获编号与修饰键，立即结束等待；对应 up、重复 down 都吞掉，不再捕获。左/右键显示保护提示且放行，继续等待，取消等界面操作仍可使用。

录制 tap 与正常 InputMailbox 共享同一个截获门。已吞掉 down 的按钮保留释放隔离，即使在松开前取消、Escape 或关闭 Sheet，up 也不会进入普通映射。普通服务在录制期间暂停，已在执行的短按 one-shot 也按原停止路径取消。临时 tap 在 Sheet 结束且释放隔离清空后移除。

取消、Escape、Sheet 关闭、应用失焦、睡眠/会话退出、权限撤销和 App 退出均结束等待。录制结果只在“使用此输入”后进入编辑草稿，外层“保存”才写配置。取消不修改原映射；Sheet 关闭处理幂等，避免重复 dismiss。

## 3. 修饰键保存与匹配

MouseModifiers 保存 Command / Option / Control / Shift 对应 CGEventFlags 的 UInt64 位掩码，支持多个修饰键；Caps Lock、Fn 等不作为匹配条件。只按修饰键不会完成鼠标录制。组合显示如“⌥⇧ + 中键”。

MouseTrigger 新增 modifiedShortPress，Codable 表示为 kind=shortPress、modifiers=数值。无修饰键仍使用原 shortPress；拖动仍只展示原配置，本轮不实现修饰键拖动替换。

映射唯一键为 Input + Trigger（含修饰键）。匹配先查完全相同的组合；若没有该组合，才回退无修饰键短按。没有模糊包含：⌘⇧ 不匹配仅要求 ⌘ 的条目。精确项禁用时不回退，精确项无操作时也不会执行普通项。Resolver 最多返回一个动作。

正常短按在物理 down 时记录修饰键快照，up 时使用该快照；中途松开/增加修饰键不改变这次按键身份。恢复、取消、失焦与停止清理快照。原拖动阈值和短按抑制检测保持原实现。

## 4. 配置兼容

UserDefaults 的 gesture.configuration.v1 / mouseMappingsV1 保持原位置。没有修饰键的数据继续采用文档 version 1；包含修饰键时使用 version 2，当前 reader 兼容两版。

这样旧 Build 25 会对 version 2 短按文档安全停止解析，避免把修饰键映射当成普通点击。Build 17 降级字段继续只表示普通侧键短按，不写入修饰键动作。旧普通映射的 UUID、按钮编号、动作与手势参数均保留。

迁移/启动前全量设置备份：build/input-recorder-v1/build26/pre-recorder-settings.plist。

## 5. 文件

新增：

- Sources/MouseGesturePOC/MouseButtonIdentifier.swift：编号、名称、修饰键、录制结果。
- Sources/MouseGesturePOC/MouseInputRecorder.swift：一次捕获、释放隔离、按下修饰键快照。
- Sources/MouseGesturePOC/MouseInputRecorderService.swift：临时 tap 生命周期。
- Sources/MouseGesturePOC/MouseInputRecorderView.swift：录制 Sheet。
- Tests/CoreRegression/MouseInputRecorderTests.swift：43 项新增回归。
- docs/general-mouse-input-recorder-v1-2026-10-04.md：本报告。

修改：MouseMapping.swift、MouseMappingStore.swift、MappingSettingsView.swift、AppViewModel.swift、MouseInput.swift、GestureEngine.swift、AppConfig.swift、SettingsView.swift、main.swift、Tests/CoreRegression/main.swift、scripts/test.sh、README.md。

GestureMachine、VerticalGestureTracker、Native Bridge、HIDInputBackend、SideButtonClickTracker、StandaloneShortPressTracker、旧动作 Executor、旧快捷键录制器及已验收系统动作实现均与本轮开始时字节一致。GestureEngine / MouseInput 修改了入口接线、录制暂停与修饰键传递，不能声称它们整个文件未变；未重写手势算法。

## 6. 自动化与已知限制

新增 43 项；原有 274 项保留，总计 317 PASS（302 regression + 15 Bridge），0 FAIL、0 SKIP。测试不注入真实手势，不能替代真实鼠标验收。

覆盖 raw / UI 编号、中键及侧键与其他按钮、主按键保护、一次捕获、up 隔离、取消/Escape/Sheet/失焦退出路径、正常 mailbox 恢复、合成导航来源过滤、单/多修饰键、modifier-only、精确匹配/无重复执行/无模糊包含、持久化/删除/禁用和旧配置兼容。

限制：

- 鼠标必须向 macOS 报告真实可区分的按钮事件；报告为键盘快捷键或被厂商工具提前改写的按键无法凭空恢复原身份。
- 所有映射全局生效，没有设备或应用 Profile；raw 2...31 是本版本边界。
- 修饰键只作用于短按。现有四方向仍走原 GestureMachine / Bridge。
- 录制需要当前包的辅助功能权限。应用失焦会取消录制，不捕获其他应用中的点击。
- 已吞掉按钮如果一直不松开，释放隔离会保留直到收到对应 up；不引入录制强制超时。
- 上一轮 ⇧⌘4 键盘录制限制及 Finder 返回问题保持冻结。⌘T、⌘W、持久化的旧 PASS 不扩展为所有快捷键 PASS。
- 本轮真实鼠标输入与修饰键触发仍待用户逐项确认，不重新发起旧功能整套验收。

## 7. 开发包和本轮验收

开发包：build/input-recorder-v1/build26/MacMouseGesture Input Recorder Dev.app，版本 0.2.0-beta.1-input-recorder-dev，固定项目证书签名。稳定 /Applications Build 17 与旧 Build 25 开发包均保留。

| 检查 | 结果 |
|---|---|
| 自动化 317 项 | PASS |
| 工具驱动新添加映射 / 初始保存禁用 | PASS |
| 工具驱动 Escape 返回输入草稿 | PASS |
| 开发中观察到中键已进入草稿 / 已存在启用映射 | OBSERVED（不替代用户正式确认） |
| 真机 1：中键录制显示“中键”，不触发已配置的显示桌面 | PASS（2026-10-04 用户回复 A） |
| 真机 2：侧键 4 录制显示“侧键 4”，不触发已有短按动作 | PASS（2026-10-04 用户回复 A：识别正确，未切换全屏） |
| 真机 3：侧键 5 录制显示“侧键 5”，不触发显示桌面 | PASS（2026-10-04 用户回复 A） |
| 真机 4：其他额外按钮录制（视鼠标硬件而定） | 跳过（2026-10-04 用户回复 B：鼠标没有其他额外按钮） |
| 真机 5：⌘ + 侧键 4 录制名称与旧动作隔离 | PASS（2026-10-04 用户回复 A：⌘ + 侧键 4，未切换全屏） |
| 本轮适用的输入录制真机检查 | 4/4 PASS，另 1 项因没有硬件跳过 |

第一项只让用户在“添加映射 → 按下鼠标按钮…”的录制窗口正常按一下中键，核对“检测到：中键”；先不保存，也不扩展成旧手势回归。未 tag、未发布 Release、未覆盖稳定 Build 17。

最终核验：运行进程 PID 41843，内核可执行路径来自本轮 Build 26 独立包，固定签名有效。实际配置比开始时新增一条“中键短按 → 显示桌面”（启用，UUID 4C3A7DA0-6936-4655-812E-13404FCAD159）；工具没有点击外层保存，保留观察到的用户当前配置，不擅自删回。原有映射与其他手势字段完全保留。该现存中键动作可用于第一项确认：录制中按中键应只显示识别结果，不同时执行显示桌面。旧快捷键录制器与上一轮已知问题保持冻结。

第 1 项收到用户回复 A，真实中键被识别为“中键”，且录制时没有执行已配置的显示桌面，记为 PASS。第 2 项仅准备侧键 4 录制，不保存草稿、不修改原映射；等待用户确认名称与已有动作隔离。

第 2 项用户回复 A，侧键 4 的真实录制名称与现有全屏动作隔离均 PASS。第 3 项只录制侧键 5，不保存草稿，等待用户确认“侧键 5”且不显示桌面。

第 3 项用户回复 A，侧键 5 的真实录制名称与显示桌面动作隔离均 PASS。中键和两个侧键三项通过。第 4 项仅检查鼠标上若存在的其他额外按钮；没有对应硬件则记为跳过，不记为 PASS。不保存录制草稿、不修改现有映射。

第 4 项用户回复 B，当前鼠标没有其他额外按钮，记为硬件不适用/跳过。第 5 项为本轮最后一个输入录制检查：按住 Command 再正常按一次侧键 4，期望“检测到：⌘ + 侧键 4”且不执行原全屏动作；只录制、不保存。

第 5 项用户回复 A，⌘ + 侧键 4 的真实录制与原全屏动作隔离 PASS。本轮限定的输入录制验收完成：中键、侧键 4、侧键 5、Command + 侧键 4 共 4 项 PASS；其他额外按钮因无硬件跳过，不记为 PASS。未发现本轮录制问题。

已取消未保存的添加映射草稿，确认设置页恢复普通服务“正在运行”、辅助功能权限开启。当前中键→显示桌面、侧键 4→全屏/退出全屏、侧键 5→显示桌面均保留并启用，拖动设置保持开启。修饰键运行时精确匹配、更多组合及其持久化已有自动化覆盖；这次物理检查只验证输入录制，不扩大成这些运行时行为均已真机通过，也不重新验收旧手势或修复冻结问题。

结论：General Mouse Input Recorder v1 本轮输入录制验收 PASS。自动化仍为 317 PASS。Build 26 继续作为开发版使用；稳定 Build 17 保留，未 tag、未发布 Release。
