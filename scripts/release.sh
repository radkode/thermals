#!/usr/bin/env bash
# Builds, signs, notarizes and publishes Thermals to the Homebrew tap. Version comes from project.yml.
# Usage: scripts/release.sh [--dry-run]
#   --dry-run  ad-hoc sign, skip notarization, tagging and publishing; still builds the zip and lints the cask.
# Env: DEVELOPER_ID (signing identity, default: first "Developer ID Application" in the keychain),
#      NOTARY_PROFILE (notarytool keychain profile, default: thermals-notary),
#      TAP_REPO (default: radkode/homebrew-thermals).
set -euo pipefail

cd "$(dirname "$0")/.."
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

TAP_REPO="${TAP_REPO:-radkode/homebrew-thermals}"
NOTARY_PROFILE="${NOTARY_PROFILE:-thermals-notary}"
VERSION="$(sed -n 's/^ *MARKETING_VERSION: *"\(.*\)"$/\1/p' project.yml)"
[[ -n "$VERSION" ]] || { echo "MARKETING_VERSION not found in project.yml" >&2; exit 1; }
TAG="v$VERSION"
OUT="build/release/$VERSION"
APP="$OUT/Thermals.app"
ZIP="$OUT/Thermals-$VERSION.zip"

if $DRY_RUN; then
  IDENTITY="-"
else
  [[ -z "$(git status --porcelain)" ]] || { echo "Working tree is not clean" >&2; exit 1; }
  [[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || { echo "Release from main" >&2; exit 1; }
  if git rev-parse "$TAG" >/dev/null 2>&1; then echo "$TAG already exists; bump MARKETING_VERSION" >&2; exit 1; fi
  IDENTITY="${DEVELOPER_ID:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)}"
  [[ -n "$IDENTITY" ]] || { echo "No Developer ID Application identity in the keychain" >&2; exit 1; }
  xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null || { echo "notarytool profile '$NOTARY_PROFILE' missing; run: xcrun notarytool store-credentials $NOTARY_PROFILE" >&2; exit 1; }
fi

echo "==> Building Thermals $VERSION"
rm -rf "$OUT" && mkdir -p "$OUT"
xcodegen generate >/dev/null
xcodebuild -project Thermals.xcodeproj -scheme Thermals -configuration Release -destination 'platform=macOS' \
  -derivedDataPath build/release/derived CODE_SIGN_IDENTITY="-" build >"$OUT/build.log" 2>&1 \
  || { tail -30 "$OUT/build.log" >&2; exit 1; }
ditto build/release/derived/Build/Products/Release/Thermals.app "$APP"

echo "==> Signing with: $IDENTITY"
if [[ "$IDENTITY" == "-" ]]; then
  codesign --force --options runtime --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi
codesign --verify --strict --deep --verbose=2 "$APP"

ditto -c -k --keepParent "$APP" "$ZIP"
if ! $DRY_RUN; then
  echo "==> Notarizing"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  spctl --assess --type execute --verbose=2 "$APP"
  rm "$ZIP" && ditto -c -k --keepParent "$APP" "$ZIP"
fi
SHA="$(shasum -a 256 "$ZIP" | cut -d' ' -f1)"

CASK="$OUT/thermals.rb"
cat >"$CASK" <<CASK
cask "thermals" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/$TAP_REPO/releases/download/v#{version}/Thermals-#{version}.zip"
  name "Thermals"
  desc "Menu bar temperature and CPU load monitor"
  homepage "https://github.com/$TAP_REPO"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "Thermals.app"

  zap trash: "~/Library/Preferences/com.radkode.thermals.plist"
end
CASK
ruby -c "$CASK" >/dev/null
echo "==> Built $ZIP ($SHA)"

if $DRY_RUN; then
  echo "==> Dry run: skipped notarization, tag, release and cask publish. Cask: $CASK"
  exit 0
fi

echo "==> Publishing $TAG to $TAP_REPO"
gh release create "$TAG" "$ZIP" -R "$TAP_REPO" --title "Thermals $VERSION" --notes "Signed and notarized Thermals $VERSION for Apple Silicon, macOS 14 or later."
EXISTING_SHA="$(gh api "repos/$TAP_REPO/contents/Casks/thermals.rb" --jq .sha 2>/dev/null || true)"
gh api --method PUT "repos/$TAP_REPO/contents/Casks/thermals.rb" \
  -f message="thermals $VERSION" -f content="$(base64 <"$CASK")" ${EXISTING_SHA:+-f sha="$EXISTING_SHA"} >/dev/null
git tag "$TAG" && git push origin "$TAG"
echo "==> Released. Install: brew install --cask ${TAP_REPO%%/*}/${TAP_REPO#*/homebrew-}/thermals"
