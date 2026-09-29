#!/bin/zsh
# Sourced by build/test. All explicit build, cache and temporary output is local.
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p build/tmp build/module-cache build/modules
export TMPDIR="$PWD/build/tmp/"
export CLANG_MODULE_CACHE_PATH="$PWD/build/module-cache"
export SWIFT_MODULECACHE_PATH="$PWD/build/module-cache"
export SWIFT_USE_OLD_DRIVER=1
swift_flags=(-O -target arm64-apple-macosx27.0 -module-cache-path "$PWD/build/module-cache")
compile_core() {
  xcrun clang -g -fdebug-prefix-map="$PWD=." -fobjc-arc -fmodules -fmodules-cache-path="$PWD/build/module-cache" \
    -mmacosx-version-min=27.0 -I Sources/SystemGestureBridge/include \
    -c Sources/SystemGestureBridge/SystemGestureBridge.m -o build/SystemGestureBridge.o
  xcrun swiftc "${swift_flags[@]}" -parse-as-library -emit-module -enable-testing \
    -module-name GestureCore Sources/GestureCore/GestureMachine.swift Sources/GestureCore/VerticalGestureTracker.swift \
    -emit-module-path build/modules/GestureCore.swiftmodule
  xcrun swiftc "${swift_flags[@]}" -parse-as-library -whole-module-optimization -emit-object -enable-testing \
    -module-name GestureCore Sources/GestureCore/GestureMachine.swift Sources/GestureCore/VerticalGestureTracker.swift \
    -o build/GestureCore.o
}
