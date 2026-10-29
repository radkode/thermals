# Feature options, 2026-10-28

## Brief and scope

The owner requested an assessment of 16 earlier ideas against what has shipped, plus new ideas. This is a product exploration, not an implementation commitment. Acceptance: account for every original item, distinguish shipped from built, rank remaining work, explain technical caveats, and preserve candidates in the repository tracker. No application changes, release or website deployment are included.

Baseline: main at `c10068c5f5330bf4ddb998693578aa31ae153996`. The latest public release at inspection was [0.4.4](https://github.com/radkode/homebrew-thermals/releases/tag/v0.4.4), build 10. The trend commit is newer than that release. The pre-existing untracked `.playwright-cli/` directory belongs to earlier work and was left alone.

## Recommendation

Make the next increment explain the heat already measured: live context on HEAT, then compact heat/pressure episodes, then charging context. The global opener is a useful small companion. Explore GPU utilization separately before promising coverage. Select one distinctive experiment after that, preferably session receipts or a one-shot cooldown notice.

Keep the 400pt transient board and stable rows. Prefer one useful summary to another permanent panel, and place optional detail behind an explicit action. No new fourth board is justified by this review. Preserve explicit units, freshness and unavailable states, neutral watts, and the distinction between CPU temperature bands and OS thermal pressure.

## Original list

| # | Idea | Verified state | Recommendation |
| --- | --- | --- | --- |
| 1 | CPU, GPU and system watts | System PSTR and IOReport GPU watts implemented and in the released baseline. CPU watts absent; README records frozen unprivileged CPU/DRAM counters on macOS 27. | Treat system/GPU as done. CPU is blocked research, not an ordinary remaining M feature. Never derive CPU as system minus GPU. |
| 2 | Live heat culprit | No live attribution row on HEAT. It has a CPU inspection button. Peaks and alerts already obtain bounded process samples while CPU is closed. | Highest-value next feature, M. Describe top CPU activity, not proven thermal causation. |
| 3 | Throttle evidence | Current thermal state only; no pressure-event log or measured frequency history. | Build pressure episodes first, M. Record OS-reported states and duration, not an invented slowdown percentage. |
| 4 | GPU readings | GPU watts exist. Sensor labels recognize GPU MTR temperatures when exposed, but no validated GPU hero/utilization feature. | Prioritize utilization/source validation over another headline temperature. |
| 5 | Heat alerts | Shipped. Trigger is 85°C or serious/critical pressure sustained 30 seconds, with episode rearming and a ten-minute minimum interval. Names busiest CPU process. | Done, with a different trigger from the original BURN proposal. |
| 6 | Pin a menu sensor | Only CPU temperature, CPU load, or both are selectable. | Later, S/M. Label the pinned source; do not apply CPU bands to battery/SSD. |
| 7 | Menu trend | Built in c10068c, after released 0.4.4. Least-squares slope over one minute, at least three samples spanning 30 seconds, 5°C/min dead zone. | Built, awaiting a later release. Do not rebuild it. |
| 8 | Global opener | In-app shortcuts exist; no global opener found. | Good small companion, S/M pending MenuBarExtra feasibility and focus handling. |
| 9 | Longer history | 180-second in-memory histories; only daily peak persists. | Episode summaries first. If still useful, 1 HR before 24 HR, with bounded buckets and explicit gaps. |
| 10 | Today's peak | Shipped in 0.4.4: temperature, time and sampled busiest process, persisted across relaunch. | Done. Attribution is activity near the peak, not proof of cause. |
| 11 | Intel support | Temperature path remains Apple Silicon. Existing SMC infrastructure reads fans and system watts. | Defer L until demand and representative hardware/testing ownership exist. |
| 12 | Shortcuts/App Intents | No actions present. | Useful S/M follow-up for read-only temperature, pressure and power with timestamps. Continuous threshold automation is separate scope. |
| 13 | Desktop widget | No extension present. | Defer. If pursued, show a timestamped daily summary, not a live thermometer. |
| 14 | Battery context | Battery temperature may appear; charging/power-source context is absent. | High-value S/M addition after explanation/episodes. Adapter rating is not live draw. |
| 15 | Flap clack | No sound behavior found. | Optional S experiment, default off and only on sustained meaningful transitions. |
| 16 | Departure announcements | Existing signage language, but no dedicated announcement feature. | Fold concise factual state copy into #2. Avoid a rotating notice feed and copy that obscures the reading. |

## New directions

Examples are illustrative product concepts, not observed measurements.

1. **Thermal flight recorder.** Expand #3 into an episode receipt: when the heat started, peak, observed pressure duration, top CPU activity and available system/GPU power. One row could say `LAST HEAT · 14:02 · 3 MIN`. Inspection answers what happened while the board was closed. Temperature episodes and pressure episodes can overlap but are not synonymous.
2. **Notify when cooled down.** A one-shot action for the current episode, useful before another build or when the user steps away. Notify after a sustained fresh recovery condition. Avoid a countdown: changing workloads make a precise cooling ETA unjustified.
3. **Build/render receipts.** Mark a session, then get a compact departure-ticket summary: duration, peak, time under OS pressure, and estimated whole-system Wh when the measured power coverage permits. Optional explicit export gives the visual identity a useful shareable artifact. Never label it the build's own energy consumption, since other work contributes.
4. **Did that help?** Compare two short session windows around a change the user makes, such as disconnecting a display, changing a browser workload or moving the laptop. Compare watts, temperature trend, pressure and fans. Show workload/context differences, allow settling time and call the result an observation, not causal proof.
5. **Unusually warm for this Mac.** Learn a local low-load baseline, separated by charging/power context. A notice can say the current reading is above recent comparable sessions, without inventing a universal normal temperature or diagnosing cooling hardware. This is research, M/L, and needs enough data to avoid noise.
6. **Clear for departure.** A stretch developer tool lets an explicitly submitted build wait for sustained nominal pressure, run, then produce a receipt. Read-only App Intents could be a first step, but a cancellable command runner and wait policy are a separate M/L feature. Never pause arbitrary applications.

The strongest differentiator is the combination of useful episode/session summaries and Thermals' physical board identity. An LLM explanation service is unnecessary for the proposed observed-state summaries.

## Evidence and limits

- Source: `Thermals/Monitor.swift`, `Thermals/Views/HeatBoard.swift`, `Thermals/HeatAlerts.swift`, `Thermals/DailyPeak.swift`, `Thermals/TemperatureTrend.swift`, `Thermals/ThermalsApp.swift`, `Thermals/Sensors/SensorLabels.swift`, `project.yml`, PRODUCT.md, DESIGN.md, README.md and the linked UX/release checkpoints.
- Alerts and peak attribution use `ProcessSampler.busiest()`; live CPU rows have a separate on-demand sampling lifecycle. The new context feature should coordinate this existing work and measure cost rather than assume background sampling is free.
- [Apple's thermal-state guidance](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum/serious) documents performance reduction at serious pressure. This supports an OS-pressure explanation, not a measured frequency history or quantified impact on an individual workload. Frequency drops alone are not a sufficient thermal-throttling test.
- [Stats' GPU reader](https://github.com/exelban/stats/blob/master/Modules/GPU/reader.swift) reads `PerformanceStatistics` and utilization keys. It establishes a candidate implementation path, not compatibility on every Thermals-supported chip/OS combination.
- [Apple's power-adapter API](https://developer.apple.com/documentation/iokit/1523866-iopscopyexternalpoweradapterdeta) supplies adapter metadata; [power-source descriptions](https://developer.apple.com/documentation/iokit/1523867-iopsgetpowersourcedescription) may omit keys. Present missing data honestly and distinguish adapter capability from measured consumption.
- [WidgetKit refresh guidance](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date) places reload timing under system control. A widget is therefore a poor primary surface for second-scale heat changes.
- No new runtime sensor experiment, render, app build or usability test was run for this planning task. Estimates are rough and not delivery promises.
- Existing website parity work is already tracked in [#36](https://github.com/radkode/thermals/issues/36), [#38](https://github.com/radkode/thermals/issues/38) and [#41](https://github.com/radkode/thermals/issues/41); do not duplicate it.
- The Impeccable loader's macOS/iOS metadata mismatch is already [#15](https://github.com/radkode/thermals/issues/15). macOS project guidance governed this assessment. The unavailable required Workflow tool is the existing harness finding DD-8744; direct tools were used and no workflow run is claimed.

## Candidate tracker

Each issue is an unselected candidate, not approval to implement or release. Item 16 is part of the live context candidate; the flight recorder is the proposed shape of item 3.

| Candidate | Recommendation | Rough effort | Issue |
| --- | --- | --- | --- |
| Investigate reliable unprivileged CPU power readings | Blocked | M research | [#42](https://github.com/radkode/thermals/issues/42) |
| Explain current heat with a compact live context row | First | M | [#43](https://github.com/radkode/thermals/issues/43) |
| Record compact heat and thermal-pressure episodes | Second | M | [#44](https://github.com/radkode/thermals/issues/44) |
| Validate GPU utilization and temperature coverage across Apple Silicon | Next research | M research | [#45](https://github.com/radkode/thermals/issues/45) |
| Allow an explicitly labeled temperature sensor in the menu bar | Later | S/M | [#46](https://github.com/radkode/thermals/issues/46) |
| Open and close the Thermals popover with a global shortcut | Quick win | S/M | [#47](https://github.com/radkode/thermals/issues/47) |
| Add bounded one-hour heat history before considering a full day | Later | M | [#48](https://github.com/radkode/thermals/issues/48) |
| Assess Intel temperature support with representative hardware | Defer | L | [#49](https://github.com/radkode/thermals/issues/49) |
| Expose fresh thermal readings through read-only App Intents | After core explanation | S/M | [#50](https://github.com/radkode/thermals/issues/50) |
| Evaluate a daily thermal-summary widget instead of a live gauge | Defer | M | [#51](https://github.com/radkode/thermals/issues/51) |
| Show charging and power-source context on HEAT | Third | S/M | [#52](https://github.com/radkode/thermals/issues/52) |
| Prototype an opt-in clack for meaningful heat transitions | Optional delight | S | [#53](https://github.com/radkode/thermals/issues/53) |
| Offer a one-shot notification when a heat episode settles | Best small new idea | S/M | [#54](https://github.com/radkode/thermals/issues/54) |
| Create a local thermal receipt for a build or render session | Strong new direction | M | [#55](https://github.com/radkode/thermals/issues/55) |
| Explore a local baseline for unusually warm low-load periods | Research | M/L | [#56](https://github.com/radkode/thermals/issues/56) |
| Compare two short thermal sessions around a user-made change | Experimental | M | [#57](https://github.com/radkode/thermals/issues/57) |
| Explore cooperative thermal waiting for user-owned build commands | Stretch | M/L | [#58](https://github.com/radkode/thermals/issues/58) |

## Authorized implementation

The owner selected the recommended sequence: #43 live HEAT context, #44 episode recorder, #52 charging context, #47 global opener, then #55 session receipts. Implement and verify these five slices in order, on main. Other candidates remain unselected. No release-version bump or website deployment is included in this implementation request.

Acceptance follows each issue's recorded criteria. Use pure model tests for freshness, episode boundaries and energy coverage; native snapshots for normal, unavailable and compact boards; and live checks for the shortcut and power source. Keep process sampling bounded and shared, preserve unavailable readings, and make copying receipts explicit. The coordinator is this Codex session; no DailyDeck claim applies to this repository's GitHub issue workflow.

## Completion checkpoint

Implementation in progress from c10068c. #43 is committed as dbbbcbc: shared attribution and live HEAT context. Its 23 activity/peak/layout tests and 11 alert tests passed; HEAT renders were inspected. A single ps scan took 0.03s wall/0.02s CPU on this host (one observation, not a cross-Mac benchmark). #44 is implemented with eight retained episodes, recovery hysteresis and honest gap/restart handling; four model tests and ten native layout tests passed, with final summary renders inspected. Logs/renders: .impeccable/features/. #52, #47 and #55 remain. Next action: charging context. The pre-existing .playwright-cli directory is unrelated. Existing sensor-test actor isolation warning is filed separately as #60.
