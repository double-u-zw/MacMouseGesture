#!/bin/zsh
# Prepares two signed Build 4 equivalents. Does not replace or launch the app.
set -euo pipefail
cd "${0:A:h:h}"
source scripts/signing.sh
prepare_signing
root="$PWD/build/signing-experiment"
[[ ! -e "$root" ]] || { print -u2 'Experiment already exists; retain its evidence.'; exit 1; }
mkdir -p "$root"
for sample in A B; do
  mkdir "$root/$sample"
  tar -xf baselines/build4/MacMouseGesture.app.tar -C "$root/$sample"
  app="$root/$sample/MacMouseGesture.app"
  version=4.1
  [[ "$sample" == A ]] || version=4.2
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $version" "$app/Contents/Info.plist"
  sign_bundle "$app"
  /usr/bin/codesign -dv --verbose=4 "$app" > "$root/$sample/details.txt" 2>&1
  /usr/bin/codesign -dr - "$app" 2>&1 | /usr/bin/sed -n 's/^designated => //p' > "$root/$sample/requirement.txt"
  [[ -s "$root/$sample/requirement.txt" ]]
  /usr/bin/shasum -a 256 "$app/Contents/MacOS/MacMouseGesture" > "$root/$sample/executable-sha256.txt"
done
cmp "$root/A/requirement.txt" "$root/B/requirement.txt"
requirement_a="$(cat "$root/A/requirement.txt")"
requirement_b="$(cat "$root/B/requirement.txt")"
/usr/bin/codesign --verify --deep --strict -R "=$requirement_a" "$root/B/MacMouseGesture.app"
/usr/bin/codesign --verify --deep --strict -R "=$requirement_b" "$root/A/MacMouseGesture.app"
hash_a="$(/usr/bin/sed -n 's/^CDHash=//p' "$root/A/details.txt")"
hash_b="$(/usr/bin/sed -n 's/^CDHash=//p' "$root/B/details.txt")"
[[ -n "$hash_a" && -n "$hash_b" && "$hash_a" != "$hash_b" ]]
print 'PASS: different code-directory hashes; identical DR; both samples satisfy the other DR.'
print 'TCC inheritance still requires the same-path A → permission → B launch experiment.'
