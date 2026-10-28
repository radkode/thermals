#!/usr/bin/env bash
# Builds, signs, notarizes and publishes Thermals to the Homebrew tap. Version comes from project.yml.
# Usage: scripts/release.sh [--dry-run | --ci]
#   --dry-run  ad-hoc sign, skip notarization, tagging and publishing; still builds the zip and the cask.
#   --ci       run from the release workflow on a main commit: publishes, then tags v<version> on HEAD.
# Env: DEVELOPER_ID (signing identity, default: first "Developer ID Application" in the keychain),
#      NOTARY_KEY_PATH + NOTARY_KEY_ID + NOTARY_KEY_ISSUER (App Store Connect API key), else
#      NOTARY_PROFILE (notarytool keychain profile, default: thermals-notary),
#      TAP_REPO (default: radkode/homebrew-thermals); gh needs write access to it (GH_TOKEN in CI),
#      SPARKLE_ED_PRIVATE_KEY (update signing key, else the keychain's "thermals" Sparkle account).
set -euo pipefail

cd "$(dirname "$0")/.."
DRY_RUN=false
CI_MODE=false
case "${1:-}" in
  --dry-run) DRY_RUN=true ;;
  --ci) CI_MODE=true ;;
  "") ;;
  *) echo "Unknown option: $1" >&2; exit 2 ;;
esac

TAP_REPO="${TAP_REPO:-radkode/homebrew-thermals}"
NOTARY_PROFILE="${NOTARY_PROFILE:-thermals-notary}"
VERSION="$(sed -n 's/^ *MARKETING_VERSION: *"\(.*\)"$/\1/p' project.yml)"
BUILD="$(sed -n 's/^ *CURRENT_PROJECT_VERSION: *"\(.*\)"$/\1/p' project.yml)"
[[ -n "$VERSION" && -n "$BUILD" ]] || { echo "MARKETING_VERSION or CURRENT_PROJECT_VERSION not found in project.yml" >&2; exit 1; }
TAG="v$VERSION"
OUT="build/release/$VERSION"
APP="$OUT/Thermals.app"
ZIP="$OUT/Thermals-$VERSION.zip"
APPCAST="$OUT/appcast.xml"
SPARKLE_BIN=build/release/derived/SourcePackages/artifacts/sparkle/Sparkle/bin

if [[ -n "${NOTARY_KEY_PATH:-}" ]]; then
  NOTARY_AUTH=(--key "$NOTARY_KEY_PATH" --key-id "${NOTARY_KEY_ID:?}" --issuer "${NOTARY_KEY_ISSUER:?}")
else
  NOTARY_AUTH=(--keychain-profile "$NOTARY_PROFILE")
fi

if $DRY_RUN; then
  IDENTITY="-"
else
  [[ -z "$(git status --porcelain)" ]] || { echo "Working tree is not clean" >&2; exit 1; }
  $CI_MODE || [[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || { echo "Release from main" >&2; exit 1; }
  if git rev-parse "$TAG" >/dev/null 2>&1; then echo "$TAG already exists; bump MARKETING_VERSION" >&2; exit 1; fi
  [[ "$(gh api "repos/$TAP_REPO" --jq .permissions.push 2>/dev/null)" == "true" ]] \
    || { echo "gh can't write to $TAP_REPO; check the token (TAP_TOKEN in CI)" >&2; exit 1; }
  if gh release view "$TAG" -R "$TAP_REPO" >/dev/null 2>&1; then echo "$TAP_REPO already has a $TAG release" >&2; exit 1; fi
  PREV_TAG="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)"
  PREV_BUILD="$(git show "$PREV_TAG:project.yml" 2>/dev/null | sed -n 's/^ *CURRENT_PROJECT_VERSION: *"\(.*\)"$/\1/p')"
  [[ -z "$PREV_BUILD" ]] || (( BUILD > PREV_BUILD )) \
    || { echo "CURRENT_PROJECT_VERSION $BUILD must be above $PREV_TAG's $PREV_BUILD, or Sparkle won't offer it" >&2; exit 1; }
  IDENTITY="${DEVELOPER_ID:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)}"
  [[ -n "$IDENTITY" ]] || { echo "No Developer ID Application identity in the keychain" >&2; exit 1; }
  xcrun notarytool history "${NOTARY_AUTH[@]}" >/dev/null || { echo "notarytool credentials not usable" >&2; exit 1; }
fi

echo "==> Building Thermals $VERSION"
rm -rf "$OUT" && mkdir -p "$OUT"
xcodegen generate >/dev/null
xcodebuild -project Thermals.xcodeproj -scheme Thermals -configuration Release -destination 'platform=macOS' \
  -derivedDataPath build/release/derived CODE_SIGN_IDENTITY="-" build >"$OUT/build.log" 2>&1 \
  || { tail -30 "$OUT/build.log" >&2; exit 1; }
ditto build/release/derived/Build/Products/Release/Thermals.app "$APP"

echo "==> Signing with: $IDENTITY"
sign() {
  if [[ "$IDENTITY" == "-" ]]; then
    codesign --force --options runtime --sign - "$@"
  else
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$@"
  fi
}
# Sparkle's nested code is signed inside out, without --deep, so the Downloader keeps its entitlements.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
sign "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
sign "$SPARKLE/Versions/B/Autoupdate"
sign "$SPARKLE/Versions/B/Updater.app"
sign "$SPARKLE"
sign "$APP"
codesign --verify --strict --deep --verbose=2 "$APP"

ditto -c -k --keepParent "$APP" "$ZIP"
if ! $DRY_RUN; then
  echo "==> Notarizing"
  xcrun notarytool submit "$ZIP" "${NOTARY_AUTH[@]}" --wait
  xcrun stapler staple "$APP"
  spctl --assess --type execute --verbose=2 "$APP"
  rm "$ZIP" && ditto -c -k --keepParent "$APP" "$ZIP"
fi
SHA="$(shasum -a 256 "$ZIP" | cut -d' ' -f1)"

# The app's Sparkle reads this feed from the latest tap release and checks the zip against SUPublicEDKey.
if [[ -n "${SPARKLE_ED_PRIVATE_KEY:-}" ]]; then
  ENCLOSURE="$(printf '%s' "$SPARKLE_ED_PRIVATE_KEY" | "$SPARKLE_BIN/sign_update" --ed-key-file - "$ZIP")"
else
  ENCLOSURE="$("$SPARKLE_BIN/sign_update" --account thermals "$ZIP")"
fi
cat >"$APPCAST" <<APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Thermals</title>
    <item>
      <title>Thermals $VERSION</title>
      <pubDate>$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure url="https://github.com/$TAP_REPO/releases/download/$TAG/Thermals-$VERSION.zip" type="application/octet-stream" $ENCLOSURE/>
    </item>
  </channel>
</rss>
APPCAST
xmllint --noout "$APPCAST"
if [[ -n "${SPARKLE_ED_PRIVATE_KEY:-}" ]]; then
  printf '%s' "$SPARKLE_ED_PRIVATE_KEY" | "$SPARKLE_BIN/sign_update" --ed-key-file - "$APPCAST"
else
  "$SPARKLE_BIN/sign_update" --account thermals "$APPCAST"
fi
xmllint --noout "$APPCAST"
# A zip signed with any other key than the app's SUPublicEDKey would be refused by every installed copy.
OPENSSL="$(brew --prefix openssl@3)/bin/openssl"
KEYS="$(mktemp -d)"
{ printf '302a300506032b6570032100' | xxd -r -p; plutil -extract SUPublicEDKey raw "$APP/Contents/Info.plist" | base64 -D; } >"$KEYS/public.der"
sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' "$APPCAST" | base64 -D >"$KEYS/signature"
"$OPENSSL" pkeyutl -verify -pubin -inkey "$KEYS/public.der" -keyform DER -rawin -in "$ZIP" -sigfile "$KEYS/signature" >/dev/null \
  || { rm -rf "$KEYS"; echo "The update signature doesn't match SUPublicEDKey; check SPARKLE_ED_PRIVATE_KEY" >&2; exit 1; }
rm -rf "$KEYS"

CASK="$OUT/thermals.rb"
cat >"$CASK" <<CASK
cask "thermals" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/$TAP_REPO/releases/download/v#{version}/Thermals-#{version}.zip"
  name "Thermals"
  desc "Menu bar temperature, CPU and memory monitor"
  homepage "https://github.com/$TAP_REPO"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "Thermals.app"

  uninstall quit: "com.radkode.thermals"

  zap trash: "~/Library/Preferences/com.radkode.thermals.plist"
end
CASK
ruby -c "$CASK" >/dev/null
echo "==> Built $ZIP ($SHA)"

if $DRY_RUN; then
  echo "==> Dry run: skipped notarization, tag, release and cask publish. Cask: $CASK, appcast: $APPCAST"
  exit 0
fi

echo "==> Publishing $TAG to $TAP_REPO"
gh release create "$TAG" "$ZIP" "$APPCAST" -R "$TAP_REPO" --title "Thermals $VERSION" --notes "Signed and notarized Thermals $VERSION for Apple Silicon, macOS 14 or later."
EXISTING_SHA="$(gh api "repos/$TAP_REPO/contents/Casks/thermals.rb" --jq .sha 2>/dev/null || true)"
gh api --method PUT "repos/$TAP_REPO/contents/Casks/thermals.rb" \
  -f message="thermals $VERSION" -f content="$(base64 <"$CASK")" ${EXISTING_SHA:+-f sha="$EXISTING_SHA"} >/dev/null
git tag "$TAG" && git push origin "$TAG"
echo "==> Released. Install: brew install --cask ${TAP_REPO%%/*}/${TAP_REPO#*/homebrew-}/thermals"
