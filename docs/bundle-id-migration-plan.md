# Bundle ID 迁移 — PUBLIC_BETA_GATE

当前保留 `local.macmousegesture.poc`。本轮不擅自选 namespace。用户需确定开发主体及其控制的命名空间，例如 `com.<developer>.macmousegesture`；示例不是可直接使用的正式 ID。

| 影响 | 迁移与验收 |
|---|---|
| Accessibility / Input Monitoring / TCC identity | 新 ID/DR/签名可能是新应用；明确重新授权说明，不复制/重置 TCC，不保证旧权限沿用 |
| UserDefaults | 经用户知情导入已知旧配置键与 onboardingCompleted；校验后写新域，保留旧域便于回退，不读取其他偏好 |
| Launch at Login | 旧 App 先 unregister，再由用户在新 App 启用；核对系统登录项，防止旧副本自动启动 |
| Single instance | 迁移期共用当前产品锁或同时持有新旧锁，并检测旧版本进程；不能让两个 ID 同时启动引擎 |
| Updates | 新 ID、代码签名 DR 和安装位置作为身份切换版本处理；明确手动替换步骤，无感更新待验收 |
| 资源与构建 | 更新 plist、signing requirement、锁目录、文档、测试和元数据校验；不只改 plist |

顺序：用户确定 ID/发行主体 → 实施并测试迁移 → 干净用户首次授权 → 旧版升级/回退/登录项测试 → 生成新的 Public Beta 包。当前 artifact 只叫 Beta Preview Artifact，外部测试者不应长期依赖此身份。
