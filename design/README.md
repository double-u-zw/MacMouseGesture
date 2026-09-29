# App icon

`app-icon-source.png`：最终 1024×1024 RGBA 源图。由内置 imagegen 工具生成，参考用户提供的蓝色鼠标四向草案；没有使用品牌产品照片或现成第三方 App icon。

生成提示词：

> Create a production macOS app icon for MacMouseGesture, square 1024x1024. The reference is visual direction only: dark blue rounded square, centered mouse, four directional arrows. Simplify dramatically: clean stylized generic silver/white mouse silhouette with one dark wheel and two clearly visible side buttons, four large bold white-cyan arrows pointing outward up down left right, all separate from mouse with clear negative space. Navy to cobalt softly shaded rounded-square tile, minimal depth, no tiny texture, no ornamental waves, no motion trails, no photorealistic hardware, no brands or text. Icon tile fills about 90% of canvas, perfectly centered. Outside rounded tile is genuinely transparent. Must read clearly at 16 and 32 pixels. No shadow outside tile, no background scene. Generate a new original generic mouse design, not a branded product rendering.

工具输出以 sips 规格化为 1024；`scripts/build-icon.sh` 生成完整 macOS iconset（16/32/128/256/512，各含 @2x）及 `Resources/MacMouseGesture.icns`。构建脚本将 ICNS 打包进 Contents/Resources，plist 设置 CFBundleIconFile。菜单栏仍使用单色 SF Symbol template。

[尺寸与浅深色背景预览](icon-preview.html)展示真实资源（没有屏幕录制）。Finder / Get Info / 实际 About 的最终视觉验收需对安装后的 App 检查；Launchpad 如系统提供再检查。
