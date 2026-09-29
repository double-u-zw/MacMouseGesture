# 首次使用、最小权限、诊断与隐私审计

日期：2026-09-29。依据实际 Sources 的状态路径模拟陌生用户流程；**没有通过重置本机 TCC 来伪造全新安装测试**。未修改 UI 或手势。

## 从下载到第一次成功手势

| 环节 | 当前实现 / 证据 | 缺口与未来期望 | 优先级 |
|---|---|---|---|
| 下载 | 私有仓库/本地构建，无正式下载件 | 发布渠道、系统/鼠标要求、发行哈希和支持入口 | P1 |
| 打开 DMG | 未构建正式 DMG | 签名、公证及拖放引导；禁止把 Gatekeeper 绕过作为安装流程 | P0 分发管线 |
| 拖到 Applications | 当前 app 在开发 build 目录运行 | 路径锁需要父目录写权限；普通用户和只读卷可能启动即退 | **P0** |
| 启动、Gatekeeper | 本地自签名信任；实验 spctl rejected | Developer ID、HR、安全时间戳、公证与真实下载链验收 | **P0** |
| 理解产品 | 通用页一句介绍；已授权启动只显示菜单栏 | 说明按侧键拖动、四方向、松手、反向、如何停用，以及侧键普通点击被占用 | P1 |
| 申请权限 | 缺 AX 显示通用页与“打开系统设置”按钮；没有自动弹授权请求 | 精确说明授权对象/路径、用途与拒绝后状态；深链接失效有手工路径 | P1 |
| 识别鼠标 | UI 只显示侧键1/2，对应 CG 3/4 | 没有首次侧键测试/编号学习；不支持的按钮不应静默失败 | P1 |
| 验证手势 | 统计与高级日志可用 | 提供明确的首次成功反馈和 backend 不可用说明 | P1 |
| 完成与日常 | 菜单栏、设置保存、关闭窗口后台运行已具备 | 退出、卸载、升级身份/权限迁移和登录项验证 | P1/P2 |

额外启动风险：`main.swift:38–44` 使用 .app 父目录的 `poc.lock`。两个不同目录副本的锁相互独立，可能同时吞输入；某个副本更新/签名迁移也会使权限对象难辨。未来单实例策略必须与安装位置解耦；本轮未修复。

## 每项权限是否真正必要

| 权限 | 当前目的和调用 | 核心需要？ | 拒绝/撤销后的实际行为 | 下一步 |
|---|---|---|---|---|
| Accessibility | AXIsProcessTrusted 检查；defaultTap 捕获并抑制侧键/移动、向系统投递动作 | 当前实现将其设为硬门槛；有用途依据 | 未授权不自动启用，显示“需要授权”；引擎运行时检测丢失后停止并取消 | 保留；说明全局控制能力和仅处理手势的范围 |
| Input Monitoring | CGPreflightListenEventAccess；可选 IOHIDManager 鼠标观察、vendor/product、拔出通知 | **源码没有把它作为四方向核心启动门槛**；UI 已写“可选” | 没有该权限时不启动 HID observer；CG 路径仍尝试工作，拔出即时检测不能保证；HID open 失败不应停止主 CG 手势 | 用干净用户 AX=true、Listen=false 真实验证后决定是否从普通流程移除可选观察 |
| Automation / Screen Recording / Full Disk Access | 未发现请求或相关功能路径 | 否 | 不适用 | 不应为产品化额外申请 |

Apple 依据：[CGEventTap](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:))、[AXUIElement](https://developer.apple.com/documentation/applicationservices/axuielement_h)、[监听权限预检查](https://developer.apple.com/documentation/coregraphics/cgpreflightlisteneventaccess())、[IOHIDManager](https://developer.apple.com/documentation/iokit/iohidmanager_h)。公开 API 身份不等于在所有 TCC 组合下可用。tapCreate 文档对 HID tap 有权限/位置限制描述；现有普通用户成功的事实仍须与实际目标系统逐项验证，不能把文档中历史 root 说明变成让产品申请 root 的理由。

最小权限验收（未来 P1）：新用户四组合 AX/Listen 均 false、仅 AX、仅 Listen、均 true；检查创建 tap、捕获、吞事件、四方向、拔插、撤销权限和重启。当前 probe 两项均 true，所以**不能从本轮实验得出“所有机器只需 AX”**。不在稳定机器清空权限做实验。

键盘说明：手势模式的 tap mask 包含全局 `.keyDown`，仅在按住侧键时读 keycode 是否 53（Escape），不吞键盘事件，不读 Unicode 文本，不写按键内容日志。可说“未存储或上传键盘输入内容”；不能说“完全不接触键盘事件”。未来可评估不用全局键盘监听的取消设计，本轮保留已验收行为。

## 新用户失败场景

| 场景 | 现在用户能看到什么 | 未来应该看到什么 / 验收 |
|---|---|---|
| 没有 Accessibility | 通用页“需要授权”、设置按钮，菜单状态相应变化 | 为什么需要、如何添加当前 .app、拒绝后可保留停用；中文系统页名可变，提供图文版本差异 |
| 授权后状态未刷新 | 每秒轮询 AX/Listen；有待启动意图时自动启动；创建失败后可能只显示“手势引擎异常” | 明确刷新/重启路径，区分等待、被拒绝、旧 app 条目、签名身份改变；不要求用户盲目 reset |
| 没有侧键鼠标 | 仍可能显示运行中，计数不增加 | 清楚检测输入并告知设备不满足要求；不要把运行中等同于鼠标适配成功 |
| 侧键编号不同 / 驱动映射 | UI 只允许 3/4；ConfigStore 可校验 2…31，但普通 UI 没有任意编号入口 | 可理解的侧键验证和未来映射方案；不承诺两个坍缩编号可区分 |
| 横向 backend 不支持 | 引擎拒绝启动；总体“手势引擎异常”；高级日志含符号/回读原因 | 独立 backend unsupported 信息，明确系统版本与下一步，不自动改用离散动作 |
| 仅纵向 probe 失败 | 可能继续横向并在日志记录；总体运行中可能掩盖纵向已关闭 | P1：按能力显示横向/纵向可用性，不能整个后端一律写“正常” |
| macOS 未知版本 | <27 被最低系统版本/桥接 guard 拦下；更高版本只凭 availability + probe | 公布已测矩阵；未测试版本提示和明确失败保护，不默认所有未来版本支持 |
| Gatekeeper 阻止 | app 内 UI 无法启动来解释 | 下载页说明 Developer ID、公证与正常安装；不引导关闭保护 |
| 安装目录不可写 | NSLog 一句 already running or directory cannot be locked，然后退出 | 用户可理解的安装路径错误；修正锁架构，而不是叫用户 sudo 启动 |

## 诊断能力与盲区

Copy Diagnostics / Save Diagnostics 已实现，后者由用户通过 NSSavePanel 选择位置；内存日志上限300行。报告包含 OS/版本/build、权限、backend probe、配置、手势 began/changed/ended/cancelled/open、postFailures、sequenceErrors、输入按钮计数、tap 恢复、RSS/CPU 和最近轴/动作。

P1：计数是桥接调用成功，不是 Dock delivery acknowledgment；系统版本字符串有 build，但架构硬编码 arm64，GUI 显示 Apple Silicon；未来 universal 时必须改成实际架构。P1：日志中仍有 “Build 4 horizontal baseline retained”，对陌生用户容易误导；backend“正常”也应区分 probe 与真实能力。P2：没有自动崩溃收集、符号化支持流程或匿名导出级别，未来设计用户主动提交的最小报告，不能默认上传 macOS crash report。

## 隐私逐项检查

| 数据 | 当前发现 | 风险 / 处置 |
|---|---|---|
| 用户名、绝对路径、个人目录/文件夹名 | **存在**：main.swift:257 `Bundle.main.bundleURL.path` 原样进入复制/保存/高级诊断；安装在用户目录会含用户名和上级目录名 | **P0**：公开前默认删除/归一化，提供分享预览；本轮不改源码、不发送报告到服务器 |
| 鼠标唯一序列号 | 未见读取；仅 HID vendor/product 和 usage | vendor/product 通常是型号类信息，不是唯一设备序列；仍需在诊断说明中披露 |
| 窗口标题、应用内容、前台应用、浏览器 URL/历史 | 所有 Sources 未发现相应读取或日志路径 | 目前不收集；不能据此保证 OS 自己生成的崩溃报告也不含这些数据 |
| 键盘文本 / 按键历史 | 不存/不上传；只在侧键按住时检查 Escape keycode | 不宣传完全不监听键盘；见上面的权限解释 |
| 鼠标坐标/活动 | 有相对 dx/dy、按钮时序与计数、手势进度、uptime；没读绝对屏幕位置 | 诊断仍能描述操作活动，应限量、用户主动导出 |
| 错误字符串 | 登录项失败的 localizedDescription 写入日志，未来内容可能包含环境信息；保存失败提示在 UI | P1：对自由文本错误做脱敏/白名单审查，不能只删 Bundle 一行就宣称永远无隐私 |
| 账户、云、遥测、自动上传 | 未发现账户模型、URLSession/网络请求、遥测 SDK/外部包；仅打开本地系统设置 URL | 支持当前“无账户、无云、无默认遥测”的技术描述；未做网络抓包级证明 |
| 持久化 | UserDefaults 保存手势配置；内存日志退出消失；用户主动保存的诊断保留 | 提供明确卸载/删除说明，不自动上传 |

未来隐私目标：No account / No cloud / No telemetry by default / No keystroke collection / No browsing history / No content collection。键盘事件处理和诊断路径问题必须准确披露；不能把这一目标直接当已完成的绝对宣传。复制到系统剪贴板本身是用户主动本地导出，后续剪贴板共享功能不受本 app 控制，不将其误报为本 app 云上传。

[卸载与系统权限清理](distribution-audit.md)只建议用户管理自身数据及系统设置，不改 TCC 数据库。
