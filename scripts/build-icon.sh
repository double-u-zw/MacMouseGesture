#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p Resources/MacMouseGesture.iconset
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" design/app-icon-source.png --out "Resources/MacMouseGesture.iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" design/app-icon-source.png --out "Resources/MacMouseGesture.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns Resources/MacMouseGesture.iconset -o Resources/MacMouseGesture.icns
