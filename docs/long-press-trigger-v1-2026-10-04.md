# Long Press Trigger v1 — Build 27

2026-10-04。实现与自动化 PASS；本轮指定的 5 项核心真机验收全部 PASS。未进行额外全产品或发布验收，未发布。

## 1. MouseTrigger 扩展

新增 `.longPress` 与 `.modifiedLongPress(MouseModifiers)`，提供 `.longPress(modifiers:)`、`.isButtonPress`、`.base`、`.withModifiers`。短按与长按以独立 Input + Modifier + Trigger 键保存，彼此不冲突。设置页触发菜单包含短按、长按、四方向拖动；拖动继续只读展示原有配置。现有拖动 order 与稳定 UUID 不变，显示顺序另用 displayOrder。

包含长按的映射文档使用 v3；新读者兼容 v1/v2。旧读者会拒绝 v3，不会把长按误认成短按。仍保存在 UserDefaults `gesture.configuration.v1` 内的 `mouseMappingsV1` Data，一次原子偏好写入。旧格式不会自动生成任何长按动作。

## 2. Long Press threshold

单一默认源 `LongPressConfiguration.defaultDuration = 0.5` 秒。配置对象允许注入 0.3–1.0 秒，异常值回到默认；当前不增加持久化时长字段或 UI 滑块。

## 3. Timer / clock

`LongPressScheduler` 将单调时钟 `now` 和 `schedule(at:)` 注入协调器。运行时使用现有 engine 串行队列的单次 DispatchSourceTimer，时间与原输入的 monotonicTime 一致。只为有效、启用且非 none 的长按候选分配计时器。

每次按压有独立 generation；旧取消回调不能作用于后续按压。回调执行一次后释放 source；提前唤醒会重新安排剩余时间。测试使用虚拟 scheduler，不需要 sleep 500ms。

## 4. Press lifecycle

`PressClaim`：pending、drag、longPress、cancelled。每个候选保存 deadline、按钮按下时 modifiers、已解析 action、generation、可取消计时器。mouseUp 移除生命周期。停止/重启清除全部生命周期；仅取消时保留 cancelled 归属直到释放，不能重新变成短按。

## 5. Short / Long / Drag 仲裁

- 松开早于阈值，且原点击 tracker 同意：立即执行短按。
- 原 tracker 识别拖动：归属 drag，取消计时器；反向回原点也不能恢复短按或长按。
- 长按先触发：归属 longPress，移除其原点击候选，mailbox 将这个物理按钮排除出拖动驱动集合。物理 mouseUp 仍被捕获并用于清理。
- 最后一个拖动驱动被排除时，通过原有 logical modifier-up 结束 detecting pipeline。已有其他按下按钮仍可驱动原手势。
- 长按之后的缓冲 motion 不能在已退休的候选上启动拖动。
- 释放发生在 deadline 或之后、计时器回调尚未运行时，只执行一次长按；先处理 queued gesture-up，再发动作，绝不补短按。
- 计时器回调先排空已收到输入；已经识别的拖动、Escape、tap 中断或释放先处理。按压 epoch 防止处理中途取消/恢复后继续发动作。

拖动识别只观察原 SideButtonClickTracker / StandaloneShortPressTracker 的结果，复用原 GestureMachine deadZone（当前 8 px）；没有第二套移动阈值。多个 legacy drag 按钮仍共享原连续手势管线；它们各自的长按计时器与动作快照独立。中键及其他额外按钮保留原“移动超阈值即取消点击”的规则，不在本轮新增任意按钮的原生拖动动作替换。

## 6. Modifier snapshot

沿用 MousePressContexts，在 buttonDown 冻结 CGEvent flags。长按 action 也在 down 时解析一次，timer 不再读取当前修饰键。精确组合优先；精确项存在但禁用/none 时抑制普通项；不存在精确组合时按原短按规则回退普通项，不匹配 modifier 子集，也不同时执行两条动作。

录制器仍只录 Button + Modifiers。编辑页在更换输入时保留用户已选择的 longPress base，不要求通过真实长按录制触发方式。左右主键保护继续保留。

## 7. 短按延迟

没有新增等待：100ms 松开仍立即执行短按，不等到 500ms。无有效长按映射的按钮没有长按计时器，也不建立长按候选。映射解析只在按钮按下时发生，mousemove 不扫描映射、不创建 Task 或 timer。

## 8. 连续手势核心保护

未修改 GestureMachine、VerticalGestureTracker、Native Bridge 或 Space swipe internals；与本轮前基线 SHA-256 一致。SideButtonClickTracker 也完全未修改。StandaloneShortPressTracker 仅增加只读 dragStartedButtons 投影，不改变移动累计或阈值判定。

GestureEngine / InputMailbox 外围新增长按仲裁、拖动驱动退休与 timer 清理。动作执行器及各动作实现、鼠标录制器 3 个文件、按钮编号/修饰键模型、键盘录制器、app main 均保持本轮前哈希不变。

## 9. 本轮文件

新增：

- Sources/MouseGesturePOC/LongPressConfiguration.swift
- Sources/MouseGesturePOC/LongPressScheduler.swift
- Sources/MouseGesturePOC/LongPressCoordinator.swift
- Tests/CoreRegression/LongPressTests.swift
- docs/long-press-trigger-v1-2026-10-04.md

修改：

- Sources/MouseGesturePOC/MouseMapping.swift
- Sources/MouseGesturePOC/MouseMappingStore.swift
- Sources/MouseGesturePOC/AppConfig.swift
- Sources/MouseGesturePOC/AppViewModel.swift
- Sources/MouseGesturePOC/MappingSettingsView.swift
- Sources/MouseGesturePOC/GestureEngine.swift
- Sources/MouseGesturePOC/MouseInput.swift
- Sources/MouseGesturePOC/StandaloneShortPressTracker.swift
- Tests/CoreRegression/MouseMappingTests.swift
- Tests/CoreRegression/main.swift
- scripts/test.sh
- README.md

build/long-press-v1/build27 内的备份、清单、日志和临时验收配置工具只供本地使用，不加入 App 的功能。

## 10. 新增测试

新增 69 项：阈值前/等于/之后、重复与迟到/提前 timer、十秒不重复、短长共存/冲突、禁用删除/none、原 deadZone、拖动反转、长按后移动、独立按钮、modifier 快照与精确匹配、v3 持久化、旧格式、主键保护、界面模型编辑、mailbox 物理捕获/驱动退休/恢复、取消与释放、跨会话旧回调、对象退出清理等。

清理测试覆盖协调器的取消生命周期，mailbox 测试覆盖输入退休/恢复；实际 app 停止、失焦、录制开始、退出、权限丢失与 tap 失效的外围调用已接入，仍需要真实环境确认。自动化不代表真机动作结果。

## 11. 全部测试结果

`zsh scripts/test.sh`：

- CoreRegression：371 PASS，0 FAIL，0 SKIP。
- BridgeContract：15 PASS，0 FAIL，0 SKIP，posting intercepted。
- 总计：386 PASS = 原有 317 + 新增 69。

保留全部原有检查。有且仅有一处旧测试输入更新：原先“未知 trigger”用 longPress 举例，这轮已成为有效值，将未知值改为 doubleClick。未知值仍必须解码失败，不删检查、不将失败改为跳过。其他原测试文件内容保持本轮前基线；main 仅注册新增检查。

独立完整 App 编译和 codesign --verify --deep --strict 通过。唯一构建警告为项目现有旧 Swift driver deprecated。

## 12. 已知限制

- 本轮指定的 5 项核心真机验收已全部 PASS；范围限于当前鼠标、当前 macOS 和测试配置，不代表额外全产品兼容测试。
- Timer 的实际派发时间受 engine queue 与系统调度影响；释放处有到期补偿，确保不能错误落为短按。
- ⌘T 等动作依赖当前前台 App；本轮不新增全局私有窗口或快捷键实现。
- ⇧⌘4 录制限制、Finder 返回问题、其他旧动作兼容限制继续冻结。
- 不实现双击、hold repeat、Long + Drag、滚轮组合、按键 chord、按 App 配置或宏。
- v3 长按配置不是旧开发版可编辑格式；退回旧版前应使用本轮前偏好备份，或从新开发版删除长按项并保存。稳定 Build 17 的 App 文件未被覆盖。

## 13. 最新开发版

`build/long-press-v1/build27/MacMouseGesture Long Press Dev.app`

Version `0.2.0-beta.1-long-press-dev` / Build 27。已安全退出旧 Build 26，启动 Build 27；实际进程 PID 45427 的 executable 路径与该 App 一致。界面显示“正在运行”“辅助功能权限已开启”，无需重新授权。UI 检查确认长按与短按两行、6 个 trigger 菜单、可编辑长按与 ⌘T；取消检查草稿，没有覆盖已保存设置。

已有中键/侧键4/侧键5短按与全部拖动设置保留，为验收新增侧键5 longPress → keyboardShortcut（keyCode 17 / modifierFlags 1048576）；在 Test 5 前追加 ⌘ + 侧键4 longPress → 同一 ⌘T 动作。重启同一 Build 27 后确认两条长按与原有短按同时存在、服务运行且权限正常；原有所有映射和其他配置字段均保留。本轮前完整本地偏好备份：build/long-press-v1/build27/pre-long-press-settings.plist。post-launch-settings.plist 和 build-manifest.json 保存新配置、source hash、exe hash 与运行路径。

/Applications/MacMouseGesture.app Build 17 的 Info.plist 与 executable SHA-256 与本轮前一致。未创建 tag、Release 或 push 发布版本，未覆盖/删除稳定版。

## 14. 第一个真机测试动作与记录

已设置：侧键5短按 → 显示桌面；侧键5长按 → ⌘T。

Test 1：快速点一下侧键5，不拖动。预期显示桌面一次，不能打开新标签页。

| 项目 | 结果 |
|---|---|
| Test 1 快速短按 | PASS：显示桌面一次，未触发 ⌘T（用户回复 A） |
| Test 2 按住超过500ms | PASS：打开一个新标签页，松开后未显示桌面（用户回复 A） |
| Test 3 立即拖动 | PASS：原有桌面切换正常，没有新标签页或显示桌面（用户回复 A） |
| Test 4 小抖动后继续长按 | PASS：打开一个新标签页，无桌面切换或显示桌面（用户回复 A） |
| Test 5 ⌘ + 侧键4长按 | PASS：只打开一个新标签页，松开后未切换全屏（用户回复 A） |

每次只发一个手动测试动作。失败即暂停后续，记录实际/预期/复现条件，先定位，不扩大修改范围。

## 最终验收结果

Long Press Trigger v1 Real-device Acceptance

- Test 1：PASS — 快速短按正常，无长按动作。
- Test 2：PASS — 长按一次 ⌘T，松开无短按动作。
- Test 3：PASS — 立即拖动正常，无短按或长按动作。
- Test 4：PASS — 轻微抖动后长按正常，无桌面切换或显示桌面。
- Test 5：PASS — ⌘ + 侧键4长按正常，松开未切换全屏。

总体：本轮 5/5 PASS。新增问题：本轮指定测试中未报告异常。自动化 386/386 PASS。建议将 Long Press Trigger v1 标记为本轮验收完成，可进入下一阶段；不据此自动发布。

保留当前验收映射，继续运行独立 Build 27；稳定 Build 17 未覆盖/删除。最终再次确认稳定 Info.plist / executable 哈希与本轮前一致。未创建 tag、Release 或 push 发布版本。冻结问题保持冻结。
