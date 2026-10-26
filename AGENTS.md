# Agent Instructions

Thermals is a SwiftUI macOS menu bar app. Product truth lives in [PRODUCT.md](./PRODUCT.md), the visual system in [DESIGN.md](./DESIGN.md) (sidecar `.impeccable/design.json`); build steps and how each reading is sourced live in [README.md](./README.md).

- `project.yml` is the source of truth for the Xcode project. Never hand-edit or commit `Thermals.xcodeproj`; run `xcodegen generate` after changing targets, settings or file layout.
- Run tests with `xcodebuild -project Thermals.xcodeproj -scheme Thermals -destination 'platform=macOS' -derivedDataPath build test`.
- Sensor access uses private IOKit symbols. Keep that code inside `Thermals/Sensors/` and keep reading-selection logic as pure functions with tests in `ThermalsTests/`.
- The visual world is a split-flap departure board. Colors and fonts live only in `Board` (`Thermals/Board/Board.swift`), shared board pieces in `Thermals/Board/BoardComponents.swift`, and each board in its own view (`HeatBoard`, `CPUBoard`); the direction contract heads `Thermals/Views/PopoverView.swift`. Check UI changes with the snapshot renders described in README.
- File findings about this repo to DailyDeck with `repo: "radkode/thermals"`.
