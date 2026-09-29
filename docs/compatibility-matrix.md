# 兼容性矩阵与承诺边界

日期：2026-09-29；基线 0.1.6 / Build 12。这是已有用户验收记录 + 本轮只读机器信息 + 隔离 probe 的汇总，不是假装本轮把所有鼠标/屏幕重新测试一遍。

状态：**Verified** = 指定环境及指定行为有实际记录；**Partial** = 只测到部分或证据粒度不足；**Untested** = 未验收；**Unsupported** = 当前构建明确不能满足。Verified 不延伸到同系列全部机器。

## 已有证据

| 环境 / 场景 | 状态 | 证据与精确边界 |
|---|---|---|
| macOS 27.0 / 26A428 | Verified | 本轮 sw_vers，与 docs/project-status.md、research.md 的既有环境一致；不是所有 27.x |
| 当前 Apple Silicon 机器 | Verified | sysctl：Mac17,3、Apple M5；uname -m=arm64；本轮没有读取硬件序列号。历史人工验收在当前用户机器上 |
| 两颗实体侧键四方向 | Verified | project-status.md 的 Phase 3–5 用户确认；build/vertical-phase5-build11-two-physical-buttons.txt 记录两个 CG 按钮计数；Build 12 仅说明文案和版本修改 |
| 两只已实测鼠标 | Partial | 本轮任务说明称两只已测；现有可追溯记录明确“两颗实体侧键”，未找到逐鼠标型号、连接方式、每只四方向验收。保留用户报告，不能把“两颗键”充当“两种型号”证据 |
| 内建屏四方向连续交互 | Verified | 历史 Phase 1/2/3–5 真人记录：停2秒、反向收回、短甩、松手回弹；未记录刷新率和所有显示设置 |
| 外接 4K / 120 Hz 交互 | Partial | 用户报告日常可用，特定全屏 App Exposé 松手偶有不足半秒收尾延迟，原生触控板也可能出现；不等于所有多屏组合通过 |
| 100+ 真实横向手势 | Verified（历史 Build 6 限定） | 141=139 ended+2 cancelled、open0 等记录；不能扩写成 Build12 全日/全方向压力测试 |
| 本轮自动回归 | Verified | 独立编译运行 58 checks / 0 failures；合成输入不是物理 8kHz 鼠标证明 |
| HR 下横纵符号/四phase构造回读 | Partial | 0x10000(runtime)、无 entitlement 例外，--probe PASS；没有真实投递/动画验证 |
| 正式 Developer ID/公证/下载/Gatekeeper | Untested | 本轮实验自签名 spctl rejected；没有正式发布链，不能标支持 |
| 登录启动 | Untested（真人首次注册） | SMAppService 已实现，历史记录默认 OFF；不自动替用户打开 |
| 睡眠唤醒、锁屏、用户会话切换、拔插 | Partial | 有实现和部分合成恢复检查；完整硬件现场验收欠缺 |
| 全天运行/长期内存/严格空闲 CPU | Untested（完整验收） | 历史数据不呈线性泄漏不能证明长期无泄漏；严格无输入 CPU 验收未完成 |

## 架构、系统版本与私有 ABI

| 目标 | 状态 | 代码/产物事实与未来工作 |
|---|---|---|
| arm64 当前构建 | Verified（本机） | scripts/toolchain.sh 显式 `-target arm64-apple-macosx27.0`；实际 Mach-O thin arm64 |
| M1/M2/M3/M4 | Untested | 指令集兼容假设不能当设备验收；按下表选样本 |
| 其他 M5 机器 | Untested | 当前一个 Mac17,3 不能代表全系列 |
| Intel x86_64 | Unsupported（当前交付包）；源码移植 Untested | 当前没有 x86_64 slice；SDK/部署目标可用性与设备 OS 支持需核实。C/Swift 没有明显 arm64 汇编或指针偏移，但私有 HID/SkyLight ABI 仍未知，不能由此承诺 universal |
| universal | Untested / 未交付 | 未来需独立编译两架构、链接依赖、lipo 与签名，且在支持目标 OS 的 Intel 机上验收；并非改一个 Package.swift 即完成 |
| macOS 26 | Unsupported（当前构建） | Package.swift、Info.plist、swift/clang target 都是27.0，Bridge:37 还显式拒绝<27；没有 legacy backend |
| macOS 26 的符号/协议存在性 | Untested / 无本机证据 | 未获得26 runtime/SDK样本；公开文档没有对这些私有符号的可用性承诺。MMF 旧系统有另一实现只是研究线索，不能据此断言当前 HID 路径一定可用/不可用 |
| 27.x 其他小版本或未来主版本 | Untested | @available(27,*) 在更高系统为真，probe 通过仍可能语义改变；必须按版本验证，不宣称27+全部支持 |

未来若考虑26，先在独立测试环境检查符号/构造/回读、再做受控真人交互，并分别评估分发与许可。不得只降低 LSMinimumSystemVersion。本轮没为26或Intel改代码，也没有下载旧系统或更改主机系统。

## Beta 优先测试矩阵

| 优先级 | 维度 / 最小场景 | 必须记录的验收结果 |
|---|---|---|
| P1-先 | 已选产品路线 + 正式签名，干净标准用户；互联网下载→安装→首次授权→重开 | Gatekeeper、路径可写性、权限对象、无 sudo/绕过，卸载及升级 |
| P1-先 | 27.x 目标发行版本的不同小版本，当前 M5 + 至少一台 M1/M2，再补 M3/M4 | OS build、架构、每颗键四方向、probe与真人分别记录；失败不得无限重启 |
| P1-先 | USB 有线、2.4GHz、蓝牙普通双侧键鼠标；不同驱动/编号 | 具体型号/连接方式（不采序列号）、CG编号、两键独立/同时、拔插、是否需要输入监控 |
| P1-先 | 内建屏/单外接屏60Hz/120Hz，双屏混合刷新率 | 半程停住/继续/反向/释放，无挂起或吞输入；同场景触控板对照 |
| P1-先 | 普通桌面、多 Spaces、首尾边界、全屏应用、有/无多个应用窗口 | 动作是否被正确完成/取消，App Exposé 终结延迟单独记录 |
| P1-先 | 睡眠唤醒、锁屏解锁、切换用户、撤销权限、tap禁用、两副本启动 | 退出/异常后鼠标可恢复；不会锁死输入或两个进程竞争 |
| P1-后 | 数小时后台、严格无输入、普通移动、连续手势分别采样 | CPU与输入计数同时间窗；有界RSS趋势、取消/开始配平，不把采样最大值当瞬时峰值 |
| P2（按用户选择） | Intel、macOS26、更多鼠标和驱动共存 | 在投入前确认目标硬件/OS可运行及路线价值；无承诺前无需现在全部完成 |

推荐 Beta 承诺句式：“已验证环境见具体列表；其他版本/设备尚未验证。”尚不能写“支持所有 Mac / 所有鼠标 / macOS 26+”。最终最小系统与公开支持范围由产品路线决定。
