#!/bin/zsh
# Sourced by build.sh and the update experiment. No implicit ad-hoc fallback.
prepare_signing() {
  signing_dir="$PWD/.local-signing"
  if [[ ! -f "$signing_dir/identity.sha1" ]]; then
    print -u2 'No pinned signing identity. See docs/signing.md; configure a stable certificate before building.'
    return 1
  fi
  signing_identity="$(< "$signing_dir/identity.sha1")"
  if [[ ! "$signing_identity" =~ '^[A-Fa-f0-9]{40}$' ]]; then
    print -u2 'Invalid certificate fingerprint in .local-signing/identity.sha1'; return 1
  fi
  signing_keychain_args=()
  if [[ -f "$signing_dir/development.keychain-db" ]]; then
    /usr/bin/security unlock-keychain -p "$(< "$signing_dir/password")" "$signing_dir/development.keychain-db"
    signing_keychain_args=(--keychain "$signing_dir/development.keychain-db")
  fi
  signing_requirement="designated => identifier \"local.macmousegesture.poc\" and certificate leaf = H\"$signing_identity\""
}
sign_bundle() {
  local target_bundle="$1"
  /usr/bin/codesign --force --sign "$signing_identity" "${signing_keychain_args[@]}" \
    --identifier local.macmousegesture.poc --timestamp=none \
    --requirements "=$signing_requirement" --entitlements Resources/Entitlements.plist "$target_bundle"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$target_bundle"
  /usr/bin/codesign --verify --strict -R "=identifier \"local.macmousegesture.poc\" and certificate leaf = H\"$signing_identity\"" "$target_bundle"
}
