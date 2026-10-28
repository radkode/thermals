# Website parity with Thermals 0.4.3

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

The native GPU power stat added in `a1868d3` is the remaining header difference, tracked separately in [#36](https://github.com/radkode/thermals/issues/36).

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
