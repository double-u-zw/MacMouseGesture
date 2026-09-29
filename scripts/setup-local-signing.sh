#!/bin/zsh
# Run only after the user approves the scope described in docs/signing.md.
set -euo pipefail
cd "${0:A:h:h}"
if [[ "${1:-}" != "--approved" ]]; then
  print -u2 'Read docs/signing.md first. This creates a project keychain and adds user-level trust for one code-signing certificate. Then run with --approved.'
  exit 64
fi
umask 077
dir="$PWD/.local-signing"
if [[ -e "$dir" ]]; then
  print -u2 'Refusing to replace existing signing material. Inspect .local-signing; never regenerate an update identity silently.'
  exit 1
fi
mkdir -m 700 "$dir"
keychain="$dir/development.keychain-db"
/usr/bin/openssl rand -base64 32 > "$dir/password"
cat > "$dir/certificate.cnf" <<'EOF'
[req]
distinguished_name = subject
x509_extensions = codesign
prompt = no
[subject]
CN = MacMouseGesture Local Development
O = MacMouseGesture Personal Development
[codesign]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
EOF
/usr/bin/openssl req -new -x509 -newkey rsa:2048 -nodes -days 3650 \
  -config "$dir/certificate.cnf" -keyout "$dir/private-key.pem" -out "$dir/certificate.pem" 2> "$dir/generation.log"
/usr/bin/openssl pkcs12 -export -inkey "$dir/private-key.pem" -in "$dir/certificate.pem" \
  -name 'MacMouseGesture Local Development' -passout "file:$dir/password" -out "$dir/identity.p12"
# security create-keychain may add its new file to the search list. Restore the
# exact preexisting user search list, including on failure. Never change default.
/usr/bin/security list-keychains -d user > "$dir/search-list-before.txt"
previous_keychains=()
while IFS= read -r line; do
  line="${line#*\"}"; line="${line%\"}"
  [[ -z "$line" ]] || previous_keychains+=("$line")
done < "$dir/search-list-before.txt"
restore_search_list() { /usr/bin/security list-keychains -d user -s "${previous_keychains[@]}"; }
trap restore_search_list EXIT
password="$(< "$dir/password")"
/usr/bin/security create-keychain -p "$password" "$keychain"
/usr/bin/security unlock-keychain -p "$password" "$keychain"
/usr/bin/security import "$dir/identity.p12" -k "$keychain" -P "$password" -T /usr/bin/codesign > "$dir/import.log" 2>&1
/usr/bin/security set-key-partition-list -S apple-tool:,apple: -s -k "$password" "$keychain" > "$dir/key-access.log" 2>&1
# Only this certificate, only the current user, only the code-signing policy.
# This can display a macOS authentication prompt, which the user handles.
/usr/bin/security add-trusted-cert -r trustRoot -p codeSign -k "$keychain" "$dir/certificate.pem"
/usr/bin/openssl x509 -in "$dir/certificate.pem" -noout -fingerprint -sha1 |
  /usr/bin/sed 's/.*=//;s/://g' > "$dir/identity.sha1"
/usr/bin/security find-identity -v -p codesigning "$keychain"
# Retain the encrypted keychain and its local password; delete only our temporary
# unencrypted PEM and transport archive once import and trust have succeeded.
/bin/rm "$dir/private-key.pem" "$dir/identity.p12"
print 'Local signing identity prepared. Keep .local-signing private and retain it across builds.'
