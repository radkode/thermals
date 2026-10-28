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
- **Sensor labels** on the HEAT board come from a table of known raw names in `Thermals/Sensors/SensorLabels.swift` (`PMU tdie6` is CPU DIE 6, `gas gauge battery` is BATTERY); a name the table doesn't know shows raw. Sensors sort by label.
- **Fans** come from the SMC (`Thermals/Sensors/SMC.swift`): `FNum` fans, each with `F<n>Ac` current, `F<n>Mn` minimum and `F<n>Mx` maximum RPM. A fan is colored by how far it is through its min to max range. A fan count outside 0 to 8 or a speed outside 0 to 20,000 RPM is treated as unreadable. Fanless Macs report no fans and the HEAT board shows no fan panel; a fan whose speed can't be read shows `--`.
- **CPU load** is the busy share of `host_processor_info` ticks between two samples, summed across cores.
- **Thermal pressure** is `ProcessInfo.thermalState`.

- **Per-core load** comes from the same ticks per logical CPU. Performance and efficiency clusters come from the device tree (`IODeviceTree:/cpus`, `cluster-type` and `logical-cpu-id`) in `Thermals/Sensors/CoreLayout.swift`; without cluster data, cores show as CPU1, CPU2 and so on.
- **Processes** come from deltas of each process's cumulative CPU time, read with the setuid `/bin/ps` (`ps -axo pid=,time=,comm=`) in `Thermals/Sensors/ProcessSampler.swift`, so root and system processes such as `WindowServer` count too. Times are summed by app, smoothed, and shown as percent of one core. `kernel_task` is the one process `ps` can't report; KERNEL + OTHERS is total load minus every sampled process. Sampling runs off the main thread, only while the CPU board is open.
- **Memory** comes from `host_statistics64` in `Thermals/Sensors/MemoryStats.swift`, split the way Activity Monitor splits it: APP (anonymous pages minus purgeable), WIRED, COMPRESSED (pages the compressor occupies) and CACHED (file-backed plus purgeable). USED is app + wired + compressed; FREE is free pages minus speculative, as `vm_stat` reports. Swap is `vm.swapusage`; pressure is `kern.memorystatus_vm_pressure_level` (NORMAL, WARN, CRITICAL). Per-app memory is each process's physical footprint (`proc_pid_rusage`, Activity Monitor's Memory column), grouped under its app like CPU and read only while the RAM board is open.

Temperatures show in °C or °F (TEMPERATURE tabs, defaulting to the system's measurement setting); bands, colors and the meter rows stay defined in Celsius, so only the shown numbers change. Readings refresh every 3, 6 (default) or 10 seconds, set with the UPDATE EVERY tabs in the popover. LAUNCH AT LOGIN registers the app as a login item through `SMAppService.mainApp` (`Thermals/LoginItem.swift`); the tabs read the system's state each time the popover opens, so a change in System Settings shows up there. The LAST 3 MIN meters bin readings into 30 six-second slices by time, so they cover three minutes at any rate. Each reading goes to its nearest slice, so timer jitter can't leave holes, and a slice with no reading (at 10 s, or after the Mac sleeps) holds the previous value.

## Boards

The popover has three boards, switched with the HEAT / CPU / RAM tabs or ⌘1 / ⌘2 / ⌘3: HEAT (sensors in fixed name order), CPU (total load, cores by cluster, the top processes) and RAM (memory used, the breakdown, your top apps by memory). Process and app rows are ranked and slide to their new rank. The HEAT sensor panel and the RAM app panel fill the popover's shared height, padding with blank flap rows. The LAST 3 MIN meters fit their eight rows to the window's range (at least 10°C, 20% load or 10% memory), while each row keeps its absolute heat color.

## Heat bands

`Thermals/Sensors/HeatBand.swift` places every reading on one continuous heat scale (`HeatLevel`, 0 to 1). Band edges sit at fixed positions: 50°C, 75°C and 90°C for temperature, 25%, 60% and 85% for load, 60%, 80% and 90% for memory used, and 10%, 25% and 40% of physical memory for one app, so the same color always means the same heat. Memory used is raised to at least HOT under WARN and BURN under CRITICAL memory pressure. Bands (COOL, WARM, HOT, BURN) drive the status words and row lamps; color comes from one gradient, `Board.heat`, steel blue through white and amber to red, used by the boards, meters and the menu bar alike. A deeper copy of the gradient keeps contrast on a light menu bar. The menu bar shows temperature, load or both (MENU BAR tabs in the popover); serious or critical thermal pressure raises the temperature to at least HOT.

## Design snapshots

The popover can't be captured with scripted clicks, so an opt-in test renders it with synthetic readings (`Thermals/Views/PreviewMonitors.swift`):

```bash
TEST_RUNNER_SNAPSHOT_DIR=$PWD/.impeccable/shots xcodebuild -project Thermals.xcodeproj -scheme Thermals -destination 'platform=macOS' -derivedDataPath build test
```

This writes `popover-cool.png`, `popover-hot.png`, `popover-no-sensors.png`, `popover-cpu-cool.png`, `popover-cpu-hot.png`, `popover-ram-cool.png`, `popover-ram-hot.png`, `popover-ram-unavailable.png` and `popover-hot-fahrenheit.png`. The app icon is drawn the same way, from `AppIcon` in `ThermalsTests/AppIconTests.swift`; `TEST_RUNNER_ICON_DIR=$PWD/Thermals/Assets.xcassets/AppIcon.appiconset` rewrites every size in the asset catalog (build again afterwards to compile them in). Scroll views draw blank offscreen, so snapshots set `snapshotRendering` to lay the rows out unscrolled. Swift Charts doesn't draw in these offscreen renders, which is one reason the history strip is a `Canvas`.

## Website

`thermals.dev` is a single static page in `site/` (`site/index.html`, the app's fonts in `site/fonts/`, the icon), deployed to the Vercel project `thermals` in `jacekradkos-projects`. It ports the app's boards to HTML and runs them on sample readings, labelled as samples and played at four times speed so LAST 3 MIN holds three sample minutes; its colors and band edges mirror `Board.heat` and `HeatLevel`, so change them together. The project is connected to this repository with `site` as its root directory and no build step: a push to `main` that changes `site/` deploys to production, other pushes are skipped (`git diff --quiet HEAD^ HEAD -- .` as the ignored build step), and `www.thermals.dev` redirects to `thermals.dev`. To deploy by hand, link once from the repo root (`vercel link --yes --project thermals --scope jacekradkos-projects`; `.vercel/` and the `.env.local` it pulls are gitignored), then `vercel deploy --prod --scope jacekradkos-projects` from the root, not from `site/`. DOWNLOAD points at the tap's latest release, so a new release needs no site change.

## Releasing

Thermals ships as a Homebrew cask from the public tap `radkode/homebrew-thermals`, which hosts the signed release zips so this repo can stay private.

**To release:** bump `MARKETING_VERSION` in `project.yml` and push to `main`. The Release workflow (`.github/workflows/release.yml`) notices a version with no `v<version>` tag, then on a macOS runner builds Release, signs with the Developer ID and hardened runtime, notarizes and staples, uploads `Thermals-<version>.zip` as a release in the tap, writes `Casks/thermals.rb` there, and tags `v<version>` here. Pushes that don't change the version do nothing. It can also be started by hand from the Actions tab.

**One-time setup:** the workflow needs the secrets listed at its top. `scripts/set-release-secrets.sh <DeveloperID.p12> <AuthKey_KEYID.p8>` sets all of them, prompting for the `.p12` password, the App Store Connect Issuer ID and a fine-grained token with Contents read and write on the tap.

`scripts/release.sh --dry-run` builds, ad-hoc signs and writes the cask to `build/release/<version>/` without notarizing or publishing. Without flags, on a Mac with a Developer ID identity and a `thermals-notary` notarytool profile, the script releases locally the same way.
