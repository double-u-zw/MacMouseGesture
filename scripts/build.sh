#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
dev_mode=false
locked=false
for option in "$@"; do
  case "$option" in
    --dev) dev_mode=true ;;
    --locked) locked=true ;;
    *) print -u2 "Unknown build option: $option"; exit 64 ;;
  esac
done
output="$PWD/build"
mode_args=()
if $dev_mode; then
  output="$PWD/build/dev"
  mode_args=(--dev)
fi
bundle="$output/MacMouseGesture.app"
mkdir -p "$output"
if ! $locked; then
  guard="$(mktemp "$PWD/build/.BuildGuard.XXXXXX")"
  trap 'rm -f "$guard"' EXIT
  xcrun clang scripts/BuildGuard.c -o "$guard"
  mv -f "$guard" build/BuildGuard
  trap - EXIT
  exec build/BuildGuard "$PWD/build/build.lock" --bundle "$bundle" \
    /bin/zsh "$PWD/scripts/build.sh" --locked "${mode_args[@]}"
fi
source scripts/toolchain.sh
source scripts/signing.sh
prepare_signing
# Identity fields cannot drift when only the version is meant to change.
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Resources/Info.plist)" == io.github.double-u-zw.macmousegesture ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' Resources/Info.plist)" == MacMouseGesture ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' Resources/Info.plist)" == 'MacMouseGesture' ]]
compile_core
stage="$(mktemp -d "$output/.package.XXXXXX")"
cleanup() {
  if [[ -d "$stage/previous.app" && ! -e "$bundle" ]]; then
    mv "$stage/previous.app" "$bundle"
  fi
  rm -rf "$stage"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
staged_bundle="$stage/MacMouseGesture.app"
mkdir -p "$staged_bundle/Contents/MacOS" "$staged_bundle/Contents/Resources"
xcrun swiftc "${swift_flags[@]}" -I build/modules -I Sources/SystemGestureBridge/include \
  Sources/MouseGesturePOC/*.swift build/GestureCore.o build/SystemGestureBridge.o \
  -framework AppKit -framework IOKit -framework Foundation -framework CoreGraphics -framework ServiceManagement \
  -o "$staged_bundle/Contents/MacOS/MacMouseGesture"
cp Resources/Info.plist "$staged_bundle/Contents/Info.plist"
cp Resources/MacMouseGesture.icns "$staged_bundle/Contents/Resources/"
cp THIRD_PARTY_NOTICES.md "$staged_bundle/Contents/Resources/"
sign_bundle "$staged_bundle"
# Recheck after compilation. Keep rollback material only until replacement succeeds.
build/BuildGuard --check-bundle "$bundle"
if [[ -e "$bundle" ]]; then
  mv "$bundle" "$stage/previous.app"
fi
if ! mv "$staged_bundle" "$bundle"; then
  exit 1
fi
print -r -- "Built: $bundle"
