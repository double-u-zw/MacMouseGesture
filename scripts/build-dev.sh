#!/bin/zsh
# Current development package. Version and Build come from Resources/Info.plist.
set -euo pipefail
cd "${0:A:h:h}"
exec /bin/zsh "$PWD/scripts/build.sh" --dev "$@"
