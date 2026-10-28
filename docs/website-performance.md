# Website performance investigation

Owner-requested performance work and board-picker repair, 2026-10-28. Tracked in [#32](https://github.com/radkode/thermals/issues/32) and [#33](https://github.com/radkode/thermals/issues/33). Scope is `site/`; native-app changes and website semantic parity ([#30](https://github.com/radkode/thermals/issues/30)) are separate work.

## Findings and implementation

- Startup called the full DOM-writing sample update 30 times to seed the charts. Seed the numeric histories directly and render once. Preserve the original initial sample and the subsequent 1.5-second cadence.
- Each resting flap used five elements, including duplicated top/bottom text. A single face now supplies the two-tone background and text. Temporary half-leaves and perspective exist only during a flip, preserving the split-flap motion and Reduce Motion behavior.
- Mobile updated all three boards, including those clipped horizontally. Sample histories continue together, but only boards with at least 1% of their area visible render. Intersection checks use the viewport, including the scroll track's clipping. An entering board catches up immediately without replaying old flips or adding a history sample. HOLD and hidden/offscreen-section suspension remain in place.
- Meter colors depend on the row, not the individual lens. Compute eight color pairs per redraw instead of repeating those calculations across 240 lenses. Board fitting batches geometry reads before style writes.
- Both TTF fonts were loaded uncompressed from the local fixture. The site now preloads full-coverage WOFF2 versions, keeping the original glyph coverage and advance widths. Original TTFs and OFL remain conversion sources; there is no runtime dependency or site build step.
- At 820px and 1024px, selecting RAM scrolled correctly but selected CPU again. Visible-area ranking tied when both boards fit. Selection now follows the nearest clamped scroll destination, retaining the clicked/current tab on ties. A trailing scroll callback handles manual scrolling without requiring `scrollend` support. Tabs remain hidden when all three platforms fit.

## Measurements

Baseline source: `19d8fe89f0289be9afc43100a8e47108b93071a7`. The site was unchanged by intervening native-app commits. Chrome on the development Mac, local HTTP server, browser cache disabled, 4x CPU throttling, 900px viewport height. Three startup runs per width; startup values below are medians. Runtime windows cover six seconds with the boards in view. These are laboratory comparisons, not field Core Web Vitals or guarantees for a physical phone.

| Measurement | Before | After | Change |
| --- | ---: | ---: | ---: |
| Demo initialization, 390px | 186ms | 50.8ms | 73% less |
| Demo initialization, 1440px | 190.8ms | 47.5ms | 75% less |
| First contentful paint, 390px | 360ms | 160ms | 56% sooner |
| First contentful paint, 1440px | 352ms | 152ms | 57% sooner |
| Resting DOM elements | 4,214 | 2,404 | 43% fewer |
| Main-thread task duration over 6s, 390px | 1.550s | 0.596s | 62% less |
| Main-thread task duration over 6s, 1440px | 1.419s | 1.279s | 10% less |
| Offscreen CPU/RAM mutations over 6s, 390px | 1,852 | 0 | Eliminated |
| Font file bytes, combined | 212,788 | 77,180 | 64% smaller |

The fresh-context first mobile initialization was still 284ms, versus 327ms in the baseline's first run. Later optimized runs were 41ms and 51ms. Desktop animation still does meaningful work while all three boards are visible; its layout/style time did not improve, so the smaller desktop task-time result should not be overstated. Font file savings are not a measurement of compressed Vercel transfer savings. No field INP was collected.

Local artifacts are ignored under `.impeccable/perf/`: baseline/final profiler outputs, screenshots, pixel comparison, functional results, sample-equivalence results and the exact profiling script. An early profiling rerun reused a context and duplicated PerformanceObserver callbacks; final metrics use a fresh context. Startup and runtime timings were unaffected by duplicate reporting, but only the final capture is used above.

## Verification and reproduction

There is no package manifest, lockfile, bundler or build step for the site. Serve it locally and run the committed Playwright CLI check against that page:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory site
# In another terminal:
playwright-cli -s=thermals-site open http://127.0.0.1:8765/ --browser=chrome
playwright-cli -s=thermals-site run-code "$(cat scripts/check-site.js)"
```

Inspect the CLI result for `Error`; its process can exit zero even when browser code throws. The checks exercise 320, 390, 768, 820, 1024, 1180, 1200 and 1440px widths; all board selections; rapid changes; Enter/Space activation; manual scroll selection; visible versus offscreen mutations; HOLD/RUN; Reduce Motion; both clipboard buttons; the download destination; font requests; and browser errors.

Held desktop before/after captures had identical dimensions and a mean RGB channel difference below 0.05 out of 255 after the face simplification. This checks the resting appearance, not every animation frame. WOFF2 conversion also passed exact character-map, glyph-order and horizontal-metric comparisons against the TTF sources. Physical-device performance and Safari rendering remain unverified.

A controlled full-cycle comparison advanced the original and optimized demos through 41 sample steps on all three boards. Every displayed character position, text ink, history lens color and range matched, including boards revisited after being offscreen. Empty cells were normalized to blank characters without collapsing their positions.

To regenerate the webfonts with FontTools and Brotli installed:

```python
from pathlib import Path
from fontTools.ttLib import TTFont

for source in Path("site/fonts").glob("*.ttf"):
    font = TTFont(source)
    font.flavor = "woff2"
    font.save(source.with_suffix(".woff2"))
```

## Delivery checkpoint

The owner authorized deployment on 2026-10-28. Commit `5c6a3696d8f4bfadc35fa56fdaba104b89bdef96` was pushed to `main`; [Vercel deployment](https://vercel.com/jacekradkos-projects/thermals/56p6vZfVdxccn1gsbYAwtNvoJs7H) completed successfully. Production HTML and both WOFF2 assets matched the local SHA-256 hashes. The complete browser check passed against `https://thermals.dev/`, including all eight widths, picker behavior, keyboard, scrolling, offscreen suspension, HOLD/RUN, Reduce Motion, clipboard and font loading, with no browser errors. Results are in `.impeccable/perf/production-check.txt`. No native version bump, app release, cask edit or tag was needed.
