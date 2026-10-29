# Performance probe reproduction

These are analysis artifacts for [the macOS performance report](../macos-performance-2026-10-28.md), not app targets or a permanent performance test suite. They use only system frameworks and existing source. Raw captures stay in ignored `build/` directories. Run hardware/process probes with normal user access, not inside a restricted process/sensor sandbox. Do not run concurrent builds during timing captures.

## Pin the assessed source

From the repository root, create the detached worktree if it does not already exist:

```sh
mkdir -p .worktrees
git worktree add --detach .worktrees/performance-dbbbcbc dbbbcbc2634977b785bda64342d9c0093bf08a64
```

The current analysis worktree has an untracked `PerformanceProbeTests.swift` experiment. The hosted experiment failed at launch because of Sparkle library validation. It is not needed by the standalone commands below and must not be committed to the product.

## Reader benchmark

```sh
mkdir -p build/performance-recheck
xcrun swiftc -O -swift-version 6 -parse-as-library \
  -module-cache-path build/performance-recheck/module-cache \
  .worktrees/performance-dbbbcbc/Thermals/Sensors/*.swift \
  docs/performance-2026-10-28/SensorBench.swift \
  -o build/performance-recheck/sensor-bench
build/performance-recheck/sensor-bench > build/performance-recheck/sensors.json
build/performance-recheck/sensor-bench --spaced > build/performance-recheck/hid-spaced.json
```

The normal run records sample counts, success availability and PID/sensor inventory as well as individual wall-time samples and summary statistics. CPU columns use `getrusage` and include loop/autorelease/sleep-call overhead; they are not individual-call CPU traces. The normal run now also includes a 15-call one-second HID series; that extra series was added after the initial baseline and is not present in its `sensors.json`. The separately reported confirmation is the `--spaced` 20-call three-second series. Readers must return real readings before timings are compared; nil fast paths are not valid performance evidence.

## Refresh and offscreen rendering

The standalone probe uses real Monitor and SwiftUI components, an inert updater stub, fixed preview data and 2x image rasterization. Extract the menu component from the pinned app file without copying its `@main` entry point:

```sh
python3 - <<'PY'
from pathlib import Path
source = Path('.worktrees/performance-dbbbcbc/Thermals/ThermalsApp.swift').read_text()
component = source[source.index('struct MenuBarReading:'):]
Path('build/performance-recheck/MenuBarReading.swift').write_text('import SwiftUI\n' + component)
PY
xcrun swiftc -O -D DEBUG -swift-version 6 -parse-as-library \
  -module-cache-path build/performance-recheck/module-cache \
  .worktrees/performance-dbbbcbc/Thermals/Sensors/*.swift \
  .worktrees/performance-dbbbcbc/Thermals/Board/*.swift \
  .worktrees/performance-dbbbcbc/Thermals/Views/*.swift \
  .worktrees/performance-dbbbcbc/Thermals/Monitor.swift \
  .worktrees/performance-dbbbcbc/Thermals/DailyPeak.swift \
  .worktrees/performance-dbbbcbc/Thermals/HeatActivity.swift \
  .worktrees/performance-dbbbcbc/Thermals/HeatAlerts.swift \
  .worktrees/performance-dbbbcbc/Thermals/LoginItem.swift \
  .worktrees/performance-dbbbcbc/Thermals/TemperatureTrend.swift \
  build/performance-recheck/MenuBarReading.swift \
  docs/performance-2026-10-28/ViewBench.swift \
  -o build/performance-recheck/view-bench
PERF_OUTPUT="$PWD/build/performance-recheck" \
  build/performance-recheck/view-bench .worktrees/performance-dbbbcbc/Thermals/Fonts
```

The output is `view-probes.json`. This does not create a live MenuBarExtra or exercise animation. Fixture Monitor instances initialize real hardware readers, but do not schedule timers, request notifications, persist peaks or run Sparkle. Full refresh timings exclude the live monitor's asynchronous peak/activity paths. Image timings measure a fresh graph, not updating a mounted board. Missing images throw. Registration of the bundled fonts is process-local.

## Existing app counters

Find the exact running app PID and verify its version/path before use. Do not accidentally measure a test host or another local copy. Replace `APP_PID` below with that numeric PID:

```sh
xcrun swiftc -O -parse-as-library \
  -module-cache-path build/performance-recheck/module-cache \
  docs/performance-2026-10-28/ProcessBench.swift \
  -o build/performance-recheck/process-bench
build/performance-recheck/process-bench APP_PID 60 > build/performance-recheck/process.json
sample APP_PID 20 2 -file build/performance-recheck/stacks.txt
vmmap -summary APP_PID > build/performance-recheck/vmmap.txt
```

Run the counter window before attaching the sampler. Record visibility, selected board/rate, warmup, power state and other workloads whenever observable. CPU percentage is `100 * delta(cpu_ns) / delta(uptime_ns)`, so 100% means one core. Child CPU must be reported separately. A successful capture needs all requested rows and exit status zero; a disappearing process is a failed capture. These sources do not measure app-specific watts, live frame time or prove a leak.

Record stdout, stderr and producer exit status for every command. The original raw captures and hashes are indexed in [measurements.json](./measurements.json); its summaries are durable even if ignored build artifacts are removed. The commands above rebuild probes without changing application source or bypassing library validation.
