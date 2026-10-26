#!/usr/bin/env bash
# Sets the GitHub Actions secrets the release workflow needs. Run it yourself in a terminal; it prompts for
# passwords and IDs and never prints or stores a secret value.
# Usage: scripts/set-release-secrets.sh <DeveloperID.p12> <AuthKey_KEYID.p8>
set -euo pipefail

REPO="${REPO:-radkode/thermals}"
P12="${1:?usage: $0 <DeveloperID.p12> <AuthKey_KEYID.p8>}"
P8="${2:?usage: $0 <DeveloperID.p12> <AuthKey_KEYID.p8>}"
[[ -f "$P12" ]] || { echo "Not found: $P12" >&2; exit 1; }
[[ -f "$P8" ]] || { echo "Not found: $P8" >&2; exit 1; }

read -r -s -p "Password for $(basename "$P12"): " P12_PASSWORD; echo
openssl pkcs12 -in "$P12" -noout -passin env:P12_PASSWORD 2>/dev/null \
  || openssl pkcs12 -legacy -in "$P12" -noout -passin env:P12_PASSWORD 2>/dev/null \
  || { echo "That password doesn't open $(basename "$P12")" >&2; exit 1; }
export P12_PASSWORD

KEY_ID="$(basename "$P8" .p8)"; KEY_ID="${KEY_ID#AuthKey_}"
read -r -p "App Store Connect Key ID [$KEY_ID]: " INPUT; KEY_ID="${INPUT:-$KEY_ID}"
read -r -p "App Store Connect Issuer ID: " ISSUER_ID
[[ -n "$ISSUER_ID" ]] || { echo "Issuer ID is required" >&2; exit 1; }
read -r -s -p "Token with Contents read/write on radkode/homebrew-thermals: " TAP_TOKEN; echo
[[ -n "$TAP_TOKEN" ]] || { echo "Token is required" >&2; exit 1; }

base64 -i "$P12" | gh secret set DEVELOPER_ID_CERT_P12_BASE64 -R "$REPO"
printf '%s' "$P12_PASSWORD" | gh secret set DEVELOPER_ID_CERT_PASSWORD -R "$REPO"
openssl rand -hex 24 | gh secret set KEYCHAIN_PASSWORD -R "$REPO"
base64 -i "$P8" | gh secret set NOTARY_KEY_P8_BASE64 -R "$REPO"
printf '%s' "$KEY_ID" | gh secret set NOTARY_KEY_ID -R "$REPO"
printf '%s' "$ISSUER_ID" | gh secret set NOTARY_KEY_ISSUER -R "$REPO"
printf '%s' "$TAP_TOKEN" | gh secret set TAP_TOKEN -R "$REPO"

echo "Set on $REPO:"
gh secret list -R "$REPO"
