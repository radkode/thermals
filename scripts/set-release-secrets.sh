#!/usr/bin/env bash
# Sets the release environment secrets the workflow needs. Run it yourself in a terminal; it prompts for
# passwords and IDs and never prints or stores a local copy of a secret value.
# Usage: scripts/set-release-secrets.sh <DeveloperID.p12> <AuthKey_KEYID.p8>
set -euo pipefail

REPO="${REPO:-radkode/thermals}"
P12="${1:?usage: $0 <DeveloperID.p12> <AuthKey_KEYID.p8>}"
P8="${2:?usage: $0 <DeveloperID.p12> <AuthKey_KEYID.p8>}"
[[ -f "$P12" ]] || { echo "Not found: $P12" >&2; exit 1; }
[[ -f "$P8" ]] || { echo "Not found: $P8" >&2; exit 1; }

read -r -s -p "Password for $(basename "$P12"): " P12_PASSWORD; echo
# openssl reads it from the environment (env:), so it must be exported first.
export P12_PASSWORD
# Keychain Access exports with legacy RC2-40, which OpenSSL 3+ only reads with -legacy.
openssl pkcs12 -in "$P12" -noout -passin env:P12_PASSWORD 2>/dev/null \
  || openssl pkcs12 -legacy -in "$P12" -noout -passin env:P12_PASSWORD 2>/dev/null \
  || { echo "That password doesn't open $(basename "$P12")" >&2; exit 1; }

KEY_ID="$(basename "$P8" .p8)"; KEY_ID="${KEY_ID#AuthKey_}"
read -r -p "App Store Connect Key ID [$KEY_ID]: " INPUT; KEY_ID="${INPUT:-$KEY_ID}"
read -r -p "App Store Connect Issuer ID: " ISSUER_ID
[[ -n "$ISSUER_ID" ]] || { echo "Issuer ID is required" >&2; exit 1; }
xcrun notarytool history --key "$P8" --key-id "$KEY_ID" --issuer "$ISSUER_ID" >/dev/null \
  || { echo "Apple rejected that notary key, Key ID or Issuer ID" >&2; exit 1; }
read -r -s -p "Token with Contents read/write on radkode/homebrew-thermals: " TAP_TOKEN; echo
[[ -n "$TAP_TOKEN" ]] || { echo "Token is required" >&2; exit 1; }

base64 -i "$P12" | gh secret set DEVELOPER_ID_CERT_P12_BASE64 -R "$REPO" --env release
printf '%s' "$P12_PASSWORD" | gh secret set DEVELOPER_ID_CERT_PASSWORD -R "$REPO" --env release
openssl rand -hex 24 | gh secret set KEYCHAIN_PASSWORD -R "$REPO" --env release
base64 -i "$P8" | gh secret set NOTARY_KEY_P8_BASE64 -R "$REPO" --env release
printf '%s' "$KEY_ID" | gh secret set NOTARY_KEY_ID -R "$REPO" --env release
printf '%s' "$ISSUER_ID" | gh secret set NOTARY_KEY_ISSUER -R "$REPO" --env release
printf '%s' "$TAP_TOKEN" | gh secret set TAP_TOKEN -R "$REPO" --env release

echo "Set in $REPO release environment:"
gh secret list -R "$REPO" --env release
