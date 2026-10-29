# macOS performance analysis, 2026-10-28

Tracking: [#59](https://github.com/radkode/thermals/issues/59). Scope is analysis, measurement and follow-up filing. No application optimization or release is included.

## Assessment

Thermals has low observed average CPU use, but blocks its main actor on hardware and process queries. Responsiveness is the first optimization target. In an optimized component probe, a complete synchronous refresh took **39.0 ms median**, or **60.0 ms with RAM process footprints enabled**. Temperature HID reads dominate elapsed time; RAM adds a process-count-dependent scan. A stack sample of the installed release independently confirms the HID IPC on its main thread.

Rendering deserves a second investigation. Creating and rasterizing a complete board at 2x took **74.9–93.7 ms median**, or **193.5 ms for the 48-core CPU fixture**. These are fresh view-graph/offscreen-render costs, not live opening latency, animation frame times or evidence that every update rebuilds the entire board.

The installed release used **0.109% of one CPU core** over a 60.21-second unattended capture. Its physical footprint was about **189 MiB**, with only **112 KiB net growth** in that window. This is not evidence of a sustained CPU problem or a memory leak. Native automation could not determine panel visibility, so the capture must not be described as a verified closed-popover baseline.

## Revision and measurement contract

- Initial source: `c10068c5f5330bf4ddb998693578aa31ae153996`, Thermals 0.4.4/build 10. Reader microbenchmarks compiled these sensor files with Swift 6 and `-O`.
- Pinned source for complete-refresh and rendering probes: `dbbbcbc2634977b785bda64342d9c0093bf08a64`, which adds shared heat activity. Its sensor files are unchanged from the initial source. A detached checkout at `.worktrees/performance-dbbbcbc` prevents concurrent work from changing measurements.
- Installed binary: `/Applications/Thermals.app`, 0.4.4/build 10, PID 55305 during capture. This is a version-identified installed binary, not a proven binary match to the pinned source. It had been running for approximately six hours, with unknown prior interactions.
- Hardware: Apple M3 Pro, 12 CPU cores, 18 GB RAM; macOS 27.0.1 build 26A434; Xcode 27.1 build 27A9275. Ordinary developer workloads continued. Initial load averages were roughly 4–5; this was not a controlled quiet lab or a cross-device study.
- Counts near the reader probe: 813 PIDs, 820 parsed `ps` entries at a different instant, 343 footprint groups, 45 raw temperature readings, 20 deduplicated display sensors and two fans. GPU energy samples were available.
- Reader probe: 100 calls per recurring reader, 30 process snapshots, 10 reader initializations; 10 ms sleeps between calls. Wall time includes waits. `getrusage` process/child CPU deltas are separate and include small harness overhead. A separate three-second-cadence HID check tests the rapid-call assumption.
- View probe: `-O -D DEBUG`, pinned production components in a standalone executable. The app entry point is replaced, fonts registered explicitly, and an inert updater stub substitutes for Sparkle. Fixed preview monitors disable peak persistence, heat alerts, live timers and process-task scheduling. Each refresh still executes the production synchronous reader path. Each image render creates a new `ImageRenderer` at 2x; overflow uses the documented snapshot branch. It does not measure a compositor, mounted-view reuse or animation.
- Quantiles use the sorted sample at `ceil(0.95*n)-1`; at n=15, p95 is the maximum. First-call costs are retained. There is no confidence interval or release gate derived from these small samples.

Concurrent feature implementation continued in the main checkout after the pin. This report does not certify those later features. The pinned source is the analysis boundary, not a claim that this is the latest app behavior.

### Source-only check of later work

Before delivery, the committed delta through `3bb435c8da1ac06881235788298196a50b208abe` was inspected. The blocking HID and RAM paths remain. New power-source polling also runs in `Monitor.refresh`; its IOPowerSources calls were not timed. Heat episodes retain at most eight completed records, and sessions retain current/last aggregates rather than an unbounded sample stream. Active sessions encode/save on every refresh, and active episodes usually change and save as their timestamp advances. Their persistence cost is unmeasured; the installed capture's zero disk writes cannot be generalized to them.

The later global-shortcut implementation replaces MenuBarExtra with `StatusItemController`, an NSPopover and an eagerly created NSHostingController. It explicitly clears sampling flags when the popover closes. Its one-second timer calls `updateLabel()` unconditionally and creates an outer ImageRenderer around `MenuBarReading`, whose body creates another image renderer. Unlike the earlier SwiftUI label path, repeated rasterization is now established directly by source even when the displayed value is unchanged. Its cost has not been measured in the new live controller. Reusing an unchanged image is a small follow-up, [#68](https://github.com/radkode/thermals/issues/68); blocking IPC still has higher priority. Eager popover construction also changes startup and retention behavior, so the older installed-process measurements cannot certify the new controller.

## Reader costs

All times below are milliseconds per call. CPU is mean self-process time; `ps` child CPU is called out separately.

| Operation | n | Wall median | Wall p95 | Wall max | Mean CPU |
| --- | ---: | ---: | ---: | ---: | ---: |
| HID temperatures | 100 | 36.908 | 60.532 | 90.306 | 1.193 |
| Temperature filtering, deduplication and sorting | 100 | 0.176 | 0.246 | 2.735 | 0.200 |
| SMC fans | 100 | 1.097 | 1.573 | 1.913 | 0.176 |
| SMC system power | 100 | 0.244 | 0.646 | 0.879 | 0.067 |
| IOReport GPU sample | 100 | 1.926 | 2.205 | 2.383 | 1.958 |
| CPU ticks | 100 | 0.024 | 0.069 | 0.740 | 0.037 |
| System memory | 100 | 0.026 | 0.050 | 0.133 | 0.034 |
| App footprints | 100 | 24.935 | 50.527 | 163.967 | 26.072 |
| Footprint ranking | 100 | 0.028 | 0.072 | 0.081 | 0.039 |
| Process snapshot, including `ps` and parsing | 30 | 126.984 | 153.761 | 241.840 | 31.869 |
| Process aggregation/smoothing | 100 | 0.184 | 0.245 | 0.290 | 0.198 |

Process snapshots also consumed **31.501 ms mean child CPU**. Ignoring subprocesses would understate attribution's CPU cost by about half. The aggregation probe reuses the same PID fixture, so its cost is not a distribution of real changing workloads.

The complete-refresh probe is stronger than adding independent percentiles: 30 actual `Monitor.refresh()` calls measured **39.031 ms median / 41.435 ms p95 / 44.368 ms max** without footprints, and **59.973 / 63.522 / 64.750 ms** with footprints. Other runs had a longer footprint tail, illustrating why a single short average is insufficient.

The independent HID cadence check confirmed the result: **20 reads spaced three seconds apart took 36.759 ms median, 65.301 ms p95 and 77.865 ms maximum**. The blocking cost is not just an artifact of calling the reader rapidly in a loop.

Reader initialization was **2.912 ms median for HID**, **0.198 ms for SMC** and **46.213 ms for GPU subscription**. A preview Monitor initialization took **50.789 ms median** because its stored reader properties initialize even for fixtures. Live startup also performs a synchronous refresh. These are startup components, not a measured launch-to-menu-bar duration. Sparkle, font loading, AppKit and first layout are excluded.

## Execution and lifecycle map

| State or event | Work at the pinned revision | Implication |
| --- | --- | --- |
| All live states | Main-run-loop timer calls `Monitor.refresh` every 3/6/10 seconds: HID, memory, fans, system power, GPU, CPU ticks, histories | Closing the board does not remove hardware IPC from MainActor |
| Menu bar | One-second freshness timer; trend derived from bounded history; non-template image rendering when SwiftUI evaluates the reading | The timer is observable in source; one image allocation every second is not established |
| HEAT visible | Shared activity request on entry and eligible refreshes, throttled to 30 seconds | Up to two background process snapshots per fresh activity sample |
| Hot, serious/critical pressure, or rising trend while hidden | Heat activity can still sample, even without a visible board | Hidden is not equivalent to zero process work |
| CPU visible | One background `ps` task at a time, rapid baseline pair one second apart, then selected cadence | Slow collection avoids MainActor; aggregation returns to it |
| RAM visible | Full footprint scan synchronously on entry and each refresh | Adds blocking cost to the hardware reads |
| Settings or dismissal | CPU/RAM request flags cleared; CPU epoch invalidates results and resets baseline | Good gating; detached in-flight `ps` is not forcibly terminated |
| New warm daily peak / alert | Shared activity sampler; five-second cache and in-flight request sharing | Avoids some duplicate work; bounded attribution can run while hidden |
| Open panel | One-second `TimelineView`, date environment, history/freshness updates | Actual hidden-panel scheduling and view invalidation breadth remain unverified |

At the default six-second rate, one snapshot's measured self+child CPU cost implies about **1.06% of one core** while CPU attribution samples continuously; at three seconds, about **2.11%**. A two-snapshot activity request every 30 seconds implies about **0.42%**. These are arithmetic workload estimates, not observed whole-app CPU, and exclude UI, caching, startup and contention. The CPU board's initial attribution wait is approximately its intentional one-second gap plus two snapshots, around **1.25 seconds** on this machine.

Three-minute histories are pruned by timestamp, roughly 61 samples per series at the fastest ordinary cadence. The display has 30 columns and eight rows. History bucketing measured **0.0003 ms median**, trend calculation **0.0007 ms**. Both probes used the ordinary 30-point fixture. A ring buffer or caching these calculations is not a justified first optimization.

## Rendering evidence

| Fresh offscreen construction and rasterization | n | Median ms | Maximum ms |
| --- | ---: | ---: | ---: |
| HEAT, nine-sensor fixture | 15 | 93.704 | 343.858 |
| CPU, ordinary fixture | 15 | 74.907 | 81.415 |
| RAM, ordinary fixture | 15 | 75.449 | 253.734 |
| CPU, 48-core fixture with overflow | 15 | 193.513 | 208.598 |
| Settings | 15 | 28.633 | 31.682 |
| Menu reading, BOTH with trend arrow | 100 | 0.364 | 7.502 |

Render outliers did not occur only on first use: the largest HEAT and RAM samples were iterations 14 and 13 respectively. The experiment does not isolate the reason for those tails. Normal HEAT fixture size also understates the 20 display sensors observed on this machine. The 48-core result combines larger view construction and the overflow snapshot path, so it does not isolate core-count scaling alone.

`FlapText` creates one stateful `FlapCell` per character. A resting cell draws two clipped Text halves, two gradient backgrounds, a hinge and rounded clipping; flipping adds two more halves and 3D animation. Each changed character starts an unstructured task with a stagger of 28 ms per column. Ordinary sample periods exceed the normal flip duration, but rapid changes/disappearance are not cancellation-tested. Ranked process/app rows also animate for 0.5 seconds. Reduce Motion guards exist in both paths.

These are candidates to inspect in a live SwiftUI trace, not reasons to replace the visual system. `ViewThatFits` may also incur candidate measurement work. The current evidence cannot apportion construction time among layout, text, gradients and framework setup. Existing Canvas history/lens bars already avoid hundreds of separate SwiftUI lens views. Menu rendering is too cheap in this probe to outrank blocking sensor I/O, and SwiftUI may skip unchanged child evaluation despite the freshness timer.

## Installed-process CPU, memory and wakeups

The 61 observations span 60.208 seconds and use `proc_pid_rusage(RUSAGE_INFO_V4)`, with cumulative CPU deltas divided by actual monotonic elapsed time. The installed app's selected refresh rate and panel visibility were not inspected:

- Self CPU: **0.1086% of one core**; child CPU delta: zero in this window.
- Physical footprint: **188.548 → 188.657 MiB**, observed range **188.532–193.001 MiB**.
- Resident size: **59.938 → 54.266 MiB**, observed range **34.344–62.250 MiB**. Resident size and physical footprint are different measures and must not be conflated.
- Interrupt wakeups: **3,143**, approximately **52.2/s**; package-idle wakeups: **3**, approximately **0.05/s**. These are kernel counters, not timer fire counts or a battery-energy reading.
- Disk reads: **2,400,256 bytes**; disk writes: zero. This does not attribute the reads to a feature or establish network behavior.

A subsequent `vmmap -summary` reported 184.3 MiB physical footprint and a 300.3 MiB lifetime peak. Its malloc-zone summary showed about 30.5 MiB allocated and 25.8 MiB dirty+swapped fragmentation, including AttributeGraph and QuartzCore allocations. Framework caches, compressed/swapped memory and process-footprint accounting mean these rows do not explain the entire footprint. There is no allocation backtrace, leak scan or repeated-open/close soak proving a leak or identifying which views remain retained.

The separate 20-second `sample` capture contains `Monitor.refresh → HIDTemperatureReader.read → _IOHIDEventSystemClientCopyEventForService → mach_msg` on Main Thread. It also contains TimelineView and menu-image work. Sleeping stacks dominate. This is stack-occupancy evidence, not CPU-profile percentages; collection overlapped a build, so it is not used as the quiet timing baseline.

## Prioritized follow-up

1. **P1: remove hardware IPC from MainActor, [#62](https://github.com/radkode/thermals/issues/62).** Keep reader ownership serial, allow one collection in flight, publish coherent results on MainActor, and preserve timestamps and failure semantics. Moving code into an inherited `Task` alone does not move it off the main actor. Verify that no hardware query occupies the UI thread.
2. **P1: move RAM footprint collection off MainActor, [#63](https://github.com/radkode/thermals/issues/63).** Preserve visibility gating, add in-flight/result-epoch discipline and drop results after leaving RAM. Optimize the scan before its negligible sort.
3. **P2: investigate board construction in live traces, [#66](https://github.com/radkode/thermals/issues/66).** Start with large CPU boards and first entry. Retain visual identity, accessibility, pressure semantics and natural sizing. Choose a smaller resting-cell representation or layout change only after attributing cost. Do not infer FPS from the image timings.
4. **P2: make the performance/lifecycle matrix reproducible, [#67](https://github.com/radkode/thermals/issues/67).** Capture menu-only, all boards, Settings, dismissal, 3/6/10-second intervals, Reduce Motion, rapid switching, sleep/wake and repeated open/close memory. Include child processes, signposts and real allocation traces. Measure whether hidden timelines stop and whether timer tolerance/coalescing can reduce wakeups without breaking freshness.
5. **Verification blocker: local signing, [#61](https://github.com/radkode/thermals/issues/61).** Ad-hoc Release builds passed signature verification but aborted at launch because Sparkle failed runtime Team-ID validation. The documented inside-out dry-run signing sequence did not resolve it. The optimized hosted test run failed for the same reason. The installed signed app runs; this is not evidence of a production launch regression.

Apple recommends keeping main-thread interaction work short and generally within about 5 ms for timely frame preparation; delays of roughly 50–100 ms can become noticeable. This is context for prioritization, not a claim that every 39 ms sample causes a visible hitch. See [Improving app responsiveness](https://developer.apple.com/documentation/xcode/improving-app-responsiveness). Timer tolerance is a supported coalescing mechanism, but its battery benefit must be measured here: [Timer.tolerance](https://developer.apple.com/documentation/foundation/timer/tolerance).

## Verification limits and artifacts

Native CUA acquisition of the installed signed app returned `timeoutReached`; evidence was added to [ai-toolkit #8](https://github.com/jacekradko/ai-toolkit/issues/8#issuecomment-6486518878). No live board navigation, FPS, hitch duration, keyboard latency, GPU cost, battery watts or energy-impact score was measured. Do not present this report as a complete Instruments audit. No minimum-macOS, other-chip, battery-power, thermal-throttling or multi-hour soak coverage exists.

The first Xcode build used a stale generated project missing `TemperatureTrend.swift`. Regeneration fixed compilation. The pinned native Release build passed. The optimized hosted probe compiled but could not start because of signing, so its test result is failed, not passed. The standalone optimized reader and rendering probes completed successfully with nonempty readings and images. No product behavior was edited; an unrelated full test-suite pass is not claimed.

Raw local artifacts are under `build/performance-2026-10-28/`: `sensors.json`, `hid-spaced.json`, `view-probes.json`, `installed-idle.json`, `installed-idle-sample.txt`, `installed-vmmap.txt`, build/probe logs and `.exit` files. The process inventory and crash reports remain local. Durable numeric summaries and raw-artifact hashes are in [measurements.json](./performance-2026-10-28/measurements.json). The three analysis-only Swift probes and reproduction commands are in [the probe directory](./performance-2026-10-28/README.md).

## Implementation checkpoint

The owner authorized #62, #63, #66 and #68 in that order after the analysis. Start revision: a10fdc1. The acceptance contract is serial background sensor ownership with coherent publication, background RAM attribution with stale-result rejection, evidence-backed rendering changes preserving the visual contract, and menu image reuse keyed by all visible state. Each slice receives focused correctness checks and before/after evidence; source, docs and verification land together on main. No version bump or release is selected. #61 signing and #67 profiling work are prerequisites only where required for these checks.

Slice #62: hardware readers initialize lazily on a dedicated actor, refresh requests coalesce, and session controls await their boundary samples. Three new deterministic tests passed for coalescing/main-actor progress, timestamps/failure recovery and persisted session boundaries. A real optimized collector probe returned 20 sensors on all 20 reads: collection median 43.416 ms, while the main actor serviced 149 five-millisecond heartbeats during those reads. Heartbeat lateness was 1.366 ms p95 and 1.405 ms maximum. The hardware wait still exists, but it no longer occupies MainActor. Raw evidence: `build/performance-implementation/collector.json`. The initial incorrect file-name suite filter selected only the three new tests; existing consumer suites were rerun by their actual suite names.

Local hosted tests now launch successfully with `CODE_SIGN_IDENTITY="Apple Development: JACEK ANDRZEJ RADKO (93G3HQ8H96)"`, an existing identity. No runtime protections or release signing settings were changed. This resolves the immediate verification prerequisite from #61; ad-hoc dry-run launch remains a separate issue.

Slice #63: RAM footprint enumeration and ranking run in a utility task, with one physical scan in flight. A visibility epoch discards results from an earlier RAM visit, and reopening requests a fresh scan only after the previous one finishes. Three new tests cover coalescing across refreshes, close/reopen races, failed reads and recovery. The combined sampling, memory and real popover lifecycle run passed 16 tests in four suites.

A 20-scan optimized real-footprint probe confirmed main-actor progress during collection; raw evidence is `build/performance-implementation/footprints.json`.

Slice #66: native stack sampling found SwiftUI layout/text-sizing, CoreText and `FlapCell.body` paths during construction. Resting cells now draw one complete glyph over the same two gradient surfaces, with the existing hinge, pins and dimensions. A stable outer ZStack keeps lifecycle identity while switching to the rotating halves. The flip timing and Reduce Motion guard are unchanged. An opt-in native test captures intermediate animation frames and verifies that normal motion produces more than just the initial and final glyph.

Release measurements on this machine, ten constructions per fixture, compare 277fdd5 with the optimized cells. Native construction includes synchronous hosting, layout and display submission; it is not first-frame presentation time or FPS.

| Board | Native median before / after, ms | Offscreen median before / after, ms |
| --- | ---: | ---: |
| HEAT | 148.32 / 69.74 | 34.17 / 25.62 |
| CPU | 232.82 / 107.01 | 69.21 / 44.85 |
| RAM | 231.68 / 111.10 | 74.68 / 44.67 |
| CPU, 48 cores | 473.36 / 222.36 | 228.41 / 117.79 |

Native medians improved 52–54% in this local comparison. The two native probe tests and ten snapshot/sizing tests passed, producing 37 board/state captures. Visual inspection preserved the board appearance. The four before/after PNG pairs have identical dimensions, with 0.31–0.51% of pixels differing and a maximum channel difference of 18/255, concentrated at cell edges. They are not byte-identical. Native captures also show the intermediate split-flap transition. Durable raw measurements and hashes are in [implementation-measurements.json](./performance-2026-10-28/implementation-measurements.json).

Instruments' 40-second SwiftUI capture reached its limit but failed to finalize after more than seven minutes, emitting an AttributeGraph tree dump. Export reported `Document Missing Template Error`; the owned profiler was terminated. That trace is not usable evidence. The separate native stack sample succeeded, but overlapped trace processing, so its timings are not a quiet baseline. This limitation is recorded in [#67](https://github.com/radkode/thermals/issues/67#issuecomment-6497807327). No FPS, hitch, energy or system Reduce Motion coverage is claimed. Exact 90-degree flap rotations emitted singular-transform warnings in the baseline, tracked separately in [#71](https://github.com/radkode/thermals/issues/71).

Slice #68: the status controller caches its successful image by the label's actual formatted parts and heat levels, effective color scheme, outer backing scale and inner text-rendering scale. Accessibility and tooltip text update independently. Rounded-value equality and source timestamp changes reuse the image; units, modes, pressure warnings, trend arrows, stale expiration and unavailable readings invalidate it when their pixels change. Tests also cover both scale inputs and appearance changes.

The native item reused the same NSImage across 1,000 unchanged updates. An optimized local comparison measured 1,000 complete cached updates at 5.424 ms wall / 9.243 ms process CPU, versus 481.132 ms wall / 655.318 ms process CPU for 1,000 fresh label rasterizations and assignments. The fresh-render comparison reuses a prepared label, so it excludes the previous controller's label-preparation cost. These are synthetic menu-path costs, not app idle CPU, allocation rate or battery savings. The sample and hash are preserved in the implementation measurements.

Final verification: the signed Release source passed 162 tests in 42 suites, with 39 snapshot artifacts. The opt-in native construction/animation suite passed two tests separately; the final focused cache suite passed three tests, including its opt-in benchmark. No test assertions were weakened. One earlier full run failed the existing native popover lifecycle test; the isolated suite, a full notification-diagnostic run and the final uninstrumented full suite passed. Its original cause remains unproven and is retained in [#67](https://github.com/radkode/thermals/issues/67#issuecomment-6499423705), with the failed log preserved. Temporary diagnostics were removed. The pre-existing actor-isolation warning remains tracked in #60.

Delivery checkpoint: source changes for #62, #63, #66 and #68 are implemented in the authorized order. #62 and #63 are commits 24bdefb and 277fdd5; rendering is 5ef374b; menu reuse and this final evidence land together in the following commit. #66 remains open for its exportable live before/after Instruments traces and responsiveness-budget validation; no specific live board-entry budget was agreed or established by these construction timings. The broader lifecycle, system Reduce Motion and energy matrix remains #67. No version bump or release was selected. The generic Workflow tool was unavailable; work proceeded directly.

## Release checkpoint

The owner subsequently authorized shipping these changes, tracked in [#80](https://github.com/radkode/thermals/issues/80). Target: 0.5.0, build 11, from the verified 9f4b769 source plus release metadata. This also publishes the previously built heat activity/episodes, power-source context, global opener, temperature trend and work-session receipts on main. The [tagged-version CI preflight](https://github.com/radkode/thermals/actions/runs/40894807601) passed 163 tests on the release runner. Remaining verification: automatic release workflow; source tag, archive/appcast/cask versions and hashes; signatures/notarization; installed update. Existing #66/#67/#71 limitations remain recorded and are not reclassified as completed by release. Status: publishing the version bump, with no new product behavior selected.
