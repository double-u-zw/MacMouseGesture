#!/bin/zsh
# Independent development package; never touches build/MacMouseGesture.app,
# Resources/Info.plist (stable Build 17), or /Applications/MacMouseGesture.app.
set -euo pipefail
cd "${0:A:h:h}"
source scripts/toolchain.sh
output="$PWD/build/button-wheel-v1/build28"
mkdir -p "$output"
source scripts/signing.sh
prepare_signing
compile_core
bundle="$output/MacMouseGesture Button Wheel Dev.app"
[[ ! -e "$bundle" ]] || { print -u2 'Build 28 already exists; preserve it before rebuilding.'; exit 1; }
stage="$(mktemp -d "$output/package.XXXXXX")"
staged_bundle="$stage/MacMouseGesture Button Wheel Dev.app"
mkdir -p "$staged_bundle/Contents/MacOS" "$staged_bundle/Contents/Resources"
xcrun swiftc "${swift_flags[@]}" -I build/modules -I Sources/SystemGestureBridge/include \
  Sources/MouseGesturePOC/*.swift build/GestureCore.o build/SystemGestureBridge.o \
  -framework AppKit -framework IOKit -framework Foundation -framework CoreGraphics -framework ServiceManagement \
  -o "$staged_bundle/Contents/MacOS/MacMouseGesture"
cp Resources/Info.plist "$staged_bundle/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 28' "$staged_bundle/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 0.2.0-beta.1-button-wheel-dev' "$staged_bundle/Contents/Info.plist"
cp Resources/MacMouseGesture.icns THIRD_PARTY_NOTICES.md "$staged_bundle/Contents/Resources/"
sign_bundle "$staged_bundle"
mv "$staged_bundle" "$bundle"
rmdir "$stage"
print -r -- "Built: $bundle"
