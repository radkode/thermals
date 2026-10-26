# Thermals

A macOS menu bar app that shows how hot your Mac is running. The menu bar shows the hottest CPU die temperature; click it for a three-minute temperature chart, CPU load, macOS thermal pressure, and every sensor reading.

Requires Apple Silicon and macOS 14 or later. Intel Macs are not supported yet.

## Build and run

```bash
brew install xcodegen          # once
xcodegen generate              # regenerates Thermals.xcodeproj from project.yml
open Thermals.xcodeproj        # then Run, or:
xcodebuild -project Thermals.xcodeproj -scheme Thermals -destination 'platform=macOS' -derivedDataPath build test
```

The Xcode project is generated and not committed; edit `project.yml`, then rerun `xcodegen generate`.

## How readings work

- **Temperatures** come from the IOKit HID event system (`Thermals/Sensors/TemperatureSensors.swift`), the same source Stats and iStat Menus use on Apple Silicon. It is a private interface, resolved at runtime with `dlsym`, so the app is distributed outside the Mac App Store and is not sandboxed. If the symbols or sensors are missing, the app shows "unavailable" instead of a number.
- **CPU temperature** is the hottest `PMU tdie*` sensor, falling back to other `PMU` sensors. `tcal` sensors are calibration constants, not temperatures, and are dropped everywhere.
- **CPU load** is the busy share of `host_processor_info` ticks between two samples, summed across cores.
- **Thermal pressure** is `ProcessInfo.thermalState`.

Readings refresh every 2 seconds.

## Heat bands

`Thermals/Sensors/HeatBand.swift` maps a reading to COOL (under 50°C), WARM (under 75°C), HOT (under 90°C) or BURN. Bands drive board colors and row lamps. The menu bar reading stays monochrome until the band is HOT or macOS reports serious or critical thermal pressure.

## Design snapshots

The popover can't be captured with scripted clicks, so an opt-in test renders it with synthetic readings (`Thermals/Views/PreviewMonitors.swift`):

```bash
TEST_RUNNER_SNAPSHOT_DIR=$PWD/.impeccable/shots xcodebuild -project Thermals.xcodeproj -scheme Thermals -destination 'platform=macOS' -derivedDataPath build test
```

This writes `popover-cool.png`, `popover-hot.png` and `popover-no-sensors.png`. Swift Charts doesn't draw in these offscreen renders, which is one reason the history strip is a `Canvas`.
