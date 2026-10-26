# Agent Instructions

Thermals is a SwiftUI macOS menu bar app. Product truth lives in [PRODUCT.md](./PRODUCT.md); build steps and how each reading is sourced live in [README.md](./README.md).

- `project.yml` is the source of truth for the Xcode project. Never hand-edit or commit `Thermals.xcodeproj`; run `xcodegen generate` after changing targets, settings or file layout.
- Run tests with `xcodebuild -project Thermals.xcodeproj -scheme Thermals -destination 'platform=macOS' -derivedDataPath build test`.
- Sensor access uses private IOKit symbols. Keep that code inside `Thermals/Sensors/` and keep reading-selection logic as pure functions with tests in `ThermalsTests/`.
- File findings about this repo to DailyDeck with `repo: "radkode/thermals"`.
