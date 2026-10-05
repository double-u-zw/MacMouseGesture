#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
source scripts/toolchain.sh
compile_core
xcrun swiftc "${swift_flags[@]}" -I build/modules -I Sources/SystemGestureBridge/include \
  Tests/CoreRegression/*.swift Sources/MouseGesturePOC/MouseInput.swift Sources/MouseGesturePOC/Diagnostics.swift \
  Sources/MouseGesturePOC/DiagnosticRedactor.swift Sources/MouseGesturePOC/SingleInstance.swift Sources/MouseGesturePOC/OnboardingState.swift Sources/MouseGesturePOC/ProductIdentity.swift \
  Sources/MouseGesturePOC/AutoStartState.swift Sources/MouseGesturePOC/MissionControlAction.swift Sources/MouseGesturePOC/AppExposeAction.swift Sources/MouseGesturePOC/MinimizeWindowAction.swift Sources/MouseGesturePOC/FullScreenWindowAction.swift Sources/MouseGesturePOC/BackMouseAction.swift Sources/MouseGesturePOC/FinderAction.swift Sources/MouseGesturePOC/SyntheticSideButtonEvents.swift Sources/MouseGesturePOC/MouseButtonActionExecutor.swift Sources/MouseGesturePOC/MouseButtonAction.swift Sources/MouseGesturePOC/SideButtonClickTracker.swift Sources/MouseGesturePOC/AppConfig.swift Sources/MouseGesturePOC/MouseMapping.swift Sources/MouseGesturePOC/MouseMappingStore.swift Sources/MouseGesturePOC/StandaloneShortPressTracker.swift Sources/MouseGesturePOC/RuntimeMetrics.swift \
  Sources/MouseGesturePOC/PresentationState.swift Sources/MouseGesturePOC/AppViewModel.swift Sources/MouseGesturePOC/LegacyDragSettingsAdapter.swift Sources/MouseGesturePOC/MappingPresentation.swift \
  Sources/MouseGesturePOC/MouseButtonIdentifier.swift Sources/MouseGesturePOC/MouseInputRecorder.swift \
  Sources/MouseGesturePOC/LongPressConfiguration.swift Sources/MouseGesturePOC/LongPressScheduler.swift Sources/MouseGesturePOC/LongPressCoordinator.swift \
  Sources/MouseGesturePOC/WheelStepNormalizer.swift Sources/MouseGesturePOC/WheelInputHandoff.swift \
  build/GestureCore.o build/SystemGestureBridge.o \
  -framework Foundation -framework CoreGraphics -framework SwiftUI -o build/CoreRegression
build/CoreRegression
# Exercise the real native Bridge contract with the posting boundary intercepted.
xcrun clang -fobjc-arc -fmodules -fmodules-cache-path="$PWD/build/module-cache" \
  -mmacosx-version-min=27.0 -I Sources/SystemGestureBridge/include \
  -DMG_BRIDGE_CONTRACT_TESTS -DCGEventPost=MGContractPost -DCGEventCreate=MGContractCreate \
  -c Sources/SystemGestureBridge/SystemGestureBridge.m -o build/SystemGestureBridgeContract.o
xcrun clang -fobjc-arc -fmodules -fmodules-cache-path="$PWD/build/module-cache" \
  -mmacosx-version-min=27.0 -I Sources/SystemGestureBridge/include \
  Tests/BridgeContract/main.m build/SystemGestureBridgeContract.o \
  -framework Foundation -framework CoreGraphics -o build/BridgeContractTests
# A missing interposition must fail before the executable can run.
if nm -u build/BridgeContractTests | /usr/bin/grep -q ' _CGEventPost$'; then
  print -u2 'Unsafe Bridge test executable links real CGEventPost'; exit 1
fi
build/BridgeContractTests
