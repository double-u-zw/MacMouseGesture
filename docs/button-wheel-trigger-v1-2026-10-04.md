# Button + Wheel Trigger v1 — Build 28

2026-10-04。开发、完整自动化、独立签名 App 编译及设置 UI 检查完成。本轮指定的真机 Test 1–8 均由用户确认 PASS，8/8 完成。旧问题保持冻结，无 tag、Release 或发布操作，稳定 Build 17 文件未覆盖。

## 1. Trigger 数据模型与 UI

`MouseTrigger` 新增 `.wheelUp`、`.wheelDown`、`.modifiedWheel(MouseWheelDirection, MouseModifiers)`，统一使用 `.wheel(direction, modifiers:)` 构造。`MouseWheelDirection` 为 Codable 的 `up/down`。每条映射仍有必需的 `MouseInput.button(3...32)`；左右主键仍受保护，不能创建单独的滚轮映射。

`isButtonPress` 包含 wheel chord，因此沿用原 AppConfig 投影、服务资格判定、AppViewModel 编辑/禁用/删除路径。`base` / `withModifiers` 保留录制器产生的 Button + Modifiers，同时保留所选 wheel 方向。录制器无需实际滚轮输入，其三个源文件均未修改。

用户菜单顺序：短按、长按、按住并向上滚动、按住并向下滚动、向左拖动、向右拖动、向上拖动、向下拖动。界面没有 wheelUp/wheelDown 开发术语。原拖动 `order` 与稳定 UUID 保持不变，显示顺序使用 `displayOrder`。

## 2. Mapping 文档格式

包含任何 wheel trigger（包括禁用项）的文档写入 v4；无 wheel 的文档仍按现有策略写入 v1/v2/v3。新读者兼容 v1–v4，并拒绝把 wheel 装进 v1–v3、把 long 装进 v1–v2 或把 modifier 装进 v1。

样例：

```json
{
  "version": 4,
  "mappings": [{
    "id": "00000000-0000-0000-0000-000000000005",
    "input": {"kind": "button", "number": 5},
    "trigger": {"kind": "wheel", "direction": "up", "modifiers": 1048576},
    "action": {"kind": "keyboardShortcut", "shortcut": {"keyCode": 17, "modifierFlags": 1048576}},
    "isEnabled": true
  }]
}
```

旧 Mapping 读者无法解码未知 wheel kind，并且拒绝超出支持范围的文档版本；不会把 wheel 降级为 shortPress。未知未来 trigger、方向或版本失败关闭，ConfigStore 不回退旧 short action。旧数据不自动生成 wheel 行，保存/加载和迁移幂等。仍原子保存于 `gesture.configuration.v1` 的 `mouseMappingsV1` Data，不改变配置键或其他偏好字段。

## 3. 唯一方向转换与 Natural Scrolling

唯一入口：`WheelScrollSample(event:)`。通过 `NSEvent(cgEvent:)` 获取 `scrollingDeltaY`、`hasPreciseScrollingDeltas`、`isDirectionInvertedFromDevice`、`momentumPhase`；连续标记同时兼容 `CGEvent.scrollWheelEventIsContinuous`。转换失败时透传，避免猜测全局偏好。

```text
NSEvent.scrollingDeltaY (raw delta)
    ↓ isDirectionInvertedFromDevice ? -delta : delta
WheelScrollSample.physicalDelta
    ↓ > 0: up / < 0: down / 0、非有限: 无方向
MouseWheelDirection.up/down
```

系统会根据自然滚动偏好反转 NSEvent delta，Apple 明确允许使用该标记乘以 -1 补偿：[Apple direction inversion 文档](https://developer.apple.com/documentation/appkit/nsevent/isdirectioninvertedfromdevice)。代码不读取全局 Natural Scrolling 设置，不在 engine、mailbox 或 mapping 层另行判断原始 sign。

测试覆盖自然滚动关闭的正 delta 与开启的负 delta 均为物理 Up，以及 Down 和连续累计。真实鼠标在两个系统设置下的方向尚待手动确认，不能将注入样本测试称为系统开关真机 PASS。其他滚轮反转工具或驱动额外修改事件时可能需要另行确认。

## 4. Logical step 与重复控制

`WheelStepConfiguration` 是统一、可注入参数来源：

| 参数 | v1 默认值 | 单位与用途 |
|---|---:|---|
| 连续累计阈值 | 10 | AppKit points |
| 最小动作间隔 | 0.04 | 秒，上限 25 actions/s |
| 累计闲置重置 | 0.25 | 秒，防止久前残量与新输入拼接 |

离散事件以 1 个 AppKit line 单位累计；正常整步事件最多输出一个动作，高分辨率的 fractional line 也能累计。连续事件按 points 累计，达到 10 points 才输出一步。保留不足一步的 remainder。

每个原始事件最多一步。异常大 delta 超出的完整 steps 直接丢弃，保留取模后的 fractional remainder，不形成后续待执行债务。40ms 内额外完整步被丢弃，没有延迟 timer 或队列补发；滚轮快速 free-spin 不会积压几十个动作。方向反转、离散/连续单位切换或闲置间隔超过阈值时清空累计，冷却时间继续有效。momentum 不建立新 wheel claim、不重复执行动作；已有 wheel claim 时仍消费其垂直 momentum。

这组默认参数根据 AppKit 的 lines/points 单位选择，10 points 和 40ms 是 v1 保守初值，尚未通过当前真实鼠标的数据校准。清晰 detent 间隔至少 40ms 时，每个 detent 一次；更快的 detent 可能被限速丢弃。没有新增速度设置 UI。

## 5. 一个 press owner 的仲裁

继续扩展现有 `LongPressCoordinator`，不另建 wheel claim source，暂保留原类名：

```text
PressClaim = pending / drag / longPress / wheel / cancelled
```

每个 press 保存 generation、修饰键快照、long action、两个方向的有效 wheel action 快照、归一化器和原 long timer。仅有 wheel 时创建 press 生命周期，但不分配 long timer。

- 快速 down/up，没有其他 owner：原 tracker 同意时立即短按，不增加短按等待。
- Long 已先执行：claim 为 longPress，后续 wheel 普通透传。
- 原 tracker 已跨过 deadZone：claim 为 drag，后续 wheel 普通透传，保留原 Drag 行为。
- 自然抖动未跨 deadZone：仍为 pending，可触发 wheel。
- 首次有 Mapping 的 logical step：claim 为 wheel，取消 long timer，移除短按/拖动候选；动作异步发到原 engine queue。
- Wheel 已拥有 press：后续垂直 Up/Down 继续解析；移动不能让该按钮再次进入 Drag，mouseUp 仅清理，不触发 short/long。
- 同时按住的其他未退休按钮仍可驱动原 Drag，不因为一个 wheel owner 而全部取消。
- Escape、停止、录制开始、设置重启、权限丢失及 tap 恢复继续通过现有取消/重置路径清理；cancelled 不恢复短按。

## 6. 修饰键与多按钮

沿用 `MousePressContexts` 在 down 冻结修饰键。Wheel action 在 down 精确解析并保存，后续松开/新增键不会改变本次按压。Wheel 使用完整 modifier 集合精确匹配，无 modifier 子集匹配、无向 plain wheel 行回退。Short/Long 原 fallback 策略保持不变。

没有固定 wheel owner 时，选择最近按下、claim 为 pending、且冻结 modifier 组合具有任意有效 wheel mapping 的按钮。仅解析它当前方向，不因它缺少该方向而回退到更早按钮。

首次成功输出 wheel step 后，该按钮固定为 wheel owner，后续按下另一 eligible button 不能抢走。Owner release 后，仍按住的其他 pending eligible button 可在下一次 wheel 重新获得归属。一次 wheel event 最多执行一条 mapping。重复 down 不改变 generation/recency 或快照。

## 7. 消费规则与事件 tap

| 场景 | 消费 |
|---|---|
| 没有物理鼠标按钮按住 | 透传 |
| 按住按钮但没有有效 wheel mapping / modifier 不匹配 | 透传 |
| 已属于 Long 或 Drag，无其他 eligible button | 透传 |
| 第一次命中前，最近 eligible button 缺少当前方向 mapping | 透传并清空残量 |
| 有当前方向 mapping，连续小 delta 尚在累计 | 消费，暂不 claim、不执行动作 |
| 有当前方向 mapping，输出 logical step | 消费并执行动作，首次锁定 wheel family |
| 已 claim wheel，当前方向没有 mapping | 消费，不执行动作 |
| 已 claim wheel，当前 event 被限速 | 消费，不执行动作 |
| 已 claim wheel，垂直 momentum | 消费，不执行动作 |
| 纯水平 / 垂直 delta 为零 / 非有限样本 | 透传，不推导横向方向 |

消费的是整个有垂直 delta 的原始 scroll event；混合水平/垂直事件匹配 wheel chord 时不拆分重发水平部分。当前 action 被选中后，即使 action executor 最终失败，也保持消费，避免前台页面发生意外滚动。

Tap 必须在返回前决定是否消费。`WheelInputHandoff` 将解析投递到原 engine 串行队列，先 drain 已收到的按钮/移动，再调用同一个 press owner。Mailbox 不持锁等待 engine，Posting 不在 tap 的决定临界区执行。

等待预算为 8ms；engine 繁忙超时会撤销 request 并透传。撤销后不能迟到建立 claim 或执行 wheel action，相关边界有测试。极端负载下会丢弃该 chord event 并出现普通滚动，这是优先保持 tap 可用的已知例外。已有 tap 恢复和物理 hold quarantine 继续生效。

## 8. 核心保护与文件清单

本轮前后 SHA-256 相同：GestureMachine、VerticalGestureTracker、Native Bridge、SideButtonClickTracker、StandaloneShortPressTracker、录制器三个源文件、MouseButtonActionExecutor、Resources/Info.plist。没有修改 deadZone、Space swipe internals 或动作库。AppConfig/AppViewModel 现有通用路径直接接受新的 `isButtonPress`，本轮无需修改其源码。

新增：

- Sources/MouseGesturePOC/WheelStepNormalizer.swift
- Sources/MouseGesturePOC/WheelInputHandoff.swift
- Tests/CoreRegression/WheelTriggerTests.swift
- scripts/build-wheel-dev.sh
- docs/button-wheel-trigger-v1-2026-10-04.md

修改：

- Sources/MouseGesturePOC/MouseMapping.swift
- Sources/MouseGesturePOC/MouseMappingStore.swift
- Sources/MouseGesturePOC/LongPressCoordinator.swift
- Sources/MouseGesturePOC/MouseInput.swift
- Sources/MouseGesturePOC/GestureEngine.swift
- Sources/MouseGesturePOC/MappingSettingsView.swift
- Tests/CoreRegression/main.swift
- scripts/test.sh
- README.md

本轮前项目有上一轮开发留下的未提交文件，本轮保留它们，没有 reset、清理、覆盖或提交。build/button-wheel-v1/build28 中的偏好备份、清单、浏览器测试页和构建日志只供本地验收。

## 9. 自动化与构建

新增 88 项，保留全部 386 项原检查：

- CoreRegression：459 PASS，0 FAIL，0 SKIP。
- BridgeContract：15 PASS，0 FAIL，0 SKIP，posting intercepted。
- 合计：474/474 PASS = 386 + 88。

检查覆盖 Up/Down、repeat/reversal/release、short/long/drag/wheel 仲裁、真实原 deadZone tracker、轻微抖动与缓冲 motion 顺序、消费、单方向反向规则、连续累计/remainder/异常巨大值/限速/反转/单位切换/闲置、自然方向注入、momentum、modifier 精确快照、多按钮 recency/pinned/release、取消清理、Codable/v1–v4/未知未来格式、UI model 和同步 handoff 撤销。

命令：`zsh scripts/test.sh`。受限运行的原基线和初次修改版都在原跨进程偏好检查失败后异常退出；在正常 macOS 环境重跑完整套件得到上述全部 PASS，没有跳过或删改原检查来规避失败。

独立 App 完整编译、`codesign --verify --deep --strict` 和指定证书 requirement 校验通过。构建日志只含现有 legacy Swift driver deprecated 警告。

最新开发版：

```text
build/button-wheel-v1/build28/MacMouseGesture Button Wheel Dev.app
Version 0.2.0-beta.1-button-wheel-dev / Build 28
```

安全退出 Build 27 后启动 Build 28。实际进程 PID 51634 的 executable 路径与此 App 一致；界面确认“正在运行”“辅助功能权限已开启”。UI 确认 wheel 上下独立行、⌘ modifier 行、⌘T/⌘W、8 项 trigger 菜单；取消检查草稿，没有修改已保存映射。

`/Applications/MacMouseGesture.app` Build 17 的 Info.plist/executable 哈希与本轮前一致，Build 27 的 App 也保留。无 tag、Release、push 或发布。

## 10. 真机测试配置与已知限制

本轮前偏好在 pre-wheel-settings.plist、退出 Build 27 后在 pre-launch-settings.plist 完整备份。仅追加三个 wheel 映射，原 short/long/drag 和其他偏好全部保留；post-launch-settings.plist 逐项比对通过。

| 输入 | 触发方式 | 动作 |
|---|---|---|
| 侧键 5 | 短按 | 显示桌面，原配置 |
| 侧键 5 | 长按 | ⌘T，原配置 |
| 侧键 5 | 按住并向上滚动 | ⌃Tab，当前手感测试配置 |
| 侧键 5 | 按住并向下滚动 | ⌃⇧Tab，当前手感测试配置 |
| ⌘ + 侧键 4 | 按住并向上滚动 | ⌘T，新配置 |

当前限制：没有 Device Profile，按住鼠标按钮时的连续事件可能来自 MacBook 触控板，v1 无法可靠区分；连续阈值尚未真机校准；40ms 限速可丢弃非常快的 detent；外部反转驱动需另验；handoff 极端负载超时透传。⌘T/⌘W 依赖当前前台 App。双击、Long+Drag、水平映射、Button Chord、App/Device Profile、宏、Shell、新动作库和速度 UI 均不实现，旧问题保持冻结。

第一项真机动作：在 Chrome 的可滚动页面，不按任何鼠标按钮，上下滚动几下。预期网页正常滚动，不开/关标签页，不显示桌面。可使用 build/button-wheel-v1/build28/browser-scroll-test.html 本地长页面。浏览器 UI 自动化连接中断，未把自动滚动或模拟事件算作真机 PASS；第一项实际鼠标测试已通过文字问题交给用户。

| 真机项目 | 预期 | 结果 |
|---|---|---|
| Test 1 普通滚轮 | 正常滚动，无额外动作 | PASS：用户确认普通滚动正常，没有额外动作 |
| Test 2 侧键 5 + ↑一次 | ⌃Tab：标签 2→3，页面不滚动 | PASS：用户回复“没问题” |
| Test 3 侧键 5 + ↓一次 | ⌃⇧Tab：标签 3→2，反向顺畅，释放不短按 | PASS：同一次上下反向测试，用户回复“没问题” |
| Test 4 侧键 5 + ↑三个清晰 detent | 标签 1→2→3→4，三次动作，无暴发 | PASS：用户回复“没问题” |
| Test 5 小于 deadZone 的抖动后 wheel | 标签 2→3，无额外动作 | PASS：用户确认只切到标签 3，没有额外动作 |
| Test 6 先拖过 deadZone 后 wheel | 原 Drag 正常，Wheel 不执行 | PASS：用户确认原 Drag 正常，Wheel 没有切标签或额外动作 |
| Test 7 等待超过 500ms、Long 已执行后 wheel | Long 一次 ⌘T，之后 Wheel 不切标签，释放不短按 | PASS：用户回复“没问题” |
| Test 8 ⌘ + 侧键 4 + ↑ | 按下后松开 Command，快照仍命中一次 ⌘T；释放不短按 | PASS：用户回复“没问题” |

每次只做一个物理鼠标测试。失败时记录实际/预期/条件，先定位再继续，不扩大修改范围。

## 11. 标签页切换手感验收（2026-10-04 追加）

用户明确保持“每个有效 logical step 执行一次 Action”，不改为一次按住仅执行一次。多滚几格重复创建标签本身不判为 bug，但 ⌘T/⌘W 不适合继续测手感。

通过 Build 28 设置编辑器及现有快捷键录制器，只替换侧键 5 两条 Wheel Action：Up → Control+Tab（keyCode 48 / flags 262144），Down → Control+Shift+Tab（keyCode 48 / flags 393216）。两条记录的 UUID、Input、Trigger、启用状态保持不变；所有其他记录和手势字段保持不变。UI 保存重新排列了投影 Drag 行，按 UUID 比对确认内容未变。Build 28 executable 哈希不变，无代码、Normalizer、限速或 repeat 改动，不新增 Build、不重跑无关自动化。

配置备份：build/button-wheel-v1/build28/pre-tab-switch-settings.plist；保存后逐项核对：post-tab-switch-settings.plist；当前两行：tab-switch-mappings.json。原始 acceptance-mappings.json 保留作历史，不覆盖。

生成本地编号测试页 tab-feel/tab-1.html 至 tab-5.html；实际在独立 Chrome 窗口打开编号 1–4 四个标签，保留原浏览器窗口。页面显示当前标签号码和 scrollY，便于观察步数与事件消费。侧键 5 Short → 显示桌面、Long → ⌘T 仍为原配置，所以测试应在 down 后 500ms 内先滚第一格；第一次 Wheel 成功后可持续按住重复与反向。

首个手感测试：标签 2 上，按住侧键 5 立即 ↑一格到 3，同一次按住 ↓一格回 2，再释放；预期无多跳、页面滚动或显示桌面。用户回复“没问题”，记录 Up/Down 单格与反向核心行为 PASS。连续三个刻度（标签 1→2→3→4）用户再次回复“没问题”，记录 Test 4 PASS；不把“多滑一下多建一个”的早期描述扩写为精确 detent 或全部仲裁验收 PASS。

Test 5 用户确认 PASS：轻微抖动后只切到标签 3，没有额外动作。Test 6 用户确认 PASS：原 Drag 正常，Wheel 没有切标签或额外动作。Test 7 用户回复“没问题”，记录 Long 先占后 Wheel 不切标签、释放不短按 PASS。Test 8 用户回复“没问题”，确认 Command + 侧键 4 在 down 后松开 Command，仍按冻结快照命中一次 ⌘T，释放没有全屏切换或其他动作，记录 PASS。

## 最终验收结果

Button + Wheel Trigger v1 Real-device Acceptance：本轮指定的 8/8 PASS。

- Test 1：普通滚轮正常，没有额外动作。
- Test 2：单格 Up 正好切一个标签。
- Test 3：单格 Down 正好反向切回，反向顺畅，无页面滚动或释放动作。
- Test 4：三个清晰 detent 正好切三次，无多跳或暴发。
- Test 5：轻微抖动后 Wheel 正常，无额外动作。
- Test 6：Drag 先开始后，Wheel 不抢占、不切标签；原 Drag 正常。
- Test 7：Long 先执行一次后，Wheel 不切标签，释放无短按或其他动作。
- Test 8：Command + 侧键 4 冻结修饰键后，松开 Command 再 Wheel 仍命中，释放无全屏或其他动作。

自动化维持 474/474 PASS（新增 88 项），手感测试期间没有代码、Normalizer 参数、动作执行器或 repeat 改动，因此不重复运行无关自动化。源码和 Build 28 executable 最终哈希与已测试版本一致。实际仍运行独立 Build 28，PID 51634 路径已再次核对，保留侧键 5 Wheel Up → Control+Tab、Wheel Down → Control+Shift+Tab 的当前映射。完整当前偏好保存于 final-current-settings.plist，原配置备份继续保留。

可以将 Button + Wheel Trigger v1 标记为本轮验收完成。范围限于当前鼠标、当前 macOS、当前测试配置和上述 8 项；不等同于额外高速 free-spin、所有设备、触控板来源区分或 Natural Scrolling 两个系统设置的真机兼容验收。连续 10 points 阈值及极快 detent 限速行为的限制继续保留，不扩大范围。

稳定 Build 17 的 Info.plist / executable 和核心手势、tracker、录制器的哈希已再次确认与本轮前一致；Build 27 保留。旧问题保持冻结，没有创建 tag、发布 Release、push 或覆盖稳定版。
