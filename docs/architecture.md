# 当前架构

`SwiftUI → AppViewModel / ConfigStore → CGEventTap → InputMailbox → GestureEngine → GestureCore / 触发协调器 → 动作执行器或 SystemGestureBridge`

## 模块职责

| 模块 | 职责 |
|---|---|
| SwiftUI / AppViewModel | 三列映射界面、编辑草稿、权限状态、首次设置及菜单栏操作。 |
| ConfigStore / MouseMappingStore | 本地配置、映射唯一性、持久化和不可变运行快照。 |
| MouseInput / InputMailbox | 捕获按钮、移动及滚轮，保留输入边沿并合并相邻移动；IOHIDManager 提供可选非独占设备观察。 |
| MouseInputRecorder | 暂停普通服务，录制按钮与修饰键；共享释放隔离，取消后仍消费已截获按钮的松开事件。 |
| GestureEngine / GestureCore | 串行调度约 120 Hz 连续帧；GestureMachine 处理死区、锁轴、横向进度和速度，VerticalGestureTracker 处理纵向动作。 |
| LongPressCoordinator | 按压归属、长按计时及 Short/Long/Drag/Wheel 仲裁；修饰键和动作在按钮按下时冻结。 |
| MouseButtonActionExecutor | 分发系统、窗口、导航、媒体和键盘动作；具体执行器负责能力检查、焦点复查与取消。 |
| SystemGestureBridge | 原生连续系统手势的非公开接口边界，接收 progress、velocity 和 phase；见[接口与来源](system-gesture-provenance.md)。 |

## 配置与匹配

鼠标输入保存一基用户编号，CG raw 2…31 对应中键至鼠标按钮 32；左、右主键禁止有效映射。映射全局生效。`MouseMapping` 包含 UUID、input、trigger、action、isEnabled；Input+Trigger（含修饰键）唯一，禁用条目仍占用唯一键。

`ConfigStore` 在 UserDefaults 的 `gesture.configuration.v1` 字典中保存手势字段及 `mouseMappingsV1` JSON Data。格式支持 v1 基础映射、v2 修饰键、v3 长按、v4 滚轮，写入采用配置所需的最低版本。有效空文档不重新导入旧动作；损坏或未来文档停止解析，未知动作降为无操作。

Short/Long 优先精确修饰键组合，缺少精确条目时才回退普通项；禁用或无操作的精确条目阻止回退。Wheel 只匹配完整组合，不回退普通项。`LegacyDragSettingsAdapter` 将映射投影为引擎按钮/轴配置；`LegacyDragDelivery` 在 began 时决定整段序列是否投递，保持终止配对。拖动动作固定，修饰键拖动不支持。

## 输入生命周期

短按提前松开立即执行；越过拖动阈值后不能恢复点击资格。长按默认 500 ms 执行一次，generation 隔离旧回调，到期释放补偿尚未派发的计时器。Drag、Long 或 Wheel 获得归属后，释放不再执行短按；其他仍按下的按钮可以继续驱动拖动。

滚轮通过 NSEvent 的 `isDirectionInvertedFromDevice` 还原物理方向。离散输入按 lines 累计，连续输入默认 10 points 一步；间隔至少 40 ms，闲置 250 ms 清残量，每个事件最多一步，不排队补发。`WheelInputHandoff` 在引擎队列排空先前输入并决定消费，8 ms 超时撤销并透传，不能迟到执行。

停止、Escape、权限丢失、tap 中断、设备移除及休眠/会话变化取消待定动作并释放输入。恢复有次数上限，尊重用户停用与挂起意图。

## 动作与运行状态

调度中心/应用 Exposé 短按复用纵向后端发送渐进单次序列。最小化使用 AX 窗口属性；全屏使用目标暴露的运行时属性或全屏按钮。返回发送带进程标记的配对侧键事件，监听入口放行自己的合成事件以防递归。打开访达使用 NSWorkspace；新建文件夹只向前台 Finder 进程发送命令。键盘及媒体动作由系统和目标应用处理。

添加、编辑弹窗保存草稿后写配置，取消不写；主表动作选择直接保存。四方向只作展示分组，参数重置不覆盖映射；整组方向恢复和删除撤销保存在当前会话。

Bundle ID 为 `io.github.double-u-zw.macmousegesture`。`ProductIdentity` 仅导入旧偏好域的允许字段缺失值，保留已有值。`SingleInstance` 在初始化引擎前持有 `~/Library/Application Support/local.macmousegesture.poc/instance.lock` 的 flock；进程结束释放，运行中不得删除或迁移锁文件。登录启动由 `SMAppService.mainApp` 状态驱动。

诊断使用最多 300 行的脱敏内存日志，UI、复制与导出共用报告。API 接受请求或事件提交成功没有目标应用响应确认。
