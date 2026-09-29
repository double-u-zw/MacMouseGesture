#!/bin/zsh
# Internal: invoked in an isolated source staging directory by build-beta.sh.
set -euo pipefail
cd "${0:A:h:h}"
[[ -f .preview-staging ]] || { print -u2 "Internal helper requires isolated Beta staging."; exit 1; }
source scripts/toolchain.sh
swift_flags+=(-g -debug-prefix-map "$PWD=.")
compile_core
xcrun swiftc "${swift_flags[@]}" -I build/modules -I Sources/SystemGestureBridge/include \
  Sources/MouseGesturePOC/*.swift build/GestureCore.o build/SystemGestureBridge.o \
  -framework AppKit -framework IOKit -framework Foundation -framework CoreGraphics -framework ServiceManagement \
  -o build/MacMouseGesture
mkdir -p build/MacMouseGesture.app/Contents/{MacOS,Resources}
cp build/MacMouseGesture build/MacMouseGesture.app/Contents/MacOS/
cp Resources/Info.plist build/MacMouseGesture.app/Contents/
cp Resources/MacMouseGesture.icns build/MacMouseGesture.app/Contents/Resources/
cp THIRD_PARTY_NOTICES.md build/MacMouseGesture.app/Contents/Resources/
xcrun dsymutil build/MacMouseGesture -o build/MacMouseGesture.app.dSYM
