# Agent Instructions

Thermals is a SwiftUI macOS menu bar app. Product truth lives in [PRODUCT.md](./PRODUCT.md), the visual system in [DESIGN.md](./DESIGN.md) (sidecar `.impeccable/design.json`); build steps and how each reading is sourced live in [README.md](./README.md).

The [2026-10-28 UX audit](./docs/ux-audit-2026-10-28.md) records evidence, limitations and tracked improvement proposals. Its implementation checkpoint records the owner-authorized follow-up scope.

The [2026-10-28 macOS performance analysis](./docs/macos-performance-2026-10-28.md) records measured reader, rendering and process costs, pinned-source scope, profiling limits and prioritized follow-ups. Its [probe directory](./docs/performance-2026-10-28/README.md) contains reproduction commands and durable measurements.

The [2026-10-28 feature assessment](./docs/feature-options-2026-10-28.md) distinguishes shipped and built ideas and records exploratory concepts. Its implementation checkpoint tracks the five owner-selected follow-ups.

The [website performance investigation](./docs/website-performance.md) records rendering constraints, measurements and browser regression checks for `site/`. The [website parity contract](./docs/website-parity.md) maps sample-board semantics to the released app and documents its regression checks.

The [2026-10-29 open-source readiness assessment](./docs/open-source-readiness-2026-10-29.md) records licensing, disclosure, contributor, security and release findings, scan coverage and the remaining publication decisions.

[CONTRIBUTING.md](./CONTRIBUTING.md) defines public contribution and verification expectations. [SECURITY.md](./SECURITY.md) defines private reporting and supported versions. [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md) records dependency licenses and distribution checks.

- `project.yml` is the source of truth for the Xcode project. Never hand-edit or commit `Thermals.xcodeproj`; run `xcodegen generate` after changing targets, settings or file layout.
- Run tests with `xcodebuild -project Thermals.xcodeproj -scheme Thermals -destination 'platform=macOS' -derivedDataPath build test`.
- Sensor access uses private IOKit symbols. Keep that code inside `Thermals/Sensors/` and keep reading-selection logic as pure functions with tests in `ThermalsTests/`.
- The visual world is a split-flap departure board. Colors and fonts live only in `Board` (`Thermals/Board/Board.swift`), shared board pieces in `Thermals/Board/BoardComponents.swift`, and each board in its own view (`HeatBoard`, `CPUBoard`, `RAMBoard`); the direction contract heads `Thermals/Views/PopoverView.swift`. Check UI changes with the snapshot renders described in README.
- Releasing: bump `MARKETING_VERSION` (and `CURRENT_PROJECT_VERSION`) in `project.yml` through a PR and merge to `main`; after preflight, the Release workflow waits for the maintainer to approve the `release` environment deployment, then signs, notarizes, publishes the Homebrew cask and tags. Only the maintainer approves; agents never approve a deployment. Never hand-edit the tap cask, create `v*` tags, or run `scripts/release.sh` without `--dry-run`. Verification, credentials and their expiry, and CI toolchain gotchas: [docs/releasing.md](./docs/releasing.md).
- Track work and file findings as GitHub issues on `radkode/thermals` (`gh issue create`), not DailyDeck. All changes, including maintainer work, require a PR against `main`, passing GitHub Actions `test` and `scan` checks, an up-to-date branch, and resolved review conversations. Do not bypass the main ruleset. Use an isolated worktree when requested.
