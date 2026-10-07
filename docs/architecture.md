# 当前技术结构

仓库维护一个正式 App 实现。当前开发基线为 `0.2.0-beta.1-dev / Build 33`；公开 Build 17 的功能和验收范围与开发版分开记录，见[兼容性矩阵](compatibility-matrix.md)。构建入口见[贡献指南](../CONTRIBUTING.md)。

## 输入与执行链

`SwiftUI → AppViewModel / ConfigStore → CGEventTap → InputMailbox → GestureEngine → GestureCore / 触发协调器 → 动作执行器或 SystemGestureBridge`

- `GestureMachine`负责死区、锁轴、横向进度、速度和结束；`VerticalGestureTracker`负责纵向进度与单次动作锁定。输入边沿/相邻移动进入有界队列，串行引擎按约 120Hz 生成连续帧。
- `SystemGestureBridge`集中原生连续手势的私有接口。它接收绝对 progress、velocity 和 phase，不识别鼠标按钮或重算阈值；详细契约与来源见[桥接来源记录](system-gesture-provenance.md)。
- `IOHIDManager`是可选非独占鼠标观察路径，用于设备事件与兼容诊断；主要手势输入来自 CGEventTap。
- 服务停止、Escape、权限丢失、tap 中断、设备移除及休眠/会话变化走既有取消清理路径。输入恢复有次数上限，并尊重用户停用和挂起意图。

## 映射与持久化

`MouseInput.button(number)`保存一基用户编号；`MouseButtonIdentifier`是原始 CG 编号与 UI 名称的转换边界。CG raw 2…31 对应中键至鼠标按钮 32，左/右主键 0/1 禁止有效映射。映射全局生效，没有按应用或设备的 Profile。

`MouseMapping`保存 UUID、input、trigger、action、isEnabled。`MouseMappingStore`用 Input+Trigger（包含修饰键）保证唯一条目；禁用条目仍占用唯一键。UI 主线程编辑值快照，引擎串行队列解析不可变快照，一次输入最多选中一个动作。

`ConfigStore`在本地 UserDefaults 的 `gesture.configuration.v1` 字典中原子保存手势字段和 `mouseMappingsV1` JSON Data：

| 文档版本 | 表达能力 |
|---|---|
| v1 | 普通短按与拖动 |
| v2 | 修饰键组合 |
| v3 | 长按 |
| v4 | 按住按钮并滚动 |

写入采用配置所需的最低版本，新 reader 兼容 v1–v4。有效空文档代表用户已删除映射，不重新导入旧动作；损坏或未来文档停止解析，不回退旧短按。未知动作安全降为无操作，未知触发方式不能冒充短按。后续保存不是未来格式无损编辑的承诺。

旧侧键动作通过兼容访问器和降级字段保留，不是第二套配置状态。首次实际编辑拖动映射时才设置 `dragMappingsManaged`；只打开界面不批量迁移。 `LegacyDragSettingsAdapter`把启用方向投影为原引擎按钮/轴配置；`LegacyDragDelivery`在原机器 began 时决定是否投递整个序列，保持开始与终止配对，反向仍属于同一次手势。拖动动作固定，修饰键拖动不支持。

## 录制与触发仲裁

鼠标录制暂时暂停普通服务，只捕获一个合法按钮 down 及当时修饰键。录制层与普通 mailbox 共享释放隔离；已吞掉 down 的 up 在取消、Escape 或关闭弹窗后仍被消费，避免落入现有映射。录制结果先进入草稿，外层保存才写配置。失焦、挂起、撤权和退出结束录制。

修饰键在物理 down 冻结，不受之后松开/增加键影响。Short/Long 优先精确组合，不存在精确条目时才回退普通项；精确条目禁用或无操作时不回退，也不匹配修饰键子集。Wheel 仅匹配完整冻结组合，没有普通项回退。

`LongPressCoordinator`维护每次按压的 pending/drag/longPress/wheel/cancelled 归属：

- 短按提前松开立即执行，不新增 500ms 等待；越过原拖动阈值后粘性取消，回起点不能恢复点击。
- 长按默认 500ms 执行一次，generation 隔离旧回调。释放已到 deadline 而 timer 尚未派发时补偿一次长按；取消不恢复短按。拖动先识别取消长按，长按先执行将该按钮退出拖动驱动集合。
- Wheel 首次产生有效 logical step 后锁定归属，释放不再触发短/长按。其他仍按下的按钮可以继续驱动拖动。无 owner 时选择最近按下的 eligible 按钮，首次成功后固定 owner，直到该按钮释放。

滚轮唯一方向转换使用 NSEvent 的 `isDirectionInvertedFromDevice` 还原物理上下，不另读全局偏好。离散输入按 lines 累计，连续输入默认 10points 一步；最小间隔 40ms，闲置 250ms 清残量。每个原始事件最多执行一步，过大/过快的完整步直接丢弃，不排队补发；方向/单位切换清残量，momentum 不建立新归属或重复动作。

`WheelInputHandoff`先在同一引擎队列排空既有输入，再决定消费；预算 8ms，超时撤销并透传，不能迟到执行。已命中 wheel 的垂直事件整体消费；纯水平/无有效方向透传，混合事件不拆分重发。

## 动作与界面

- 调度中心/应用 Exposé短按复用纵向后端，在约 0.2 秒/120Hz 发送渐进 one-shot；新物理输入优先，异步动作互斥并可取消。
- 最小化通过公开 AX focused/main window、可写 AXMinimized 及执行前焦点重查。全屏先用目标明确暴露的运行时 AXFullScreen 属性，否则用公开全屏按钮/AXPress；不在失败后重试另一后端或键盘 fallback。
- 返回发送带进程标记的 button3 down/up；监听入口只放行本进程合成事件，防递归。兼容性目前限于已验证 Chrome。
- 显示桌面使用系统快捷键，缺省 F11 保留 secondaryFn 标记；快捷键和媒体动作依赖系统/目标应用。
- 打开访达显示个人主目录；新建文件夹只向前台 Finder PID 发送原生命令，在当前目录创建并命名。锁屏复用系统快捷键。这些新增动作的真机状态见兼容矩阵。

主表三列为“鼠标输入 / 操作方式 / 执行动作”。普通动作选择直接保存；添加/编辑使用草稿，取消不写。四方向仅作展示分组，不合并底层记录；参数恢复不覆盖映射。整组停用的方向恢复和删除撤销只保存在当前会话，重启后需明确选择方向。帮助、权限、运行状态、关于位于次级设置入口。

## 产品身份与诊断

永久 Bundle ID 为 `io.github.double-u-zw.macmousegesture`。旧域 `local.macmousegesture.poc` 只导入八个实际手势字段和 onboardingCompleted 的缺失值；新值优先，旧域保留，迁移标记最后写入。

单实例继续使用 `~/Library/Application Support/local.macmousegesture.poc/instance.lock` 作为有意保留的兼容命名空间。先持 flock 再初始化模型/引擎，进程结束由内核释放；运行中不得 unlink 或迁移 inode。登录启动由 SMAppService.mainApp 状态驱动，不是偏好键；旧版升级需 old-off/new-on。

日志最多 300 行，集中脱敏；UI、复制和导出使用同一报告。动作诊断记录应用标识、阶段和结果，不记录窗口标题/URL/文档内容。API 接受请求或提交完成不等于系统动画成功；测试回读与实际鼠标验收必须分别记录。见[隐私说明](../PRIVACY.md)。
