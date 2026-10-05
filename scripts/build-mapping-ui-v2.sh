#!/bin/zsh
# Build 30: approved v2 UI, current configuration/services. No existing package replaced.
set -euo pipefail
cd "${0:A:h:h}"
source scripts/toolchain.sh
output="$PWD/build/mapping-ui-v2/build30"
mkdir -p "$output"
source scripts/signing.sh
prepare_signing
compile_core
bundle="$output/MacMouseGesture Mapping UI v2 Dev.app"
[[ ! -e "$bundle" ]] || { print -u2 'Build 30 already exists; preserve it before rebuilding.'; exit 1; }
stage="$(mktemp -d "$output/package.XXXXXX")"
staged_bundle="$stage/MacMouseGesture Mapping UI v2 Dev.app"
mkdir -p "$staged_bundle/Contents/MacOS" "$staged_bundle/Contents/Resources"
xcrun swiftc "${swift_flags[@]}" -I build/modules -I Sources/SystemGestureBridge/include \
  Sources/MouseGesturePOC/*.swift build/GestureCore.o build/SystemGestureBridge.o \
  -framework AppKit -framework IOKit -framework Foundation -framework CoreGraphics -framework ServiceManagement \
  -o "$staged_bundle/Contents/MacOS/MacMouseGesture"
cp Resources/Info.plist "$staged_bundle/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 30' "$staged_bundle/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 0.2.0-beta.1-mapping-ui-v2-dev' "$staged_bundle/Contents/Info.plist"
cp Resources/MacMouseGesture.icns THIRD_PARTY_NOTICES.md "$staged_bundle/Contents/Resources/"
sign_bundle "$staged_bundle"
mv "$staged_bundle" "$bundle"
rmdir "$stage"
print -r -- "Built: $bundle"
