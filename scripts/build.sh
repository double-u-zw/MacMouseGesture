#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
source scripts/toolchain.sh
if [[ "${1:-}" != "--locked" ]]; then
  xcrun clang scripts/BuildGuard.c -o build/BuildGuard
  exec build/BuildGuard "$PWD/build/poc.lock" /bin/zsh "$PWD/scripts/build.sh" --locked
fi
source scripts/signing.sh
prepare_signing
# Identity fields cannot drift when only the version is meant to change.
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Resources/Info.plist)" == local.macmousegesture.poc ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' Resources/Info.plist)" == MacMouseGesture ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' Resources/Info.plist)" == 'MacMouseGesture' ]]
compile_core
xcrun swiftc "${swift_flags[@]}" -I build/modules -I Sources/SystemGestureBridge/include \
  Sources/MouseGesturePOC/*.swift build/GestureCore.o build/SystemGestureBridge.o \
  -framework AppKit -framework IOKit -framework Foundation -framework CoreGraphics -framework ServiceManagement -o build/MacMouseGesture
bundle="$PWD/build/MacMouseGesture.app"
stage="$(mktemp -d "$PWD/build/package.XXXXXX")"
staged_bundle="$stage/MacMouseGesture.app"
mkdir -p "$staged_bundle/Contents/MacOS" "$staged_bundle/Contents/Resources"
cp build/MacMouseGesture "$staged_bundle/Contents/MacOS/MacMouseGesture"
cp Resources/Info.plist "$staged_bundle/Contents/Info.plist"
cp THIRD_PARTY_NOTICES.md "$staged_bundle/Contents/Resources/"
sign_bundle "$staged_bundle"
# Keep the previously installed bundle recoverable, even if a later build fails.
if [[ -e "$bundle" ]]; then
  previous="$(mktemp -d "$PWD/build/previous.XXXXXX")"
  mv "$bundle" "$previous/MacMouseGesture.app"
fi
if ! mv "$staged_bundle" "$bundle"; then
  [[ -z "${previous:-}" ]] || mv "$previous/MacMouseGesture.app" "$bundle"
  exit 1
fi
rmdir "$stage"
print -r -- "Built: $bundle"
