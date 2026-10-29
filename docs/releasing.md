# Releasing Thermals

Thermals ships as a Homebrew cask from the public tap [`radkode/homebrew-thermals`](https://github.com/radkode/homebrew-thermals), which hosts the signed release zips and the stable Sparkle update feed. Users install with `brew install --cask radkode/thermals/thermals` and update with `brew upgrade --cask thermals`.

## Cutting a release

1. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml` in a pull request. Merge only after the required native and secret-scan checks pass on the current base and review conversations are resolved. Sparkle offers an update only when the build number goes up.
2. `.github/workflows/release.yml` runs on main pushes that touch `project.yml`. Its `check` job skips versions that already have a `v<version>` tag. For an untagged version, secret-free preflight tests and license checks must pass before the `release` job can access signing credentials. That job runs `scripts/release.sh --ci` on a `macos-26` runner: Release build, Developer ID signing with hardened runtime, notarization and stapling, then the zip and appcast are signed for Sparkle, both go up as a release in the tap, `Casks/thermals.rb` is rewritten there, and `v<version>` is tagged here.
3. Verify:
   - `gh run list -R radkode/thermals --workflow release.yml --limit 3`
   - `gh release list -R radkode/homebrew-thermals`
   - `brew update && brew upgrade --cask radkode/thermals/thermals`, then `spctl --assess --type execute -vv /Applications/Thermals.app` must print `source=Notarized Developer ID`.

On an already tagged version, `gh workflow run release.yml -R radkode/thermals --ref main` runs a secret-free build and test preflight on the release runner. On an untagged version, the same command starts a release, so check the current version and tag first.

Don't:
- hand-edit the tap's `Casks/thermals.rb`;
- create `v*` tags by hand (a tag makes the workflow skip that version);
- run `scripts/release.sh` without `--dry-run` from an agent session.

`scripts/release.sh --dry-run` builds and ad-hoc signs the app archive, checks its license resources, and writes the cask to `build/release/<version>/`. It exits before any update signing or appcast generation and needs no production keys. It does not notarize, tag or publish. This is a packaging check only: ad-hoc Release launch can fail library validation with Sparkle (#61). Use Debug for development.

The cask's `uninstall quit:` makes `brew upgrade` quit a running Thermals and reopen the new build. Without it the old process keeps running from a replaced bundle, and `SMAppService` refuses every register and unregister (`Register (<private>) error: 1` in the unified log). Current builds show the refusal on the board and log the error. To see those errors, use `/usr/bin/log show`, because zsh's builtin `log` shadows it.

## Toolchain gap

CI builds with the default Xcode on the `macos-26` image (printed at the top of the build step), which is older than the Xcode used locally (27.x). The workflow pins `actions/checkout` to a commit and verifies the SHA-256 of XcodeGen 2.46.0 before running it. Review both pins when updating those tools. Code that compiles locally can fail only in CI. The first 0.1.0 run on `macos-15` (Xcode 16.4) timed out type-checking one long expression in `PreviewMonitors.swift`. Long literal-heavy expressions should be split into typed `let`s.

## Credentials

The workflow's secrets live in the `release` environment, which accepts deployments only from `main`. Keep original credentials, recovery instructions, ownership and expiry records in the maintainer's private credential store, not in this repository. To rotate the certificate, notary key and tap token, run `scripts/set-release-secrets.sh <DeveloperID.p12> <AuthKey_KEYID.p8>` in a terminal. It validates the certificate password and notary key before setting them.

| Secrets | Purpose |
|---|---|
| `DEVELOPER_ID_CERT_P12_BASE64`, `DEVELOPER_ID_CERT_PASSWORD` | Developer ID Application certificate and its export password |
| `NOTARY_KEY_P8_BASE64`, `NOTARY_KEY_ID`, `NOTARY_KEY_ISSUER` | App Store Connect notarization key and identifiers |
| `TAP_TOKEN` | Fine-grained token with Contents read/write on the release tap only |
| `KEYCHAIN_PASSWORD` | Random password for the runner's temporary keychain |
| `SPARKLE_ED_PRIVATE_KEY` | Private key corresponding to the shipped app's public update-verification key |

The setup helper sets the first seven secrets. Set the Sparkle key separately using the procedure below. Check expiry and least privilege in the private inventory before every release. Do not put private keys, token values, private inventory locations or recovery details in issues, logs or repository files.

Automatic releases from `main` are an explicit maintainer choice. The environment restricts branches but has no required reviewer, so a merged workflow change can change the job that receives signing and publishing secrets. Main requires PRs and passing CI with no bypass actors, but CI does not establish that a workflow change is trustworthy. Review release changes carefully and retain strict account and repository administration access. The ordinary native-test and secret-scan workflows receive no release secrets and use read-only token permissions. Pinned inputs do not protect against a compromised main writer. Public repositories can add environment reviewers, but changing the accepted automatic-release boundary requires an explicit decision; see [#9](https://github.com/radkode/thermals/issues/9).

## Gotchas we hit setting this up

- **Xcode's "Developer ID Application" option was greyed out** for the account holder. Workaround: generate a CSR with Certificate Assistant, then create the certificate at developer.apple.com › Certificates › + › Developer ID Application (G2 Sub-CA) and double-click the downloaded `.cer`. On macOS 27, Keychain Access no longer has the Certificate Assistant menu; the app is at `/System/Library/CoreServices/Certificate Assistant.app`.
- **Keychain Access exports `.p12` files with legacy RC2-40 encryption.** OpenSSL 3 and later read them only with `-legacy`; the helper falls back to it. macOS `security import` (used in CI) reads them fine.
- **HTTP 401 from the tap** means `TAP_TOKEN` is invalid (in our case a token pasted twice). `scripts/release.sh` now checks write access to the tap before building. A fine-grained token is shown only once; regenerate it if lost.

## In-app updates (Sparkle)

The app reads `https://github.com/radkode/homebrew-thermals/releases/latest/download/appcast.xml` (`SUFeedURL` in `project.yml`), requires a signed feed (`SURequireSignedFeed`) and verifies each archive before extraction (`SUVerifyUpdateBeforeExtraction`). [Sparkle requires both settings together](https://sparkle-project.org/documentation/customization/). It only installs a zip whose EdDSA signature matches `SUPublicEDKey`. Both signatures come from the private key in the login keychain under the Sparkle account `thermals`, and in CI from the `SPARKLE_ED_PRIVATE_KEY` secret. Keep its backup and recovery instructions in the private credential store (`generate_keys --account thermals -f <file>` restores a saved key to a keychain). Losing it means shipped copies can't be updated in-app. To set or rotate the secret from the keychain (resolve packages first so `build/SourcePackages` exists; `generate_keys -x` refuses a path that already exists, so it writes into a fresh directory):

```bash
(D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
  build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys --account thermals -x "$D/key" \
    && gh secret set SPARKLE_ED_PRIVATE_KEY -R radkode/thermals --env release < "$D/key")
```

The release script refuses to publish when `CURRENT_PROJECT_VERSION` isn't above the last tag's, or when the zip's signature doesn't verify against the app's `SUPublicEDKey` (checked with Homebrew's `openssl@3`; the system LibreSSL can't verify Ed25519). It re-signs Sparkle's nested code (XPC services, Autoupdate, Updater.app, the framework) inside out with the Developer ID before signing the app, because notarization rejects the ad-hoc signatures Xcode leaves on them.

To test an update end to end without releasing, build the release script's dry-run app twice, set `SUFeedURL` in both copies to `http://127.0.0.1:<port>/appcast.xml`, give the second a higher `CFBundleVersion`, re-sign both with the Developer ID, then zip the second and sign the zip and one-item appcast with `sign_update --account thermals` before serving them. Back up `com.radkode.thermals` defaults before setting `SUHasLaunchedBefore` true and `SULastCheckTime` in the past so the first copy checks at launch; restore them afterwards. A Thermals process is a menu bar app, so `Updater.install` activates it first, otherwise Sparkle's window opens behind other apps.

For a published-feed install test, copy the published app to an isolated directory, lower only its `CFBundleVersion`, and re-sign that copy with the same Developer ID. Stop the installed app and back up its defaults first. Set `SUHasLaunchedBefore` and `SUAutomaticallyUpdate` to true and `SULastCheckTime` in the past, then launch the copy. Sparkle verifies the signed appcast and archive, downloads and extracts the update, and installs it when the copy quits. Verify the replaced bundle's build number, recursive signature, stapled ticket, Gatekeeper result and Team ID, then relaunch it. Stop the copy, restore the saved defaults and delete any test-only key that `defaults import` leaves behind, then restart the installed app. Run signature and Gatekeeper checks outside the workspace sandbox; restricted keychain access can produce false verification failures.

The published 0.3.0 app cannot start Sparkle because it lacks `SUVerifyUpdateBeforeExtraction`. Users on that build must upgrade through Homebrew to 0.3.1 or later. The 0.3.1 recovery release omitted `auto_updates true` so older Homebrew clients would still offer the upgrade. Starting with 0.3.2, the cask declares `auto_updates true`; [current Homebrew](https://docs.brew.sh/FAQ#how-does-brew-upgrade-handle-apps-that-update-themselves) compares the installed bundle version for this versioned self-updating cask. Check `brew outdated --cask` before and after an in-app update to verify the upgrade boundary.
