# Contributing

Outside pull requests are welcome. For a substantial behavior or architecture change, open an issue first so we can agree on the scope. Keep each change focused and describe the problem, result and verification. Contributions are made under the project's [MIT license](./LICENSE); retain dependency and asset licenses.

The maintainer may land changes directly on `main`. That internal workflow does not require outside contributors to have write access. Fork the repository and open your PR against `main`. Do not change the app version or release workflow unless the task specifically calls for it.

## Build and test

Use an Apple Silicon Mac with macOS 14 or later, full Xcode selected with `xcode-select`, and XcodeGen 2.46.0. The build is verified with Xcode 26.6 in CI and Xcode 27.1 locally. CI uses the default Xcode on GitHub's `macos-26` image and prints its version; earlier Xcode versions have not been validated. Runtime macOS support does not imply that every older Xcode can build the source.

```sh
brew install xcodegen
xcodebuild -version
xcodegen --version
xcodegen generate
xcodebuild -project Thermals.xcodeproj -scheme Thermals \
  -destination 'platform=macOS' -derivedDataPath build test
scripts/check-licenses.sh build/Build/Products/Debug/Thermals.app
```

Homebrew installs its current XcodeGen version; use 2.46.0 when reproducing CI. The [native workflow](./.github/workflows/test.yml) shows the pinned download and checksum. Package resolution downloads the public Sparkle artifact. Debug builds use ad-hoc signing and disable update checks. No Apple Developer membership, release certificate, notary key, tap token or Sparkle private key is needed.

Open `Thermals.xcodeproj` and Run the Debug scheme, or launch `build/Build/Products/Debug/Thermals.app` after building. Quit the installed Thermals first to avoid two indistinguishable menu items and shared preferences. A development build uses the same defaults domain as the installed app; use a separate macOS account if you need isolated preferences and recordings.

Edit `project.yml`, not the generated Xcode project. Keep private hardware interfaces inside `Thermals/Sensors/` and test reading-selection logic as pure functions. Use the [README](./README.md) for reading semantics and snapshot instructions and [AGENTS.md](./AGENTS.md) for the repository's documentation index. No personal agent harness, plugins or external task manager is required.

## Local packaging and forks

```sh
scripts/release.sh --dry-run
python3 scripts/test-release-dry-run.py
```

The dry run builds and ad-hoc signs an app archive and writes a cask under `build/release/<version>/`. It does not access production signing keys, create an appcast, notarize, tag or publish. It is a packaging check, not a supported distribution or launch test. Ad-hoc Release builds can fail macOS library validation when loading Sparkle; [#61](https://github.com/radkode/thermals/issues/61) tracks that separately. Use Debug for local development. Production releases retain hardened runtime and signed update verification.

Before distributing a fork, choose a separate bundle identifier in `project.yml`, your own signing identity, and your own Sparkle feed and public verification key, or disable the updater in your fork. The default Release configuration trusts the official feed and uses `com.radkode.thermals`; do not distribute a modified app under that identity. Never request or copy the maintainer's private signing keys. Preserve the [third-party notices](./THIRD_PARTY_NOTICES.md).

## Website checks

The website is static and has no package install or build step. The committed checks are functions intended for [Playwright CLI](https://github.com/microsoft/playwright-cli), not standalone Node scripts. Install that tool and its Chrome browser prerequisites separately, record the version used, serve `site/` locally, and follow [the website verification commands](./docs/website-parity.md#verification). These browser checks are currently manual; native CI does not run them. Changes to `site/` on main deploy to production, so keep website work scoped and reviewed.

## Reports and verification

Bug reports should include the app version/build, macOS version, chip model, expected and actual behavior, and reproducible steps. Remove unrelated process names or other personal details from logs and screenshots. For vulnerabilities use [SECURITY.md](./SECURITY.md), not a public issue.

Native changes run tests and license-resource checks on main and PRs without release secrets. Secret scanning runs on all main pushes and PRs. Run the relevant local checks before proposing a change and report limitations honestly. Hardware support depends on private macOS interfaces; one machine's result is not proof for every Apple Silicon model.

## Dependency maintenance

Dependabot proposes weekly updates to GitHub Actions references. Sparkle is pinned in XcodeGen's `project.yml`, not a tracked SwiftPM manifest; Dependabot is not relied on to update it. When maintaining dependencies, compare the pinned Sparkle version with [upstream releases and advisories](https://github.com/sparkle-project/Sparkle), update its complete notices, and run native tests plus signed-update verification before release. Check pinned XcodeGen and Gitleaks versions/checksums in the workflows at the same time. Review upstream changes before accepting new pins; never replace checksum verification with an unchecked download.
