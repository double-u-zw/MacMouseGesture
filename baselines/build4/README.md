# MacMouseGesture — macOS 27 横向手势 POC

原生 Swift / AppKit / Objective-C 实验，目标是把普通鼠标侧键拖动变成连续 Spaces 手势。当前交付范围：**Phase 0 Research + Phase 1 输入探测 + Phase 2 横向手势 POC**。2026-09-29，用户确认 Build 4 两个侧键与当前方向“可以正常使用了”，横向基本功能验收通过；本版本支持自动启用和持续运行。长期稳定性与完整边界验收尚未完成。

继续开发前请查看 [项目总结与后续计划](docs/project-status.md)，其中集中记录当前基线、验收证据、未完成项和建议优先级。

## 运行

```sh
open build/MacMouseGesture.app
```

Build 4 打开应用后会自动开启横向手势；缺少辅助功能权限时等待，授权生效后自动开启。横向模式持续运行，不再每 120 秒关闭。关闭面板后应用继续运行，点击 Dock 图标可以重新打开面板；按 ⌘Q 完全退出。没有登录启动项或后台 helper，配置只保留当前进程内。文件、构建缓存、临时目录都在本项目中；不安装到 `/Applications`。

第一次只验证两个小项目：

1. 退出其他鼠标映射工具。在实验面板点击“请求辅助功能”，到系统设置开启 **MacMouseGesture.app** 权限，再回到面板。本机 macOS 27 中文页面名为“设备控制和数据访问”。若权限仍显示 Missing，退出重开。
2. 点击“1. 观察 CG 输入”，分别按一下两个侧键，移动鼠标。记录是否看到 `Button4 DOWN/UP cg=3`、`Button5 DOWN/UP cg=4` 和合并的 dx/dy。此模式不会吞事件，侧键原本的 Back/Forward 仍可能生效；在空白桌面测试。监听若未获准，再通过面板授予输入监控。
3. 准备至少两个 Space（若已有则不用新增）。默认 `CG buttons=3,4`，两个侧键都可用；如果刚使用输入观察模式，点击“开启 / 重新应用横向手势”。分别按住两个侧键左右慢拖，中途停一下再松开。反馈：**两个键是否都能带动桌面、能否停在中途、松手是否正常完成或回弹**。

这不是 Ctrl+方向键模拟，程序当前不发送快捷键。垂直拖动只锁轴并忽略，留到横向验收通过后实现。横向手势没有会话限时；CG / HID 输入观察仍在 120 秒后停止。一次连续按住最多 20 秒，达到限时或输入后端异常会停止并释放拦截，修复后通过“开启 / 重新应用横向手势”恢复。手势期间 Escape、面板“停止”可停用，⌘Q 退出应用。

睡眠、屏幕休眠、会话退出活动状态时会先取消手势并释放输入，全部恢复且权限有效后自动重启横向模式。手动点击“停止”或进入输入观察模式后，自动启动被取消；恢复系统会话不会覆盖这个选择。主动停止后需点“开启 / 重新应用横向手势”，或者重新启动应用。

`Accessibility: true` 后可使用横向手势。当前实现不会因 `Input Monitoring: false` 预先阻止横向启动；只有实际 CGEventTap 创建失败或进行 HID 对照时，再处理对应权限。状态中的 `Continuous — no session timeout` 表示正在持续运行；`Stopped` 会显示停止原因。

如果编号不对，改 `CG buttons`（每个编号允许 2…31，多个用英文逗号分隔）。如两个键在 CG 中相同，做“对照 HID 输入”，先授予输入监控，复制诊断中 HID usage 与 vendor/product。HID 模式同样不吞事件。

日志中的 `Button4 cg=3 / Button5 cg=4` 是程序按 CG 编号生成的名称，不保证与鼠标外壳、驱动或使用者称呼的 4/5 键一致。默认两个侧键都触发相同的横向手势；两键同时按住时，只产生一段手势，松开其中一个会继续，最后一个松开才结束。两个绑定键的原始按下/松开在手势模式中都会被拦截；暂不保留它们的单击前进/后退功能。

只想启用一个侧键时可填 `3` 或 `4`。更改按键、方向、灵敏度后都需要重新点击启动按钮才能应用；当前 POC 不保存退出后的配置。

Build 3 默认开启 `Invert horizontal`，保留用户在本机确认正确的方向；其他鼠标方向相反时可取消勾选。拖动幅度不足可把 `pixels/progress` 从 600 调小。这个 progress 尚未按显示器/Space 数量标定。Freeze 默认开启的是实验性事件拦截；可取消勾选比较，**并未宣称已经优于正常光标模式**。

## 构建与检查

已在 macOS 27.0 (26A428)、arm64、Swift 6.4 / macOS 27 SDK 构建。不需要完整 Xcode 或第三方包。

```sh
./scripts/build.sh
./scripts/test.sh
build/MacMouseGesture.app/Contents/MacOS/MacMouseGesture --probe
```

构建 `.app` 使用 ad-hoc 签名，未公证。每次重新签名后 macOS 可能要求重新授权；不要在应用运行时覆盖 bundle。退出后再运行 build.sh。

**辅助功能开关开启但仍显示 false：** 本机已发现旧构建签名的授权不匹配新构建（tccd 报 code requirement mismatch）。先退出 POC，在“隐私与安全性 → 辅助功能”中选中旧的 MacMouseGesture POC 点减号移除；点加号，按 ⌘⇧G，输入当前项目中 `build/MacMouseGesture.app` 的完整路径，重新添加并开启，再启动应用。不要只重复打开旧条目的开关。0.1.1 / build 2 在诊断中显示实际 bundle 路径；build.sh 也会拒绝覆盖正在运行的应用。

目前仍使用 ad-hoc 签名，不保证未来代码更新继承授权。先完成该固定构建的手势验收；后续长期版本再考虑稳定的证书签名流程。Apple 对此机制的说明见 [TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)。

本机 Swift 6.4 新 driver / SwiftPM 在中文项目路径作为 TMPDIR 时发生 SIGTRAP。脚本使用同一工具链自带 legacy driver 并直接编译，保留项目内临时文件；会打印 deprecated 提示。Package.swift 用于源码结构/其他环境，**本机验证入口是 build.sh / test.sh，而不是 swift test**。测试采用无依赖可执行断言，Command Line Tools 无需 XCTest。

`--probe` 只检查权限、符号、构造和回读事件，**不 post 任何手势**。测试中的 8,000 Hz / 100 次循环是合成状态机输入，不代表物理鼠标或 Dock 通过验收。

## 结构

```text
Sources/GestureCore/          状态机、锁轴、progress、velocity
Sources/SystemGestureBridge/ 唯一私有 API 边界，运行时加载和 HID 事件封装
Sources/MouseGesturePOC/      CG / HID 输入、串行引擎、内存诊断、实验面板
Tests/CoreRegression/        可执行回归检查
scripts/                     项目内构建、签名和测试
docs/research.md             版本核对、技术证据、权限与未验证项
docs/validation.md           本机验证记录、阶段验收与下一步
references/                  只读研究材料；不编译、不打包
build/MacMouseGesture.app    可运行的个人实验版本
```

当前尚未实现 Mission Control / App Exposé、正式菜单栏/设置、快捷键 fallback、开机启动。probe 不可用会明确停止，不把快捷键当成交互式成功。确认横向 POC 成功以后再推进 Phase 3–5。

详见 [研究结论](docs/research.md)、[验证记录](docs/validation.md)、[来源与许可](THIRD_PARTY_NOTICES.md)。
