# Beta Preview 签名选择

本轮选择已有稳定的**本地自签名 + Hardened Runtime、空 entitlements、无安全时间戳**，仅用于本机隔离 Preview 和真人 HR 验收。不是正式发行签名方案，不要求外部用户导入证书或更改信任。

| 方案 | Gatekeeper | TCC / 更新身份 | 完整性 |
|---|---|---|---|
| 自签名 | 不建立 Apple Developer ID 信任或公证；下载仍可能阻止 | 可固定证书与 DR；本机已有权限可能延续，但必须实测，换证书/ID/位置可能重新授权 | 可检验签名及资源封装；不证明发布者获 Apple 信任 |
| ad-hoc | 无可验证发布者身份，不绕过 Gatekeeper | DR 通常绑定特定代码版本；重编译可能改变身份，不能承诺权限延续 | 可检测代码改动，但没有证书身份 |
| unsigned | 没有正常发行签名链，且 Apple Silicon 本地可执行代码有签名要求，不作为本轮可用方案 | 没有可靠的签名身份连续性，不适合权限稳定性验收 | 没有代码签名完整性保障 |

依据：[Apple TN2206](https://developer.apple.com/library/archive/technotes/tn2206/)、[TN3127 requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)、[ad-hoc flag](https://developer.apple.com/documentation/security/seccodesignatureflags/adhoc)、[Apple 安全打开 App](https://support.apple.com/102445)。这些资料描述签名机制，不构成本项目 TCC 兼容性承诺。

正式站外分发仍以 Developer ID + notarization 为推荐路线，但申请、提交、公证及 stapling 不在本轮范围。private API 与第三方许可仍单独审核。系统允许覆盖也不等于获得再分发许可。
