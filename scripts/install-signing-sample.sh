#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
sample="${1:-}"
[[ "$sample" == A || "$sample" == B ]] || { print -u2 'Usage: install-signing-sample.sh A|B'; exit 64; }
if [[ "${2:-}" != --locked ]]; then
  xcrun clang scripts/BuildGuard.c -o build/BuildGuard
  exec build/BuildGuard "$PWD/build/poc.lock" /bin/zsh "$PWD/scripts/install-signing-sample.sh" "$sample" --locked
fi
source_app="$PWD/build/signing-experiment/$sample/MacMouseGesture.app"
/usr/bin/codesign --verify --deep --strict "$source_app"
stage="$(mktemp -d "$PWD/build/sample-install.XXXXXX")"
ditto "$source_app" "$stage/MacMouseGesture.app"
previous="$(mktemp -d "$PWD/build/previous.XXXXXX")"
mv build/MacMouseGesture.app "$previous/MacMouseGesture.app"
if ! mv "$stage/MacMouseGesture.app" build/MacMouseGesture.app; then
  mv "$previous/MacMouseGesture.app" build/MacMouseGesture.app
  exit 1
fi
rmdir "$stage"
print "Installed signing sample $sample at the fixed bundle path."
