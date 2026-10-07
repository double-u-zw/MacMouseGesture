# 系统手势 Bridge 与来源

`Sources/SystemGestureBridge/SystemGestureBridge.m` 中的 `SystemGestureEventBuilder` 将请求描述映射为原生 HID 负载，再封装并投递 CGEvent。鼠标识别、阈值、进度计算和动作选择属于 Swift 层。

## 接口与协议

四个 C 入口均返回 bool：`MGBackendProbe(char *, unsigned long)`、`MGVerticalProbe(char *, unsigned long)`、`MGPostHorizontal(double progress, double velocity, uint32_t phase)`、`MGPostVertical(double progress, double velocity, uint32_t phase)`。

入口决定轴；progress 为绝对有符号进度，velocity 为 progress/秒，phase 为 1 began、2 changed、4 ended、8 cancelled。NaN、Infinity 或无效 phase 拒绝且不投递。Bridge 不缩放、反转或裁剪参数。

| 负载 | 当前协议 |
|---|---|
| DockSwipe 根对象 | type 23；options 为 `phase << 24`。 |
| Motion / Progress / Flavor | 字段 `(23<<16)|1` 为横向 1 或纵向 2；`(23<<16)|2` 为 progress；`(23<<16)|5` 为 DockPrimary=3。 |
| 终止速度 | 仅 end/cancel 附 type 9 子事件；字段 `(9<<16)|{0,1,2}` 为横向(v,0,0)或纵向(0,v,0)。 |
| CGEvent 外壳 | type 30，session event tap，标记 `0x4D47504F43`。 |
| 时间 | HID 使用当前 mach time；CGEvent 使用单调 uptime 纳秒。 |

每次调用先分配完整对象集，再统一写字段和附加负载，构造成功才投递一次。缺类、符号、selector、分配失败或异常失败关闭；CF 所有权平衡，Objective-C 对象由 ARC 管理。Probe 只构造、附加、回读和释放，永不投递。返回 true 表示构造及投递调用完成，没有 Dock 响应确认。

## 非公开接口来源

连续 Spaces、调度中心和应用 Exposé 依赖 private HID.framework 的 `HIDEvent`、SkyLight 的 `SLEventSetIOHIDEvent` / `SLEventCopyIOHIDEvent` 及未文档化 DockSwipe 字段。动态加载和公开 CGEvent 投递函数不使这些接口成为公开 SDK 合同；系统更新可能改变其存在性或语义，签名与公证不提供接口授权或兼容保证。

| 来源 | 固定版本与引用范围 |
|---|---|
| Apple IOHIDFamily | [IOHIDFamily-1633.120.12](https://github.com/apple-oss-distributions/IOHIDFamily/tree/IOHIDFamily-1633.120.12) 的 `IOHIDEventTypes.h`、`IOHIDEventFieldDefs.h`、`HIDEvent.h`，为最小 ABI 声明、类型和字段编号的来源。 |
| Mac Mouse Fix，Noah Nuebling | 参考快照 `a7ac3ecc86acf4ddb309ce1007472439a2f9d42a`；系统手势协议、连续体验和高频输入合并的参考来源。许可为固定版本的 [MMF License](https://github.com/noah-nuebling/mac-mouse-fix/blob/0c0fc99e65b3b09e083cbedc71c4d83fe21d1075/License)。 |

## 归因与许可边界

当前 Builder 按项目接口契约组织请求、对象分配和字段映射；项目记录的工程来源判断未发现当前实现中的 MMF 代码级派生。这不构成法律保证，也不表示未参考过 MMF。归因不授予额外权限或取消对应材料的适用条款。

项目自有代码采用根 [MIT License](../LICENSE)。MMF 使用自定义许可，不能用项目 MIT 重新授权其材料。Apple 相关头文件含 APSL 通知；最小声明和协议事实的精确覆盖范围仍需独立判断，没有打包完整 Apple 头文件或实现。完整第三方声明保留在 [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)。
