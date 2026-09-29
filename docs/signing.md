# 签名诊断与本机更新实验

2026-09-29。Phase A 已完成；本页保留诊断、迁移和更新实测，历史中间状态按后续结果更新。

## Build 4 实际检查

原始输出保存于 `build/signing-audit/`。对当前正在使用的应用执行了：

```sh
codesign -dv --verbose=4 build/MacMouseGesture.app
codesign -dr - build/MacMouseGesture.app
codesign --verify --deep --strict --verbose=4 build/MacMouseGesture.app
security find-identity -v -p codesigning
plutil -p build/MacMouseGesture.app/Contents/Info.plist
```

| 检查 | 实际结果 |
|---|---|
| 版本 | 0.1.3 / Build 4 |
| 签名 | `Signature=adhoc`；原脚本 `codesign --force --sign -` |
| DR | `cdhash H"f48b3ff46e9a7c0ca578ac0b7685fc3bac240966"` |
| 签名验证 | valid on disk；satisfies its Designated Requirement |
| 可用证书身份 | `0 valid identities found` |
| Team Identifier | not set |
| Bundle ID | `local.macmousegesture.poc` |
| 固定路径 | `build/MacMouseGesture.app` |
| Executable / Name（原 Build 4） | `MacMouseGesture` / `MacMouseGesture POC` |
| 架构 / 最低系统 | arm64 / 27.0 |
| Entitlements | Build 4 无 entitlement 内容 |

结论：Bundle ID、名称、路径不是这几次更新的变化点。原脚本使用 ad-hoc，没有证书身份；隐式 DR 绑定具体 CodeDirectory hash。不是“运行一次就变”，而是代码或签名所封存的内容变化时 hash 通常改变。不能宣称每次无内容变化的重建都必定改变 hash。

此前保留的系统日志 `build/permission-system-log-latest.txt:97` 明确记录：

```text
Failed to match existing code requirement for subject local.macmousegesture.poc and service kTCCServiceAccessibility
```

因此，旧构建获准、更新后旧授权不再匹配，有实际签名与 TCC 日志证据。当前失效反馈中的 Accessibility=true 与这类更新权限失配不是同一项证据；不能据此认定偶发侧键失效也由签名导致。

Apple 说明 ad-hoc 的 DR 绑定具体版本；具有稳定 DR 的证书签名支持系统识别更新。[TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)。自签证书的适用范围、DR 和信任策略见 [TN2206](https://developer.apple.com/library/archive/technotes/tn2206/)，签名时证书链要求见 [TN3161](https://developer.apple.com/documentation/technotes/tn3161-inside-code-signing-certificates)。稳定 DR 是本次实验的前提，是否继承本机 TCC 权限必须实测。

## 已保留的回归基线

`baselines/build4/`（另保留 build 下的早期副本） 中保存原始 `.app` 归档、修改前 Sources / Tests / scripts / Resources 的源码归档、SHA256SUMS、原项目文档、28 项重新运行结果和此次偶发失效反馈。

当时尚未初始化 Git，也没有创建或覆盖任何 tag。原始 Build 4 归档不重新签名，回退时先退出应用，再恢复到原路径。回到 ad-hoc 基线仍可能需重新授权，不能承诺跨签名方案自动继承。

## 已获批准的本地证书操作

本机没有 Apple Development / Developer ID 可用身份。用户已明确批准，已执行 `scripts/setup-local-signing.sh --approved`：

1. 在项目 `.local-signing/` 创建独立钥匙串、随机密码和一张仅用于 code signing 的本地证书，有效期十年。该目录权限 700，文件 600，已加入 `.gitignore`。
2. 将证书与私钥导入该独立钥匙串，允许系统签名工具访问；不导入 login 或 System 钥匙串。创建钥匙串可能短暂加入用户搜索列表，脚本保存并恢复原列表，不改变默认钥匙串。
3. 只对这张证书增加**当前用户、代码签名用途**的信任。macOS 可能要求用户确认认证弹窗。不会改其他证书信任。
4. 固定证书 SHA-1 指纹，DR 同时绑定此证书和 `local.macmousegesture.poc`；后续构建不重新生成证书，也不退回 ad-hoc。首次从 ad-hoc 迁移预计仍需授权一次。
5. 先使用 Build 4 的同一份可执行逻辑制作 A / B 样本，只改变版本封存内容。核对两者 hash 不同、DR 相同，互相满足对方 DR，再在固定安装路径实际验证权限继承。

本轮不会关闭 SIP / Gatekeeper、修改 TCC 数据库、重置全部权限或自动执行任何 TCC reset。信任可通过删除这一证书的用户信任撤销；钥匙串可移除。但移除会使后续无法继续同身份签名，因此不会自动清理 `.local-signing/`。私钥、钥匙串密码不可提交、分享或传到服务端。密码仅保护本机开发钥匙串，保存在同一受限目录，不等同于硬件密钥保护。

本次执行命令：

```sh
./scripts/setup-local-signing.sh --approved
./scripts/signing-experiment.sh
```

若使用已有稳定 Apple 证书，可将 `security find-identity` 的精确 40 位证书指纹写入 `.local-signing/identity.sha1`，不创建本地钥匙串或用户信任。签名脚本使用该固定指纹；更换证书需重新评估 DR 和权限继承。

## 构建保证与实验状态

`./scripts/build.sh` 已改为只接受固定证书身份，缺失则明确停止；在新 bundle 签名和验证成功前不替换旧应用。旧 bundle 移入项目 `build/previous.*` 供回退，运行中仍拒绝替换。ID / Executable / Name 做一致性检查，entitlements 固定为空，不增加能力。

| 验收 | 状态 |
|---|---|
| 原版签名 / DR / identity / plist 审计 | 完成 |
| 原版源码和签名应用回退归档 | 完成 |
| 原有 28 项自动测试 | 28 PASS / 0 FAIL |
| 本地证书 / 用户信任建立 | 已经用户批准并建立，1 valid identity |
| A / B hash 与 DR 比较、交叉验证 | PASS；原始输出 `build/signing-audit/experiment.txt` |
| A 首次授权后 B 继承 Accessibility | PASS：一次经用户批准的定向重置与重新授权后 A=true；更换为 B 后直接 true 并自动 Running，无再次请求授权 |
| Input Monitoring 更新继承 | A 观察时 false，B 打开时 true（HID open 成功）；变化原因未单独验证，不宣称 A/B 继承通过 |
| Phase B / C / D 当时结果 | 见 project-status.md；当时已完成 0.1.4 / Build6，后续 UI 构建见文末 |

## 2026-09-29 实际签名实验

历史归档 Build 3 的 DR 为 `cdhash H"816551579de63b46ddc69b52b6540e60990985a7"`，与 Build 4 的 DR 不同，补充了跨版本变化的实际证据。

新证书固定指纹：`<本机证书指纹，保存在 .local-signing/identity.sha1>`。

```text
identifier "local.macmousegesture.poc" and certificate leaf = H"<本机证书指纹>"
```

| 样本 | 原有逻辑 | CFBundleVersion | CDHash |
|---|---|---|---|
| A | Build 4 不变 | 4.1 | e73ace1d9374ed936e4826af5bd51334fa68ab24 |
| B | Build 4 不变 | 4.2 | f77c720e7d2d0da6b7f3bc94b6a1be1cab5d0f78 |

两份 DR 文本相同；双向 `codesign --verify --strict -R` 均通过。TeamIdentifier 仍为 not set，因为这是本机自签证书，不是假造 Apple Team。两份 entitlement 均为空。

样本通过 `scripts/install-signing-sample.sh A|B` 安装到固定原路径，共用应用锁，旧 bundle 保存在 `build/previous.*`。当时先安装 A，随后完成 B 实验。A 首次 UI 显示 Build 4.1，AX=false，原系统条目仍 on；这是 ad-hoc → 证书的首次身份迁移，不是 A → B 更新实验失败。

开发工具沙箱内不可正常访问用户钥匙串信任：同一操作会报 `SecKeychainUnlock ... parameters ... not valid` 或 `CSSMERR_TP_NOT_TRUSTED`。经用户批准后在正常用户权限上下文中执行成功；未为解决沙箱限制放宽证书策略。证书建立后用户钥匙串搜索列表恢复为原 login.keychain-db，未改变默认钥匙串。

实际验证中修正了 codesign 的内联 requirement 参数语法（需前导 `=`）；失败样本保留在 `build/signing-experiment-*-syntax-failure`，不计入成功记录。运行中执行 build.sh 返回 2，旧 app 未被覆盖。

### 首次迁移受阻的诊断

用户反馈已经重新添加授权，但 A 重启后仍 AX=false。`build/signing-audit/tcc-a-mismatch.txt` 的 00:31:58 记录仍显示旧 Build 4 cdhash 与新证书 DR 不匹配。因此尚未把 A 的运行授权计为通过。按 A7 单独请求一次 `tccutil reset Accessibility local.macmousegesture.poc`，当时等待确认，随后经批准执行（见下一段）；未重置 All、全局 Accessibility 或 Input Monitoring。

### A → B 实际结果

用户随后单独批准执行 **一次** `tccutil reset Accessibility local.macmousegesture.poc`。退出 A 后执行成功，重新启动并由用户开启权限，A UI 显示 Accessibility=Granted、Running。随后退出 A，通过安装脚本替换为 B，再打开：Build=4.2、Accessibility=true、自动 Running。此过程没有对 B 发起权限申请，没有再次 reset。第一次迁移处理已结束，后续继续使用同一证书。

### 编译后的更新验证

完成 A → B 后，又以相同身份实际编译、安装并启动 Build 5（配置保存）和 Build 6（边界诊断）。两次都直接显示 Accessibility=true、Input Monitoring=true、自动 Running，无再次授权或 reset。Build 6 的 DR 仍与 A 一致，并通过 A 的 requirement 验证。最终 `codesign` 输出见 `build/audit-build6/`。

Build 6 CDHash：`15a369a4709db0cf97137d28baba1cf7a013517a`；arm64；空 entitlement；本地证书 Authority=MacMouseGesture Local Development；TeamIdentifier=not set。源码版本为 0.1.4 / Build 6。

### 0.1.5 / Build 7 UI 更新

Build 7 为菜单栏版本。`CFBundleName` 与 `CFBundleDisplayName` 现改为 `MacMouseGesture`，`LSUIElement=true`；Bundle ID、可执行文件名称与安装路径未变。最终 CDHash 为 `a7360b3202a5ee7e8d0d7f30b65825d280062dbc`，DR 仍是上方固定证书和 Bundle ID，`codesign --verify --deep --strict` 显示 valid on disk / satisfies its Designated Requirement。该版本在同一路径运行，设置界面实测 Accessibility=Granted、Input Monitoring=Granted、Gesture Engine=Running，没有再次重置授权。
