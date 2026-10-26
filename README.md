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

- **Per-core load** comes from the same ticks per logical CPU. Performance and efficiency clusters come from the device tree (`IODeviceTree:/cpus`, `cluster-type` and `logical-cpu-id`) in `Thermals/Sensors/CoreLayout.swift`; without cluster data, cores show as CPU1, CPU2 and so on.
- **Processes** come from `proc_pidinfo` CPU-time deltas in `Thermals/Sensors/ProcessSampler.swift`, summed by name, smoothed, and shown as percent of one core. Only processes the current user may inspect are visible; root and system processes such as `WindowServer` are not. Sampling runs only while the CPU board is open.

Readings refresh every 3, 6 (default) or 10 seconds, set with the UPDATE EVERY tabs in the popover. The LAST 3 MIN meters bin readings into 30 six-second slices by time, so they cover three minutes at any rate.

## Boards

The popover has two boards, switched with the HEAT / CPU tabs or ⌘1 / ⌘2: HEAT (sensors in fixed name order) and CPU (total load, cores by cluster, your top processes). Process rows are ranked by CPU and slide to their new rank. The HEAT board's sensor panel fills the popover's shared height, padding with blank flap rows. Both LAST 3 MIN meters fit their eight rows to the window's range (at least 10°C or 20% load), while each row keeps its absolute heat color.

## Heat bands

`Thermals/Sensors/HeatBand.swift` places every reading on one continuous heat scale (`HeatLevel`, 0 to 1). Band edges sit at fixed positions: 50°C, 75°C and 90°C for temperature, 25%, 60% and 85% for load, so the same color always means the same heat. Bands (COOL, WARM, HOT, BURN) drive the status words and row lamps; color comes from one gradient, `Board.heat`, steel blue through white and amber to red, used by the boards, meters and the menu bar alike. A deeper copy of the gradient keeps contrast on a light menu bar. The menu bar shows temperature, load or both (MENU BAR tabs in the popover); serious or critical thermal pressure raises the temperature to at least HOT.

## Design snapshots

The popover can't be captured with scripted clicks, so an opt-in test renders it with synthetic readings (`Thermals/Views/PreviewMonitors.swift`):

```bash
TEST_RUNNER_SNAPSHOT_DIR=$PWD/.impeccable/shots xcodebuild -project Thermals.xcodeproj -scheme Thermals -destination 'platform=macOS' -derivedDataPath build test
```

This writes `popover-cool.png`, `popover-hot.png`, `popover-no-sensors.png`, `popover-cpu-cool.png` and `popover-cpu-hot.png`. Scroll views draw blank offscreen, so snapshots set `snapshotRendering` to lay the rows out unscrolled. Swift Charts doesn't draw in these offscreen renders, which is one reason the history strip is a `Canvas`.
