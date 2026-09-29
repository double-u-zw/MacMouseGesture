#!/bin/zsh
# Internal: invoked in an isolated source staging directory by build-beta.sh.
set -euo pipefail
cd "${0:A:h:h}"
[[ -f .preview-staging ]] || { print -u2 "Internal helper requires isolated Beta staging."; exit 1; }
source scripts/toolchain.sh
swift_flags+=(-g)
compile_core
# Keep linked objects until dsymutil completes; one-shot swiftc deletes its temps.
xcrun swiftc "${swift_flags[@]}" -whole-module-optimization -emit-object \
  -I build/modules -I Sources/SystemGestureBridge/include \
  Sources/MouseGesturePOC/*.swift -o build/MacMouseGesture.o
xcrun swiftc -target arm64-apple-macosx27.0 \
  build/MacMouseGesture.o build/GestureCore.o build/SystemGestureBridge.o \
  -framework AppKit -framework IOKit -framework Foundation -framework CoreGraphics -framework ServiceManagement \
  -o build/MacMouseGesture
xcrun dsymutil build/MacMouseGesture -o build/MacMouseGesture.app.dSYM
xcrun dwarfdump --debug-info build/MacMouseGesture.app.dSYM > build/dsym-info.txt
/usr/bin/grep -q 'MacMouseGestureApp' build/dsym-info.txt
/usr/bin/grep -q 'MGPostHorizontal' build/dsym-info.txt
# Developer symbols remain in dSYM; user binary should not retain local debug paths.
xcrun strip -S build/MacMouseGesture
mkdir -p build/MacMouseGesture.app/Contents/{MacOS,Resources}
cp build/MacMouseGesture build/MacMouseGesture.app/Contents/MacOS/
cp Resources/Info.plist build/MacMouseGesture.app/Contents/
cp Resources/MacMouseGesture.icns build/MacMouseGesture.app/Contents/Resources/
cp THIRD_PARTY_NOTICES.md build/MacMouseGesture.app/Contents/Resources/
