# 本地签名与构建

开发环境为 macOS 27 / Apple Silicon 和 Xcode 命令行工具。构建与测试使用仓库脚本；开发包统一输出到 `build/dev/`。公开 Build17 的已有签名/Release 资产不会因为新开发构建而改变。

## 固定开发身份

构建使用 `.local-signing/identity.sha1` 中固定的 40 位证书指纹，缺失或无效时停止，不自动退回 ad-hoc。指定要求绑定永久 Bundle ID `io.github.double-u-zw.macmousegesture` 和该 certificate leaf；实际指纹、密码和私钥不得写进文档或 Git。

已有可用代码签名证书时，可用 `security find-identity -v -p codesigning` 确认可用身份，并在本机配置固定指纹。若使用项目独立钥匙串，`.local-signing/development.keychain-db` 与其本地密码只用于本机签名。

没有证书时，先阅读并明确同意以下操作范围，再运行：

```sh
zsh scripts/setup-local-signing.sh --approved
```

该脚本创建项目独立钥匙串和一张本地 code-signing 证书，允许系统 codesign 访问，只增加这张证书的当前用户代码签名信任，并恢复原钥匙串搜索列表；不改变默认钥匙串。已有 `.local-signing/` 时拒绝覆盖。系统认证提示由用户处理。

`.local-signing/` 保留在 Git 忽略范围，目录/文件权限限制为 700/600。不要提交、分享或删除仍需使用的钥匙串/密码，不导入他人的本地证书。签名脚本读取本地材料不代表可以打印其内容。

## 日常操作

```sh
zsh scripts/test.sh
zsh scripts/build-dev.sh
open build/dev/MacMouseGesture.app
```

常规本地构建使用 `zsh scripts/build.sh`，输出 `build/MacMouseGesture.app`；开发入口调用同一脚本的 `--dev` 模式，输出 `build/dev/MacMouseGesture.app`。两个入口使用同一份源 Info.plist，当前均为 `0.2.0-beta.1-dev / Build 33`，不自动改版本号。目标 App 正运行时，构建在开始和替换前检查其实际可执行路径并拒绝覆盖；另一路径运行的实例不妨碍生成新包，但运行仍受单实例锁约束。

隔离打包使用 `zsh scripts/build-beta.sh`：要求已提交源码，先运行测试，再生成 Hardened Runtime 本地签名 App、DMG、SHA256SUMS 与匹配 dSYM；版本/build 读取源 Info.plist，不固定为公开 Build17，也不安装覆盖或上传。产物目录为 `build/beta-preview/<version>-build<build>-<commit>/`，已有同目录时拒绝覆盖；当前工作区未提交的源码和文档会触发 clean 门禁。

新包在签名与验证通过后才用于检查；关闭窗口不会退出 App，切换运行包前应先通过菜单“退出”。新包与安装版共用产品偏好和单实例锁，不能同时运行。图标需要重新生成时运行 `zsh scripts/build-icon.sh`，来源见[design 说明](../design/README.md)。

检查一个包的结构与签名可运行：

```sh
codesign --verify --deep --strict build/dev/MacMouseGesture.app
codesign -dv --verbose=4 build/dev/MacMouseGesture.app
codesign -dr - build/dev/MacMouseGesture.app
```

证书指定要求支持稳定代码身份；ad-hoc 通常绑定具体代码 hash。身份稳定是权限延续的条件之一，不是 TCC 继承保证。更换 Bundle ID、证书或安装位置后可能需要重新授权；历史一次授权重置不属于正常更新步骤。

## 公开分发的区别

本地自签名可验证资源完整性，不能提供 Developer ID 下载信任或 Apple 公证。当前公开 Build17 未经公证。Hardened Runtime、签名、Gatekeeper 和私有 API 使用条件是不同问题；签名/probe 通过不代表系统手势已真机通过。

将来准备新的公开包时，先明确发行身份与路线；Developer ID 流程包括必要 entitlements、Hardened Runtime、安全时间戳、notarytool 提交和日志审查、staple/validate、最终 Gatekeeper 与干净用户下载验收。ZIP 不能直接 staple，应给内部 App 附票后重打包。不要为动态加载盲目增加禁用 library validation 等例外。

公开资产只提供匹配版本的用户包和 SHA256SUMS；需要分析崩溃时再导出匹配 dSYM。打包检查结束后清理本地产物，活动项目不长期归档独立 release artifact 或工程日志。发布前核对源码 commit/dirty 状态、版本/build、二进制与 dSYM UUID，校验实际最终包。官方参考：[代码签名](https://developer.apple.com/library/archive/technotes/tn2206/)、[指定要求](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)、[公证](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)。
