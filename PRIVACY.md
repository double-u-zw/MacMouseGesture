# 隐私说明

适用于 0.2.0-beta.1，依据当前源码核对，不包含未来计划中的功能。

- 无需账户，不访问 Apple ID，无云同步。
- 没有网络上传、analytics、crash upload、telemetry 或自动日志上传。
- 设置通过 UserDefaults 保存在本机。用户级运行锁保存在用户资源库 Application Support 中。
- 运行中会生成最多 300 行的内存日志，以及鼠标事件/手势/性能计数；退出后内存日志消失。并非点击导出后才生成日志。
- 仅当用户主动点击“复制诊断信息”或“保存诊断快照”才导出报告；保存路径由用户选择。报告和错误消息经过集中脱敏，安装位置只显示 Applications / 非 Applications。自由文本中包含绝对路径的行会保守删去路径及后续内容。
- 报告可能含版本、Build、Git Commit、macOS、架构、权限状态、设置、侧键/拖动/手势计数、性能数据、HID 鼠标 vendor/product 数字编号及错误状态。编号不是序列号。
- “高级诊断”可预览即将导出的内容；请在提交 Issue 前检查，按需删去不希望分享的内容。

## Not collected

窗口标题、窗口内容、网页 URL/网页内容、用户文档或私人文件名、剪贴板内容、Apple ID、鼠标序列号：**Not collected**。程序只读写自身设置/资源与用户主动保存的诊断文件，不扫描用户文件。

键盘输入内容：**Not collected / not recorded**。但手势运行时的事件监听包含 keyDown；按住配置侧键期间，仅检查 Escape 的键码以取消手势，不转换文字、不保存键码、始终传递键盘输入。不能把这一点描述为“完全不接触键盘事件”。

剪贴板只在用户点击复制诊断时写入，不读取已有内容。系统可能独立生成 macOS 崩溃报告，本应用没有自动收集或上传机制。

## 源码依据

`Diagnostics.swift`（有界日志）、`DiagnosticRedactor.swift`（脱敏）、`main.swift`（报告/导出）、`MouseInput.swift`（鼠标计数与 Escape）、`HIDInputBackend.swift`（鼠标匹配与 vendor/product）、`AppConfig.swift`（设置）、`SingleInstance.swift`（用户级锁）。没有新增远程服务。
