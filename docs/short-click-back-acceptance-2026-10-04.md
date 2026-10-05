# 返回专项修复与验收

状态：自动化 PASS；独立 Build 24 已启动，侧键 4=返回，侧键 5=显示桌面。Chrome 真机 PASS；Finder 真机 FAIL（用户回复 B，没有反应），已暂停后续验收并开始只读定位；Safari PENDING；未冻结返回动作。

## 实现与边界

旧实现硬编码 ⌘[。本轮将返回改为 CGEvent 的 otherMouseDown / otherMouseUp 配对，mouseEventButtonNumber=3、clickState=1、flags=0；两事件共用 privateState source，使用当前鼠标位置，不移动指针。完整分配成功后才投递，操作前重新确认权限和前台应用。

使用公开 eventSourceUserData 字段附加进程内随机标记。InputMailbox.capture 最前面仅放行带本进程标记的 otherMouseDown/up，防止重新触发短按或手势；不进入计数器、按键状态或恢复隔离逻辑。实际物理侧键和第三方事件仍走原路径。

CGEvent.post 没有应用处理确认；诊断 success 只表示配对事件已提交，不能当作浏览器导航成功。日志包含 action、button、executor、应用标识、result 和失败阶段，不记录标题、网址或用户输入。失败不重放导航、不回退键盘，避免一次点击导航两次。

Chromium 原生处理将 buttonNumber=3 解释为 Back，4 为 Forward：
https://raw.githubusercontent.com/chromium/chromium/main/components/input/web_input_event_builders_mac.mm
公开标记字段： https://developer.apple.com/documentation/coregraphics/cgeventfield/eventsourceuserdata

应用必须自行处理额外鼠标按钮，窗口还须有返回历史；指针应位于目标应用内容区域。不宣称所有应用都支持。Safari 和 Finder 兼容性尚未确认；前进动作仍保持旧实现，等待返回验收后单独处理。

## 自动化与冻结保护

新增 20 项：真实 CGEvent 字段和 NSEvent 按钮转换、配对分配失败、非法按钮/位置、权限/焦点变化、投递失败释放及不重试、负坐标、多次标记事件无递归、物理按钮独立、物理按住状态不被合成 up 释放、恢复隔离不被解除、Escape 行为、真实 mailbox/click tracker/machine 组合、日志和 executor 路由。

结果：208 项回归 + 15 项 Bridge = 223 PASS，0 FAIL，0 SKIP。真实事件投递被测试桩拦截，无真机导航结论。输出：build/short-click-acceptance/back-mouse-test-output.txt。

GestureMachine、VerticalGestureTracker、Bridge、GestureEngine、SideButtonClickTracker、AppConfig，以及显示桌面、Mission Control、App Exposé、最小化、全屏路径均与 Build 23 冻结哈希一致。逆向移除 MouseInput 的标记放行和 executor 返回接线后，两文件哈希均与 Build 23 一致。未改阈值、短按判定、连续手势或其他动作。

## 开发包与验收准备

- 独立包：build/short-click-acceptance/build24/MacMouseGesture Short Click Dev.app。
- Build 23 正常退出；内核确认当前 PID 29752 的实际可执行文件来自 Build 24 开发包。
- 源码与 build24/build-manifest.json 一致，固定证书签名验证通过。
- UI 显示服务正在运行、辅助功能已开启。旧设置已备份为 build24/pre-back-settings.plist；除侧键 4 的动作外，其他配置与备份一致。
- /Applications 的稳定 Build 17 plist/可执行文件哈希未变，旧开发包均保留。未创建 tag、发布 Release 或 push。
- Chrome 浏览器接口不可用，改用 Chrome 原生界面新建独立本地标签页；按普通链接依次进入第 1、2、3 页。当前停在黄色第 3 页，等待用户短按侧键 4 一次；预期绿色第 2 页。页面无脚本、无快捷键处理；没有通过工具执行返回动作来代替真实鼠标测试。

## 真机记录

| 项目 | 结果 |
|---|---|
| Chrome：第 3 页短按返回至第 2 页一次 | PASS（2026-10-04 用户回复 A） |
| Safari：正常历史返回且不重复 | PENDING |
| Finder：文件夹历史返回且不重复 | FAIL（2026-10-04 用户回复 B，没有反应） |

Chrome 首项用户回复 A 后，进入 Finder 单项。原生控制文档列出的可选 launch_app 在当前运行时不可用（is not a function）；此前直接绑定无窗口的 Finder 曾失败，故不重复该路径。Finder 窗口准备交由用户：进入一个子文件夹，指针放在文件列表空白处，短按侧键 4 一次。工具准备限制不是返回动作的 FAIL；Finder 实际结果继续 PENDING。

出现异常立即停在本动作，记录复现、实际、预期和日志，再定位；不推进前进动作。

## Finder 失败记录

- 复现条件：按上一项指引，在 Finder 中进入一个子文件夹，把指针放在文件列表空白处，短按配置为返回的侧键 4 一次。窗口/历史条件尚待工具核实。
- 预期：回到刚才的文件夹，仅返回一次。
- 实际：用户回复 B，没有反应。
- 初步怀疑：Finder 未处理合成的 button 3 鼠标导航事件；也需排除未进入动作执行器、权限/前台变化和窗口没有可返回历史。Chrome 已 PASS 不能代替 Finder 结果。
- 日志：执行器已有内存诊断，先读取现有日志再决定是否补充。不因 CGEvent.post success 就声称 Finder 已处理。不直接改代码，不开始前进或其他动作。

### 本次定位结果

通过开发版帮助页读取现有内存诊断：Build 24、Accessibility=true、Input Monitoring=true、event tap enabled、gestureState=idle，Balance open=0、sequenceErrors=0、postFailures=0。以下为一组记录（不保存窗口标题、路径或输入内容）：

```text
4087.262 [DEBUG] Short-click accepted cg=3 action=back
4087.263 [DEBUG] [ShortClick] button=4 action=back executor=nativeMouse-button3 frontmost=com.apple.finder stage=request
4087.263 [DEBUG] [ShortClick] button=4 action=back executor=nativeMouse-button3 frontmost=com.apple.finder stage=complete result=success reason=marked otherMouseDown/otherMouseUp pair submitted; application handling/history requires real-device acceptance
```

同一诊断快照后续还有独立物理 down/up 对应的相同提交记录；另一次实际拖动明确被记录为 Short-click suppressed reason=gesture。不能把多次物理点击的日志误写为一次点击重复执行。

工具核实 Finder 的返回按钮启用；通过 Finder 自带返回按钮成功导航，再通过前进恢复检查前位置。该检查仅验证窗口存在有效历史，不算侧键动作 PASS。

由此初步定位：短按已进入返回执行器，权限及前台应用正确，状态没有残留，窗口历史可用；Finder 对当前合成 button 3 返回事件没有产生预期导航。仍不能从 CGEvent.post 的 void 接口确认 Finder 是否收到/如何处理，故记录为当前执行路径的 Finder 兼容失败，不宣称所有版本 Finder 都不支持。

现有日志已足够定位这一层，暂不增加日志。生产代码、开发包和配置未改；Finder 已恢复检查前位置，返回动作未冻结，后续验收保持暂停。后续如修复，仅限定返回执行路径，不改短按/拖动或连续手势核心。
