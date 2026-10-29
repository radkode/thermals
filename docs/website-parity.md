# Website parity with Thermals

## Selected continuation: current app features

The owner selected website parity work after the five native features landed in `3bb435c`. This continuation covers #64 and the existing #36 (GPU watts), #38 (daily peak) and #41 (menu trend). Preserve the station/platform composition, responsive picker, fixed histories, reduced-motion behavior and visible-only rendering. Add current HEAT context, expandable episodes and sensors, and explicit sample session START/STOP/COPY. Native global-shortcut behavior is explained, not registered by the webpage. These features shipped in 0.5.0; the website identifies the boards as sample readings and the features as included in that release.

Acceptance: all three boards remain readable from 320 through 1440px; sample controls work with keyboard and pointer; receipts identify synthetic data, whole-system energy and measured coverage; no names are copied; GPU unavailable states are honest; peak and trend follow the native semantics. Run the existing functional and parity browser checks plus focused new-feature checks, inspect desktop/mobile renders, and update this contract. Scope excludes native code, release-version changes and the unrelated in-progress performance probe. Canonical checkout began at `29ca66d`; the modified `docs/performance-2026-10-28/ViewBench.swift` and pre-existing `.playwright-cli/` are not part of this work. This Codex session coordinates delivery on main through the repository's website deployment path.

Implementation, local verification, independent design/documentation review and production verification are complete. Artifacts: `.impeccable/site-next/`, with reviewed captures under `.impeccable/review/site-next/`. Concurrent native performance edits are outside this change and were not staged with it.

### New feature contracts

| Native source | Website behavior |
| --- | --- |
| `HeatBoard.swift` | POWER/LOAD and GPU/PRESSURE use the same two-column grid. Watts stay neutral; unavailable system/GPU values show `--`. TOP CPU uses one-core percent, links to the CPU platform and transfers keyboard focus. Charging and adapter capability are separate from measured draw. |
| `DailyPeak.swift` | PEAK TODAY retains the first time a displayed whole degree was reached, resets on sample midnight, and includes illustrative top activity without claiming causation. |
| `TemperatureTrend.swift` | The last 60 sample seconds use least-squares slope, a 30-second minimum span and a 5°C/min dead zone. RISING/COOLING/STEADY is on HEAT; only rising/falling adds a menu arrow. |
| `HeatEpisode.swift` | Episodes start at 85°C or serious/critical pressure and finish after 30 sample seconds below 75°C without serious pressure. The disclosure retains up to eight completed episodes, with peak temperature/power and pressure intervals whose endpoints are both pressured. |
| `ThermalSession.swift` | Explicit sample START/STOP retains the latest receipt in page memory only. HOLD, offscreen suspension and hidden-tab suspension freeze sample time. Missing power excludes both adjacent intervals from Wh and coverage. Receipt text identifies synthetic data and whole-system energy, includes °C, and omits process names. COPY is explicit; clipboard denial selects the receipt and explains manual recovery. |
| `GlobalShortcut.swift` | Copy explains the upcoming native Control + Option + T opener and T/H/OFF choices. The site does not capture global shortcuts or simulate native settings permissions. |

Native `<details>` provide episodes, receipts and sensors. Flap cells remain decorative; buttons and disclosure summaries are keyboard accessible, with actual 44px targets after narrow-board scaling. Board-size observation keeps expanded content in normal page flow without inner scrolling. The sample clock advances six seconds per 1.5-second tick; initial histories and episode/peak records are seeded numerically, without repeated DOM renders. CPU/RAM offscreen rendering remains suspended.

Local checks passed: the existing eight-width functional check, 41-state semantic parity check and new 41-state feature check. The latter validates trends, daily peak retention, episode transitions, sample timing, pressure intervals, Wh/coverage, clipboard success/failure, focus, mobile expansion and reload reset. A first HOLD assertion confused CSS-uppercase display text with the unchanged `0s` model text; the assertion now reads the duration label directly. A functional run after a mocked clock had no font resource entries; the unchanged check passed in a fresh real-time browser session. Run the real-time check in its own session, before clock-based checks:

```sh
playwright-cli -s=thermals-site-real open http://127.0.0.1:8766/ --browser=chrome
playwright-cli -s=thermals-site-real run-code "$(cat scripts/check-site.js)"
playwright-cli -s=thermals-site-clock open http://127.0.0.1:8766/ --browser=chrome
playwright-cli -s=thermals-site-clock run-code "$(cat scripts/check-site-parity.js)"
playwright-cli -s=thermals-site-clock run-code "$(cat scripts/check-site-features.js)"
```

Impeccable's independent full review found one material correction: use an authored SVG for the menu trend rather than a font-fallback arrow. The correction inherits temperature ink and preserves accessible direction text; the reviewer scored it resolved and returned `ship` on that fix. All seven recaptures were valid. The documentation review confirmed this is an ordinary extension with no new token system. Inherited platform metadata is already #15; the sidecar narrative typo is separately filed as #69. The detector ran once; its new long all-caps note was changed to mixed case. Remaining findings concern the inherited hero leading, clamp padding and design-metadata mismatches, not a new design direction. Review records: `finish-review.md` and `documentation-review.md` in the artifact directory. The unavailable required Workflow tool remains the existing harness finding DD-8744; no Workflow run is claimed.

The 0.5.0 release updates the sample heading, download explanation and release assertion in `check-site-features.js` together. The notice explicitly distinguishes sample readings from data on the visitor's Mac. Future release-copy changes must preserve that distinction. Physical-device and Safari verification remain separate from the Chrome evidence.

### Production checkpoint

Delivered on 2026-10-28 from `2658cbf1506bf1cbd8661b7e6ab884b13b8e4b31`. [Vercel deployment](https://thermals-kwcr1vc2y-jacekradkos-projects.vercel.app) reported READY for that exact commit and production target. [thermals.dev](https://thermals.dev/) serves byte-identical HTML, 60,342 bytes, SHA-256 `6dd30abb077a649ac6ae4dbdef09012295ea0b0e2a6e1658f5175b4c1b0919a1`.

All three browser checks passed on production: eight responsive widths, 41 semantic sample states and 41 feature states, including native-arrow orientation/color, peak and episode behavior, session timing/energy coverage, copy success/failure, keyboard focus and mobile expansion. Offscreen CPU/RAM mutations remained zero; both WOFF2 fonts loaded once; there were no browser errors. The production desktop capture was visually confirmed. Evidence is `production-functional.txt`, `production-parity.txt`, `production-features.txt` and `production-desktop.png` in the artifact directory. No app version was changed; the site identifies the newer demo as a preview alongside the 0.4.4 download.

### Release 0.5.0

The native release is [0.5.0, build 11](https://github.com/radkode/homebrew-thermals/releases/tag/v0.5.0). Its release transition changes only the sample heading and notice, retaining layout and behavior. The 41-state feature check passed, and copy/download/overflow checks passed at 320, 390, 720, 820, 1180, 1200, 1440 and 1995px. Desktop and mobile captures were inspected. Use a fresh browser context after edits: the first local check correctly rejected a cached copy of the old notice, then the fresh-context run passed. Artifacts are under `build/release-verification/0.5.0/`; production verification is recorded on [release task #80](https://github.com/radkode/thermals/issues/80).

### Board-group alignment

The [#70 alignment follow-up](https://github.com/radkode/thermals/issues/70) gives the sample heading, HOLD control and all explanatory notes the same content edges as the three-board group. `--platforms-width` combines three 372px boards and two 24px gaps; supporting containers add the existing 16px gutters. Narrow layouts retain their gutters and horizontal board navigation. Geometry checks cover 320, 390, 720, 820, 1180, 1200, 1440 and 1995px; desktop and 320px captures are under `.impeccable/site-alignment/`.

## Earlier released baseline

Owner-authorized continuation of [#30](https://github.com/radkode/thermals/issues/30), after the website performance work landed as `5c6a369`. The initial reference was 0.4.1/build 7 (`c127241`); [#34](https://github.com/radkode/thermals/issues/34) carries the fixed-scale history contract into 0.4.2/build 8 and the website together. The owner-approved 0.4.3 refinement gives percentage histories the full palette for magnitude. Preserve the station/platform design and the [performance constraints](./website-performance.md).

## What the sample boards teach

| App source | Website contract |
| --- | --- |
| `Board.swift`, `HeatBand.swift` | The dark heat ramp ends at `#FF7073`, with `#FF8355` at the BURN edge. Utilization text and row indicators map to the first 55% of that ramp and use LOW/MOD/HIGH. History charts use the full ramp for magnitude. Heat words apply only to CPU die reference bands. |
| `HeatBoard.swift`, `ThermalsApp.swift` | Non-CPU sensors are neutral and unbanded. Thermal pressure raises temperature ink consistently on HEAT, CPU and the menu preview, where serious/critical pressure also adds `!`. Fan speed uses utilization colors and five numeric cells. |
| `CPUBoard.swift` | Whole-system 100% means all cores; process 100% means one core. Top processes precede core detail. UNMEASURED EST stays neutral, with a non-additive-row explanation. The eight sample cores average to the headline, within display rounding. Estimated work accounts for an unlisted process as well as the five visible processes. |
| `RAMBoard.swift` | Used/installed GB remain visible. Only OS pressure raises the memory hero into warning colors. App shares describe installed RAM and physical footprints, not heat. Memory parts total installed capacity, with lenses apportioned by largest remainder. |
| `BoardComponents.swift` | Histories label observed MIN/MAX and newest-right direction. Visible bounds, help and accessible summaries explain fixed scales and rising/falling/steady trends. HEAT spans 20–110°C; CPU/RAM span 0–100% with identical full-palette colors. Eight equal bins light on crossing their lower boundary, so zero/50%/100% fill zero/four/eight rows. |
| `FlapText.fitted` | Long names use an ellipsis with full hover text. Numeric overflow uses hashes instead of silently dropping digits. Column headings align with numeric and status cells. |

The GPU power header gap from `a1868d3` was tracked in [#36](https://github.com/radkode/thermals/issues/36) and is included in the continuation above.

The website remains an illustrative demo, not a simulated settings application or a sensor reader. Sample row counts can differ from a visitor's Mac. Readings advance at four times speed; every 1.5 seconds represents one six-second history slice. Synthetic OS-pressure states use their own sequence, so a complete cycle includes high RAM with normal pressure and critical pressure at a lower CPU temperature. Labels explicitly identify these as simulated readings.

Each platform has a named heading, an accessible unit/meaning explanation and a current sample/trend summary. The decorative flap DOM stays hidden from assistive technology. Summaries are not live regions, avoiding continuous announcements. On touch, essential units are visible; hover help only expands on them. Boards keep their complete natural height, with horizontal platform navigation on narrow screens and no inner vertical scrolling.

## Verification

There is no package manifest, lockfile, dependency installation or build step. With the site served locally and an existing Playwright CLI session, run:

```sh
playwright-cli -s=thermals-site run-code "$(cat scripts/check-site.js)"
playwright-cli -s=thermals-site run-code "$(cat scripts/check-site-parity.js)"
```

Inspect the CLI's result block for `Error`, not only its process exit code. The existing check covers eight widths from 320 to 1440px, pointer/keyboard/manual-scroll picker selection, HOLD/RUN, Reduce Motion, clipboard, release links, font loading and visible-only mutations. The parity check advances a browser clock through 41 sample states and validates units, labels, palette caps, CPU capacity, mixed OS-pressure states, history descriptions, fixed axis bounds, stable row colors, matching CPU/RAM gradients, column alignment and clipping. It does not publish a test API or change production timers.

Local verification passed both checks. Resting DOM count is 2,367 versus 2,404 after the performance merge. Offscreen CPU/RAM board mutations remain zero in the existing runtime check. Single-face resting flaps, numeric-only history seeding, eight meter color calculations at construction, batched fitting, WOFF2 fonts and picker selection are preserved. These are structural/regression observations, not a new claim about field performance.

Desktop normal, high-RAM/normal-pressure and critical-pressure states, all three 390px boards, and 320px HEAT were captured and visually reviewed. The accessibility tree exposes the named boards, unit explanations and sample trends. Captures and logs are ignored under `.impeccable/site-parity/`. A first mobile check caught absolutely positioned accessibility descriptions escaping the horizontal track; positioning their platform parent fixes it, and the eight-width check then passed. Physical-device and Safari testing remain unverified.

## Delivery

Pushes to `main` that change `site/` deploy through Vercel. This parity work is authorized for that delivery path. Verify the deployed commit and production HTML, then repeat production browser smoke checks. The initial #30 delivery changed only the website; #34 coordinates the website with native 0.4.2 and the owner-approved full-palette refinement in 0.4.3.

Published on 2026-10-28 as `97244634476ea37877793b5be9396d78a3304a4d`. [Vercel deployment AMF14qgsYvGbC1cXM9YQYK3do3ts](https://vercel.com/jacekradkos-projects/thermals/AMF14qgsYvGbC1cXM9YQYK3do3ts) completed successfully. [thermals.dev](https://thermals.dev/) served byte-identical HTML (SHA-256 `6c592e023b07b095b313b1b557d801c2e93b32e933f5adf182508d9b9d424d70`). Both browser checks passed against production, including all eight widths and all 41 semantic states, with no browser errors. The production desktop capture was also visually checked.

The fixed-history follow-up (#34) deployed from `b8fe5ade3f0b80914db56627c63819838f7b0770` on 2026-10-28. [Vercel deployment BN7o15Sd7TavSZH2863Jqk1TYMHz](https://vercel.com/jacekradkos-projects/thermals/BN7o15Sd7TavSZH2863Jqk1TYMHz) succeeded, and production served byte-identical HTML (SHA-256 `752c989ac83b4b38a5daa1c122ee52ff3ab36e63f58bd28e8784d3d34de547c1`). Both browser checks passed on production, including eight widths, all 41 sample states, stable chart bounds and gradients, and zero offscreen CPU/RAM mutations. Desktop and mobile captures, including 320px, passed visual review. Current evidence is under `.impeccable/history-gradient/`; the page has 2,379 resting DOM elements after adding axis labels.

The full-palette refinement deployed from `8aa4164a6b3607b58b21f275e81cae05690c66d8` via [Vercel deployment AaMtywJ59ws7DwcbWwGsyHFmMNmQ](https://vercel.com/jacekradkos-projects/thermals/AaMtywJ59ws7DwcbWwGsyHFmMNmQ). Production HTML matches the tested source (SHA-256 `cb387d8478703b0c40457553b3e1cf0a995dfd970361bab357f282f866ad31ec`). All eight responsive widths and 41 semantic states passed on production, including the full red endpoint on both percentage charts. Offscreen CPU/RAM mutations remained zero. Evidence: `.impeccable/full-history-palette/`.
