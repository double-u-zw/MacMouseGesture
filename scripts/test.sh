#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
source scripts/toolchain.sh
compile_core
xcrun swiftc "${swift_flags[@]}" -I build/modules -I Sources/SystemGestureBridge/include \
  Tests/CoreRegression/*.swift Sources/MouseGesturePOC/MouseInput.swift Sources/MouseGesturePOC/Diagnostics.swift \
  Sources/MouseGesturePOC/AutoStartState.swift Sources/MouseGesturePOC/AppConfig.swift Sources/MouseGesturePOC/RuntimeMetrics.swift \
  Sources/MouseGesturePOC/PresentationState.swift Sources/MouseGesturePOC/AppViewModel.swift \
  build/GestureCore.o build/SystemGestureBridge.o \
  -framework Foundation -framework CoreGraphics -framework SwiftUI -o build/CoreRegression
build/CoreRegression
