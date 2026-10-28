# Agent Instructions

Thermals is a SwiftUI macOS menu bar app. Product truth lives in [PRODUCT.md](./PRODUCT.md), the visual system in [DESIGN.md](./DESIGN.md) (sidecar `.impeccable/design.json`); build steps and how each reading is sourced live in [README.md](./README.md).

The [2026-10-28 UX audit](./docs/ux-audit-2026-10-28.md) records evidence, limitations and tracked improvement proposals. Its implementation checkpoint records the owner-authorized follow-up scope.

The [website performance investigation](./docs/website-performance.md) records rendering constraints, measurements and browser regression checks for `site/`. The [website parity contract](./docs/website-parity.md) maps sample-board semantics to the released app and documents its regression checks.

- `project.yml` is the source of truth for the Xcode project. Never hand-edit or commit `Thermals.xcodeproj`; run `xcodegen generate` after changing targets, settings or file layout.
- Run tests with `xcodebuild -project Thermals.xcodeproj -scheme Thermals -destination 'platform=macOS' -derivedDataPath build test`.
- Sensor access uses private IOKit symbols. Keep that code inside `Thermals/Sensors/` and keep reading-selection logic as pure functions with tests in `ThermalsTests/`.
- The visual world is a split-flap departure board. Colors and fonts live only in `Board` (`Thermals/Board/Board.swift`), shared board pieces in `Thermals/Board/BoardComponents.swift`, and each board in its own view (`HeatBoard`, `CPUBoard`, `RAMBoard`); the direction contract heads `Thermals/Views/PopoverView.swift`. Check UI changes with the snapshot renders described in README.
- Releasing is automatic: bump `MARKETING_VERSION` (and `CURRENT_PROJECT_VERSION`) in `project.yml` and push to `main`; the Release workflow signs, notarizes, publishes the Homebrew cask and tags. Never hand-edit the tap cask, create `v*` tags, or run `scripts/release.sh` without `--dry-run`. Verification, credentials and their expiry, and CI toolchain gotchas: [docs/releasing.md](./docs/releasing.md).
- Track work and file findings as GitHub issues on `radkode/thermals` (`gh issue create`), not DailyDeck. Work lands straight on `main`; there are no PRs.
