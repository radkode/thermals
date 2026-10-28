# Thermals

A macOS menu bar app that shows how hot your Mac is running. The menu bar shows the hottest CPU die temperature; click it for a three-minute temperature chart, system power, CPU load, macOS thermal pressure, and every sensor reading.

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
- **Power** is the SMC's whole-system total, `PSTR`, in watts. A value at or below zero or at 500 W and above is treated as unreadable and shows `--`. There is no CPU figure: on macOS 27 the IOReport `Energy Model` CPU and DRAM counters stay frozen for an unprivileged process, and the SMC's other power keys are undocumented.
- **GPU power** is the IOReport `Energy Model` group's `GPU Energy` counter (`Thermals/Sensors/GPUPower.swift`, private `libIOReport` symbols resolved at runtime), as watts between two samples. It shows `--` until the counter has moved once, so a counter macOS freezes never reads as an idle 0 W; a counter that goes backwards or a result of 500 W or more also shows `--`.
- **CPU load** is the busy share of `host_processor_info` ticks between two samples, summed across cores.
- **Thermal pressure** is `ProcessInfo.thermalState`.

- **Per-core load** comes from the same ticks per logical CPU. Performance and efficiency clusters come from the device tree (`IODeviceTree:/cpus`, `cluster-type` and `logical-cpu-id`) in `Thermals/Sensors/CoreLayout.swift`; without cluster data, cores show as CPU1, CPU2 and so on.
- **Processes** come from deltas of each process's cumulative CPU time, read with the setuid `/bin/ps` (`ps -axo pid=,time=,comm=`) in `Thermals/Sensors/ProcessSampler.swift`, so root and system processes such as `WindowServer` count too. Times are summed by app, smoothed, and shown as percent of one core. `kernel_task` is the one process `ps` can't report; UNMEASURED EST is total load minus every sampled process. It is an estimate, and the smoothed top-five rows are not an additive breakdown of the whole-system headline. Sampling runs off the main thread only while CPU is visible. On entry, two samples one second apart provide an initial estimate independently of the chosen 3/6/10-second refresh rate; subsequent reads use that rate. Leaving CPU or opening Settings cancels the pending result and resets its baseline.
- **Memory** comes from `host_statistics64` in `Thermals/Sensors/MemoryStats.swift`, split the way Activity Monitor splits it: APP (anonymous pages minus purgeable), WIRED, COMPRESSED (pages the compressor occupies) and CACHED (file-backed plus purgeable). USED is app + wired + compressed; FREE is free pages minus speculative, as `vm_stat` reports. Swap is `vm.swapusage`; pressure is `kern.memorystatus_vm_pressure_level` (NORMAL, WARN, CRITICAL). Per-app memory is each process's physical footprint (`proc_pid_rusage`, Activity Monitor's Memory column), grouped under its app like CPU and read only while the RAM board is open.

Temperatures show in °C or °F (TEMPERATURE tabs, defaulting to the system's measurement setting); bands, colors and the meter rows stay defined in Celsius, so only the shown numbers change. Readings refresh every 3, 6 (default) or 10 seconds, set with the UPDATE EVERY tabs in the popover. LAUNCH AT LOGIN registers the app as a login item through `SMAppService.mainApp` (`Thermals/LoginItem.swift`); the tabs read the system's state each time the popover opens, so a change in System Settings shows up there. The LAST 3 MIN meters bin readings into 30 six-second slices by time, so they cover three minutes at any rate. Each reading goes to its nearest slice, so timer jitter can't leave holes, and a slice with no reading (at 10 s, or after the Mac sleeps) holds the previous value.

HEAT ALERTS (on by default) sends one notification when the CPU has been at 85°C or above (a little under BURN, which fan-cooled Macs rarely reach) or macOS has reported serious or critical thermal pressure for 30 seconds, naming the process using the most CPU right then (two `ps` samples two seconds apart, taken only when an alert fires). The logic is `HeatAlertTrigger` in `Thermals/HeatAlerts.swift`: an episode ends only once the reading falls below HOT, alerts stay at least ten minutes apart, and a gap in readings longer than 30 seconds (sleep) restarts the count. Settings separates the requested ON/OFF preference from macOS notification authorization. ALLOW requests permission before an alert; blocked authorization links to notification settings. Without an explicit request, permission is asked at the first alert. Returning to the app refreshes authorization and login-item approval state. A Debug build launched with `-heatAlertTest` (`open build/Build/Products/Debug/Thermals.app --args -heatAlertTest`) sends one alert with the current reading, to check permission and delivery without heating the Mac. The app's notification delegate is the `Updater`, which acts only on its own `update` notification.

PEAK TODAY, at the bottom of HEAT's LAST 3 MIN panel, is the hottest CPU die reading since local midnight (`DailyPeak` in `Thermals/DailyPeak.swift`), saved in user defaults so a relaunch keeps it. Only a reading a whole degree hotter replaces it. When a peak at or above 50°C is set, the busiest process is sampled the same way as for alerts (`ProcessSampler.busiest`), at most every 30 seconds; a rising peak keeps the last name until the next sample. The time is 24-hour (`Format.clock`).

## Boards

The 400pt-wide popover has three boards, switched with HEAT / CPU / RAM or Cmd-1/2/3. Each board uses its natural height, bounded only by the current screen's visible height minus 32pt. Ordinary readings stay fully visible whenever they fit. Only overflow scrolls; tabs, available updates and the footer stay reachable. CPU puts attribution before per-core detail. Settings (Cmd-comma) replaces readings, and Back or Escape returns. Its heading shows the running app’s version and build, read from `Bundle.main` rather than the update feed. Closing the panel stops expensive process/footprint sampling.

The CPU headline is percent of the whole machine; process rows use percent of one core and may exceed 100%. RAM states used and installed GB. Short notes explain OS pressure, estimated process remainder, memory categories and app footprint limits. Names truncate with an ellipsis and preserve full hover/accessibility text. Numeric overflow uses hashes instead of clipping magnitude; fan values fit all five supported RPM digits.

Sources track loading, successful timestamp, unavailable and failed states separately. Failed CPU samples clear old load and reset the counter baseline; missing values never enter history. The footer reports successful-read age, and readings older than max(15 seconds, twice the sampling interval) are marked stale. Menu-bar values from stale selected sources are withheld. History ages against wall time even when sampling stops: 30 nearest six-second buckets cover three minutes, at most one gap holds a preceding sample, and longer gaps stay empty. MIN/MAX means observed extrema, not axis bounds. Eight fixed equal rows span 20–110°C for HEAT (converted labels in Fahrenheit) and 0–100% for CPU/RAM. Both percentage histories share one linear full-palette gradient, so equal values have equal heights and colors. Zero fills no rows; a positive partial bin lights one. Accessibility describes trend direction and gaps.

## Heat bands

`HeatLevel` defines CPU temperature reference boundaries at 50°C, 75°C and 90°C, shown as COOL, WARM, HOT and BURN. They are reference ranges, not hardware safety limits; only CPU die sensors use them. Other sensor types remain neutral. `Board.heat` uses the full blue/white/amber/red ramp. Serious or critical OS pressure raises temperature ink in HEAT, CPU and the menu bar, including when temperature is missing; every menu mode retains an explicit pressure warning.

Outside history charts, CPU, fan and app-memory utilization use LOW, MOD and HIGH and `Board.usage`, which stays within the first 55% of the palette. Load reference points remain 25/60/85%; app-share points are 10/25/40% of installed RAM. Memory-used reference points are 60/80/90%, but high usage under normal or unknown pressure stays below warning colors. Only OS WARN/CRITICAL pressure raises the RAM hero into warning colors. Critical small-text colors clear 4.5:1 against both flap leaves.

## Design snapshots

The popover can't be captured with scripted clicks, so an opt-in test renders it with synthetic readings (`Thermals/Views/PreviewMonitors.swift`):

```bash
TEST_RUNNER_SNAPSHOT_DIR=$PWD/.impeccable/shots xcodebuild -project Thermals.xcodeproj -scheme Thermals -destination 'platform=macOS' -derivedDataPath build test
```

`PopoverSnapshotTests` writes normal HEAT/CPU/RAM, unavailable and stale sources, Fahrenheit, update, login failure/pending, notification authorization with alerts on and off, compact-height, 48-core, long-name, low-temperature/critical-pressure and high-RAM/normal-pressure states. Time, preferences, permissions and sample values are pinned. It also renders each complete board at 356pt to check the width remaining with persistent scrollbars. CPU fixture totals match their cores and process estimates. Layout regressions compare complete ordinary boards at a laptop ceiling against unconstrained renders, cover all ten app rows on a 900pt desktop, and exercise native hosted resizing and overflow.

Scroll views draw blank in ImageRenderer, so only the overflow snapshot path lays content out unscrolled and clips it to the same viewport. Normal snapshots use the real natural-height branch. These renders prove composition and dimensions, not live scrolling, keyboard or VoiceOver behavior. For exact palette assertions, inspect stored bitmap samples with `getPixel`: `colorAt` returns calibrated RGB, so converting it again to sRGB changes already-rendered values. The native automation timeout is tracked in [ai-toolkit #8](https://github.com/jacekradko/ai-toolkit/issues/8). The app icon is drawn separately by `AppIconTests`; `TEST_RUNNER_ICON_DIR=$PWD/Thermals/Assets.xcassets/AppIcon.appiconset` rewrites its sizes. Swift Charts cannot draw in these offscreen renders, so history uses Canvas.

## Website

`thermals.dev` is a single static page in `site/` (`site/index.html`, the app's fonts in `site/fonts/`, the icon), deployed to the Vercel project `thermals` in `jacekradkos-projects`. It ports the app's boards to HTML and runs them on sample readings, labelled as samples and played at four times speed so LAST 3 MIN holds three sample minutes; its labels, pressure handling and palette match the 0.4.3 app, as recorded in the [website parity contract](./docs/website-parity.md). Coordinate future color and band changes with the website delivery scope. The project is connected to this repository with `site` as its root directory and no build step: a push to `main` that changes `site/` deploys to production, other pushes are skipped (`git diff --quiet HEAD^ HEAD -- .` as the ignored build step), and `www.thermals.dev` redirects to `thermals.dev`. To deploy by hand, link once from the repo root (`vercel link --yes --project thermals --scope jacekradkos-projects`; `.vercel/` and the `.env.local` it pulls are gitignored), then `vercel deploy --prod --scope jacekradkos-projects` from the root, not from `site/`. DOWNLOAD points at the tap's latest release, so a new release needs no site change.

The [website performance investigation](./docs/website-performance.md) explains the lightweight flap rendering, visibility-aware sample updates, picker selection and repeatable browser checks. The website loads WOFF2 fonts; the original TTF files remain conversion sources with their OFL license.

## Releasing

Thermals ships as a Homebrew cask from the public tap `radkode/homebrew-thermals`, which hosts the signed release zips so this repo can stay private.

**To release:** bump `MARKETING_VERSION` in `project.yml` and push to `main`. The Release workflow (`.github/workflows/release.yml`) notices a version with no `v<version>` tag, then on a macOS runner builds Release, signs with the Developer ID and hardened runtime, notarizes and staples, uploads `Thermals-<version>.zip` as a release in the tap, writes `Casks/thermals.rb` there, and tags `v<version>` here. Pushes that don't change the version do nothing. It can also be started by hand from the Actions tab.

**In-app updates:** the app embeds Sparkle (`Thermals/Updater.swift`). It checks daily against `appcast.xml` on the tap's latest release; the release script signs both the appcast and zip with an EdDSA key. A found update shows as a NEW VERSION row on the board plus one notification per version; INSTALL hands off to Sparkle's window. Debug builds never check. Bump `CURRENT_PROJECT_VERSION` with every release: Sparkle compares build numbers, so a release with an unchanged build number is never offered.

**One-time setup:** the workflow needs the secrets listed at its top. `scripts/set-release-secrets.sh <DeveloperID.p12> <AuthKey_KEYID.p8>` sets all of them, prompting for the `.p12` password, the App Store Connect Issuer ID and a fine-grained token with Contents read and write on the tap.

`scripts/release.sh --dry-run` builds, ad-hoc signs and writes the cask to `build/release/<version>/` without notarizing or publishing. Without flags, on a Mac with a Developer ID identity and a `thermals-notary` notarytool profile, the script releases locally the same way.
