# MacMouseGesture · 原生鼠标手势

当前稳定基线是 **0.1.6 / Build 12**，主要在 macOS 27 / Apple Silicon 上验证。按住任一侧键向左或向右拖动，可连续切换桌面空间；向上拖动打开调度中心；向下拖动打开应用 Exposé。全部使用交互式系统手势，没有快捷键替代。旧版 **0.1.5 / Build 7** 的本地回退归档仍保留。

这是菜单栏工具：平时只显示原生鼠标图标，需要调整时从菜单栏打开“设置”。菜单栏、设置、诊断和关于界面的普通文案已统一为简体中文；高级诊断保留技术字段。当前进度见 [项目状态](docs/project-status.md)，纵向协议与验收边界见 [纵向手势研究](docs/vertical-gesture-research.md)。

This project uses macOS system-level/private interfaces for interactive gesture injection and is intended for personal/development use. It has not been assessed for Mac App Store distribution or macOS versions beyond the tested environment. 第三方研究来源与许可边界见 [来源与许可](THIRD_PARTY_NOTICES.md)；本仓库暂不附加开源许可证。

## 使用

```sh
open build/MacMouseGesture.app
```

权限有效，且已启用应用和至少一种手势时自动开启，没有 120 秒会话限时。正常运行不常驻 Dock，也不自动弹窗口；菜单栏提供启停、设置、诊断、重新启动手势引擎和退出。关闭设置窗口仍运行，⌘Q 或菜单“退出”才完全退出。若无法在菜单栏找到图标，也可在访达再次打开同一 .app 以显示设置。

普通启动按设置中的“启用纵向手势”运行，已无需开发参数。手势页固定显示“向上拖动→调度中心、向下拖动→应用 Exposé”；验证应用 Exposé 时，前台应用应有多个窗口。原 `--vertical-poc` 仍可用于开发诊断，正常使用直接打开 `.app` 即可。

默认横向手感保持 Build 4：CG 按键 `3,4`、Invert=true、pixels/progress=600、dead zone=8、Freeze=true；纵向独立使用 300 pixels/progress，不改变横向灵敏度。两颗键都可用；同时按住只产生一段手势，最后一颗松开才结束。绑定侧键的原始点击被拦截，暂不保留单击前进/后退功能。新版首次启动默认启用纵向；旧配置若已关闭唯一的横向手势，迁移时保持停用。

设置包含“通用、手势、诊断、关于”四页。两颗侧键在 UI 中称为“侧键 1/2”，内部仍对应 CG 3/4；至少保留一颗。方向默认“反向”，仍对应原 invert=true。“灵敏度”使用对数滑块，只影响横向桌面空间切换；纵向目前使用独立固定手感。“触发距离”对应原始 deadZone=8，两轴共用。“恢复默认手势设置”只恢复手势参数，保留应用启用意图。设置继续经同一 AppConfig / ConfigStore 写入 UserDefaults，自动保存、即时应用；拖动滑块采用约 220 ms 防抖。修改会安全结束当前手势并重启输入监听，因此请在松开侧键后改参数。

“通用”页的“启用 MacMouseGesture”和菜单栏“启用鼠标手势”控制同一个 enabled 值；停用意图跨重启保存。手势中 Escape 或单次按住超过 20 秒会停止本次引擎，需点“重新启动手势引擎”；这两种保护不会改写持久化 enabled。原 CG/HID 观察后端仍保留在源码中，不占用日常设置。

Launch at Login 使用 Apple ServiceManagement 的主应用登录项，首次默认关闭，只在用户打开开关时注册。若系统要求审核，General 会显示状态并提供打开“登录项”设置的按钮。请保持应用在固定路径，勿移动已注册的 bundle。

睡眠、会话离开活动状态、屏幕休眠会取消手势并释放输入；全部恢复后按当前启用意图恢复。显示配置变化也会重启已启用的引擎。主动停止优先于这些自动恢复。真实睡眠与多屏验收状态见 [人工清单](docs/manual-test.md)。

## 权限与签名

辅助功能用于当前横向路径。`Input Monitoring=false` 不会预先阻止 CG 横向启动；输入监控用于可选 IOHID 对照。General 只显示权限状态和“打开系统设置”，不重复触发授权弹窗。首次打开若缺少辅助功能权限会自动显示 General。当前机器两项均已获准。macOS 27 中文辅助功能入口显示为“设备控制和数据访问”。

已使用本机固定证书替代 ad-hoc，保持 Bundle ID `local.macmousegesture.poc` 和 `build/MacMouseGesture.app` 路径。首次证书迁移已完成一次授权；A → B → Build 5 → Build 6 更新实测保留权限。更换证书、路径或系统策略仍需重新评估，不能保证所有未来环境都免授权。

[签名说明](docs/signing.md) 保存实际 codesign、TCC 证据和 A/B 结果。`.local-signing/` 保存本机签名材料，不提交、不分享、不随 build 清理；构建不会自动生成新证书或退回 ad-hoc。没有全局 TCC reset，也不把 reset 当常规更新步骤。

## 构建与测试

本机使用 Command Line Tools、Swift 6.4 / macOS 27 SDK。先在应用中 ⌘Q，关闭面板不足以退出。

```sh
./scripts/test.sh
./scripts/build.sh
open build/MacMouseGesture.app
```

脚本在签名与验证新 bundle 成功后才替换当前应用，旧 bundle 留在 `build/previous.*`。运行中构建会明确拒绝覆盖。固定架构 arm64，entitlements 为空。普通终端可使用本机钥匙串；受限开发沙箱可能需要正常用户权限上下文，具体见签名文档。

目前 **58 项自动检查通过**，包含 Build 7 原有 45 项。新增纵向锁轴、双向动作固定、反拖、停顿/速度、取消一次、横纵隔离、配置迁移和纵向 HID 正负进度四阶段回读；也检查了中文状态和“恢复默认手势设置”。跨进程 UserDefaults 检查使用随机测试域并清理，不能在禁止偏好写入的沙箱中据失败断言应用不保存。测试不模拟真实鼠标；Build 9/10 的两个 POC 与 Build 11 普通模式已由用户真人验证。Build 12 仅调整界面说明与版本，没有更改手势投递算法。

本机 Swift 新 driver 在中文 TMPDIR 下有兼容问题，脚本继续使用同一工具链 legacy driver，编译会提示 deprecated。本机验收入口为上述脚本；Package.swift 描述的最低系统也已统一为 27.0。

## 诊断与回退

Diagnostics 首先显示系统、输入状态和手势统计；Advanced Diagnostics 默认折叠，保留原始输入、手势计数、最后侧键时间、Tap 恢复、CPU/RSS 和最近日志。可复制或保存完整诊断快照，Restart 单独放在下方。始末平衡应在松开按键后查看：`started == ended + cancelled`、`open=0`、`sequenceErrors=0`、`postFailures=0`。

系统禁用 Tap 时，先取消当前手势、释放拦截，再有限次尝试重新启用；成功后须先松开原来按住的侧键。连续失败会明确停止，不静默循环。Tap 显示 enabled 不能证明其他鼠标工具没有在上游拦截侧键。

再次失效时，先复制诊断，再点重新开启，保留故障前后的证据。完整清单在 [manual-test.md](docs/manual-test.md)。

原始 **0.1.3 / Build 4 — First confirmed working horizontal gesture baseline** 的源码、原签名应用、校验和位于 `baselines/build4/`；Build 6、Build 7 分别保存在 `baselines/build6/` 和 `baselines/build7/`，不随正常 build 改写。回退时先退出应用，再按归档恢复；跨证书方案回退可能需重新授权。

## 代码结构

- `Sources/GestureCore/`：保留 Build 4 的状态机、锁轴、进度与速度。
- `Sources/SystemGestureBridge/`：保留 Build 4 的 HID bridge 与私有 API 边界。
- `Sources/MouseGesturePOC/`：AppKit 菜单栏与窗口、SwiftUI 设置页、输入、串行调度、配置、诊断与性能采样。
- `Tests/CoreRegression/`：合成输入、配置及生命周期检查。
- `scripts/`：本机构建、签名与更新实验。
- `docs/`：当前状态、历史研究、签名及验收记录。

Build 7 的菜单栏、双侧键横向手势、设置即时生效与重开持久化已由用户验收。Build 8 的中文界面已在本机逐页检查布局；首次上拖无反应的快照显示真实上拖 `dy` 为负，原假设导致纵向投递 0 次。Build 9 修正方向后，用户确认调度中心的跟手、停顿、回退、回弹与快速上甩；现场诊断 `61 = 53 + 8`，无 open、序列错误或投递失败。Build 10 用户同样确认应用 Exposé 的完整交互与双键横向四方向，最终诊断 `87 = 63 + 24`，无 open、序列错误或投递失败。Build 11 普通模式下，用户确认两颗实体侧键均可用，四方向正常；快照显示开始与结束/取消各 244 次、两键 DOWN 计数 29/216、无 open、投递失败或序列错误。外接 4K/120 Hz 屏幕的 macOS 全屏窗口中，下拖应用 Exposé 偶尔有不到半秒的松手收尾延迟；用户发现触控板有时也会这样，且不影响使用，因此保留已验证的手势参数。来源与许可见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
