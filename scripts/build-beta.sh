#!/bin/zsh
# Local Beta Preview only. No network, publishing, notarization, or stable-app replacement.
set -euo pipefail
cd "${0:A:h:h}"
root="$PWD"
version=0.2.0-beta.1
commit="$(git rev-parse HEAD)"
[[ -z "$(git status --porcelain --untracked-files=normal)" ]] || { print -u2 'Commit reviewed source before building a traceable Preview.'; exit 1; }
mkdir -p build
# Serialize builds without deleting/replacing another build's staging or artifact.
if [[ "${1:-}" != --locked ]]; then
  xcrun clang scripts/BuildGuard.c -o build/BetaBuildGuard
  exec build/BetaBuildGuard "$root/build/beta-build.lock" /bin/zsh "$root/scripts/build-beta.sh" --locked
fi
work="$(mktemp -d "$root/build/beta-staging.XXXXXX")"
trap 'rm -rf "$work"' EXIT
touch "$work/.preview-staging"
cp -R Sources Tests Resources scripts "$work/"
cp THIRD_PARTY_NOTICES.md "$work/"
/bin/zsh "$work/scripts/test.sh" > "$work/tests.txt" 2>&1 || { cat "$work/tests.txt"; exit 1; }
! /usr/bin/grep -Eq '^(FAIL|SKIP) ' "$work/tests.txt"
/bin/zsh "$work/scripts/compile-preview.sh"
cd "$root"
bundle="$work/build/MacMouseGesture.app"
/usr/libexec/PlistBuddy -c "Add :GitCommit string $commit" "$bundle/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :SourceTreeDirty bool false' "$bundle/Contents/Info.plist"
source scripts/signing.sh
prepare_signing
/usr/bin/codesign --force --sign "$signing_identity" "${signing_keychain_args[@]}" \
  --identifier local.macmousegesture.poc --options runtime --timestamp=none \
  --requirements "=$signing_requirement" --entitlements Resources/Entitlements.plist "$bundle"
python3 scripts/verify-beta.py "$bundle"
python3 scripts/test-beta-package.py "$bundle"
"$bundle/Contents/MacOS/MacMouseGesture" --probe > "$work/probe.txt"
mkdir -p "$work/image" "$work/result/developer"
cp -R "$bundle" "$work/image/MacMouseGesture.app"
ln -s /Applications "$work/image/Applications"
cp docs/INSTALL.md "$work/image/安装说明.md"
hdiutil create -quiet -volname 'MacMouseGesture Beta Preview' -srcfolder "$work/image" \
  -format UDZO "$work/result/MacMouseGesture-$version.dmg"
hdiutil verify "$work/result/MacMouseGesture-$version.dmg"
mkdir "$work/mount"
hdiutil attach -readonly -nobrowse -mountpoint "$work/mount" "$work/result/MacMouseGesture-$version.dmg" > "$work/mount.txt"
trap 'hdiutil detach "$work/mount" >/dev/null 2>&1 || true; rm -rf "$work"' EXIT
python3 scripts/verify-beta.py "$work/mount/MacMouseGesture.app"
[[ "$(readlink "$work/mount/Applications")" == /Applications ]]
hdiutil detach "$work/mount"
trap 'rm -rf "$work"' EXIT
cp -R "$work/build/MacMouseGesture.app.dSYM" "$work/result/developer/"
cp "$work/tests.txt" "$work/probe.txt" "$work/result/developer/"
xcrun dwarfdump --uuid "$bundle/Contents/MacOS/MacMouseGesture" > "$work/result/developer/executable-uuid.txt"
xcrun dwarfdump --uuid "$work/build/MacMouseGesture.app.dSYM" > "$work/result/developer/dsym-uuid.txt"
[[ "$(cut -d ' ' -f 2 "$work/result/developer/executable-uuid.txt")" == "$(cut -d ' ' -f 2 "$work/result/developer/dsym-uuid.txt")" ]]
print -r -- "version=$version build=13 commit=$commit signing=local-self-signed hardened-runtime=true" > "$work/result/developer/build.txt"
(cd "$work/result" && shasum -a 256 "MacMouseGesture-$version.dmg" > SHA256SUMS && shasum -a 256 -c SHA256SUMS)
output="$root/build/beta-preview/$version-build13-$commit"
[[ ! -e "$output" ]] || { print -u2 'Archive already exists; refusing to overwrite.'; exit 1; }
mkdir -p "${output:h}"
mv "$work/result" "$output"
print -r -- "Beta Preview Artifact (not public): $output"
