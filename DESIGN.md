---
name: Thermals
description: A split-flap concourse departure board for the Mac's heat, in the menu bar.
colors:
  steel-frame: "#2A2D31"
  flap-black: "#0B0B0D"
  flap-top: "#242529"
  flap-bottom: "#1B1C1F"
  lens: "#1E1F23"
  steel-mid: "#5B5E63"
  steel-light: "#A7AAAF"
  letter-white: "#F2F2F2"
  amber: "#FFB000"
  burn-red: "#FF7073"
  heat-cool: "#6F9CC8"
  heat-warm: "#DCE6EE"
  heat-warm-high: "#FFE3A3"
  heat-burn-edge: "#FF8355"
  menubar-light-cool: "#2E6299"
  menubar-light-warm: "#4A5560"
  menubar-light-warm-high: "#8A6400"
  menubar-light-hot: "#A04A00"
  menubar-light-burn-edge: "#B8360F"
  menubar-light-max: "#B3141A"
typography:
  display:
    fontFamily: "Barlow Condensed SemiBold"
    fontSize: "50pt"
    fontWeight: 600
    letterSpacing: "normal"
  title:
    fontFamily: "Barlow Condensed SemiBold"
    fontSize: "15pt"
    fontWeight: 600
    letterSpacing: "normal"
  label:
    fontFamily: "Barlow Condensed Medium"
    fontSize: "11pt"
    fontWeight: 500
    letterSpacing: "1.6pt"
  readout:
    fontFamily: "Barlow Condensed Medium"
    fontSize: "12pt"
    fontWeight: 500
    letterSpacing: "1.2pt"
    fontFeature: "tnum"
  menubar:
    fontFamily: "Barlow Condensed SemiBold"
    fontSize: "15pt"
    fontWeight: 600
    letterSpacing: "0.4pt"
    fontFeature: "tnum"
rounded:
  lens: "1pt"
  cell-row: "1.5pt"
  housing-row: "2.5pt"
  cell-hero: "3pt"
  housing-hero: "5pt"
  panel: "5pt"
spacing:
  cell-row: "1.5pt"
  cell-hero: "3pt"
  row: "3pt"
  lamp-gap: "5pt"
  column: "6pt"
  panel: "8pt"
  tab: "10pt"
  section: "14pt"
  frame: "14pt"
components:
  popover:
    backgroundColor: "{colors.steel-frame}"
    padding: "14pt"
    width: "400pt"
  flap-strip-row:
    backgroundColor: "{colors.flap-black}"
    textColor: "{colors.letter-white}"
    typography: "{typography.title}"
    rounded: "{rounded.housing-row}"
    padding: "1.5pt"
  flap-cell-row:
    backgroundColor: "{colors.flap-top}"
    rounded: "{rounded.cell-row}"
    width: "11.5pt"
    height: "19pt"
  flap-strip-hero:
    backgroundColor: "{colors.flap-black}"
    typography: "{typography.display}"
    rounded: "{rounded.housing-hero}"
    padding: "3pt"
  flap-cell-hero:
    backgroundColor: "{colors.flap-top}"
    rounded: "{rounded.cell-hero}"
    width: "38pt"
    height: "58pt"
  board-panel:
    backgroundColor: "{colors.flap-black}"
    rounded: "{rounded.panel}"
    padding: "8pt"
  column-label:
    textColor: "{colors.steel-light}"
    typography: "{typography.label}"
  flap-tab:
    backgroundColor: "{colors.flap-black}"
    textColor: "{colors.steel-light}"
    typography: "{typography.title}"
    rounded: "{rounded.housing-row}"
  flap-tab-selected:
    textColor: "{colors.letter-white}"
  lamp:
    backgroundColor: "{colors.lens}"
    size: "6pt"
  lamp-lit-tab:
    backgroundColor: "{colors.amber}"
    size: "6pt"
  quit-button:
    backgroundColor: "{colors.flap-black}"
    textColor: "{colors.letter-white}"
    typography: "{typography.title}"
    rounded: "{rounded.housing-row}"
  quit-button-hover:
    textColor: "{colors.amber}"
---

# Design System: Thermals

## Overview

**Creative North Star: "The Concourse Departure Board"**

Thermals is a rail concourse departure board where sensors, cores and processes are departures. Readings use matte split-flap cells inside black housings mounted on a steel frame. Barlow Condensed capitals carry measurements and labels; short mixed-case notes explain units, source limitations and recovery. Temperature uses the full heat ramp. Utilization uses its blue-to-pale-sodium portion, reserving warning orange and red for heat and OS pressure.

The board is dense and ordered the way a real departures board is. Rows hold their position (sensors by natural order of their board label, cores P1.. then E1..) so the eye can return to the same slot; only the user's processes are ranked, and they slide to their new rank rather than jumping. The popover is a fixed 400pt wide, and all three boards (HEAT, CPU and RAM) share one height so the footer and Quit never move when switching. The board is always rendered dark, regardless of system appearance; only the menu bar reading adapts to a light scheme.

This world was chosen by the owner over a liquid-crystal strip. It refuses the stock stats popover (gauges, rings, system-gray list rows) and refuses gamer RGB: no rainbow cycling, no neon, no glow beyond a lit lamp.

**Key Characteristics:**
- Split-flap cells for every value; steel column labels name the data.
- One shared palette with distinct temperature, utilization and OS-pressure meanings.
- Fixed row order; only processes rank, and they animate to their new place.
- CPU temperature reference bands use COOL, WARM, HOT and BURN; utilization uses LOW, MOD and HIGH.
- Steel frame, black housings, matte flaps; no cards, no translucency, no system materials inside the board.

## Colors

A near-black and steel board uses steel blue, letter white and pale sodium for utilization, with amber, orange and red reserved for temperature and OS pressure warnings.

### Primary
- **The Heat Gradient** (stops at 0, 1/3, 0.55, 2/3, 0.85 and 1): `Board.heat` interpolates steel blue, frost, pale sodium, amber, orange and red. Temperature uses the full ramp. `Board.usage` maps normalized utilization into 0...0.55. Small critical text uses #FF7073; the BURN edge is #FF8355. Both clear 4.5:1 against either flap leaf.
- **Menu Bar Light Ramp** (`menubar-light-*`, same six positions): a darker parallel ramp used only when the menu bar is in light appearance, so the reading keeps contrast on a pale bar.

### Secondary
- **Departure Amber** (`amber`): beyond the HOT stop, it is the selection lamp on flap tabs, the hover ink on Quit, and the SERIOUS pressure ink. It is the board's one interface accent.
- **Burn Red** (`burn-red`): the top of the gradient and the CRITICAL pressure ink.

### Neutral
- **Steel Frame** (`steel-frame`): popover background; the mounting the housings sit on.
- **Flap Black** (`flap-black`): strip housings, board panels, cell hinge line.
- **Flap Top / Flap Bottom** (`flap-top`, `flap-bottom`): the two leaves of every cell, each a soft vertical gradient so the lower leaf reads slightly recessed.
- **Lens** (`lens`): an unlit lamp and an unlit meter lens.
- **Steel Mid** (`steel-mid`): panel hairline border (at 45% opacity) and the axle pins on hero cells.
- **Steel Light** (`steel-light`): column labels, unselected tab text, sensor and process names below BURN, placeholder values, NOMINAL pressure, and the neutral UNMEASURED EST row.
- **Letter White** (`letter-white`): selected tab text, FAIR pressure, the default flap ink, the lamp-meter range readout.

### Named Rules
**The One Gradient Rule.** Reading colors come from Board: temperature uses `heat`, utilization uses `usage` (the first 55% of the same ramp). High utilization alone never receives warning orange or red.

**The Derived Is Neutral Rule.** An aggregate the app derives rather than measures (UNMEASURED EST) is shown in steel light with an unlit lamp and an empty STATUS. It is never banded with per-process thresholds.

**The Unscaled Is Neutral Rule.** A reading with no scale shared across Macs (system POWER in watts: an Air peaks near 20 W, a Max past 100 W) is inked letter white, never placed on the heat gradient, since the same watts would mean different heat on different chips.

**The Always Colored Rule.** Menu-bar values remain non-template colored images in both appearances. OS serious/critical pressure adds an explicit warning in every menu mode and raises temperature ink even when the temperature is unavailable. A stale selected source is withheld and marked with a question mark.

**The Pressure Is A State Rule.** Thermal and memory pressure are discrete OS states, not readings, so they use fixed inks, not the gradient: thermal NOMINAL steel light, FAIR letter white, SERIOUS amber, CRITICAL burn red; memory NORMAL steel light, WARN amber, CRITICAL burn red.

## Typography

**Display Font:** Barlow Condensed SemiBold (bundled)
**Label Font:** Barlow Condensed Medium (bundled)
**Menu Bar Font:** Barlow Condensed SemiBold (bundled), 15pt with tabular digits

**Character:** A condensed industrial grotesque in capitals, the voice of transit signage; the cell grid, not the font, carries the rhythm. The menu bar reading uses the same face at 15pt, sized so its cap height matches the 13pt system text around it; it is rendered to an image so it keeps both the face and its heat color.

### Hierarchy
- **Display** (SemiBold 600, 50pt in 38 x 58pt cells): the hero reading on each board (CPU DIE on HEAT, CPU LOAD on CPU).
- **Title** (SemiBold 600, 15pt in 11.5 x 19pt cells): every row value, name, status, stat, tab and the update clock.
- **Readout** (Medium 500, 12pt, 1.2pt tracking, tabular digits): the lamp meter's low to high range.
- **Label** (Medium 500, 11pt, 1.6pt tracking, uppercase, steel light): column and stat labels. Explanatory notes use Medium 500 at 14pt, mixed case, wrapping to the viewport.
- **Menu bar** (SemiBold 600, 15pt, 0.4pt tracking, tabular digits): the reading in the menu bar only.

### Named Rules
**The Cell Is The Unit Rule.** Measurements use fixed flap cells, uppercase and right-aligned; names are left-aligned. Truncated names end in an ellipsis and expose their full text on hover and to accessibility. Numeric overflow shows hashes, never a smaller-looking prefix; fan RPM has five cells for the supported 20,000 RPM maximum.

**The Two Sizes Rule.** Flap text comes in exactly two sizes, hero and row. Hierarchy beyond that comes from position and heat color, not new sizes.

## Layout

A 400pt-wide shell has a 14pt frame and section gaps. Height is capped at 640pt and the current screen visible height minus 32pt. Board tabs, available-update action and footer remain outside one scrolling content viewport. Only the selected board exists. Settings replaces the readings inside that viewport, with Back and Cmd-comma to return; Escape returns from Settings or dismisses the panel. Settings holds menu mode, units, sample interval, heat alerts and login items. Footer freshness is age since the selected board's last successful reading, not time since a timer fired.

Each board opens with its hero and contextual stats, followed by source notices and units guidance, then a lamp meter and panels. CPU shows its top five processes before the two core platforms. RAM states used and installed GB, OS pressure, the five memory parts, and up to ten apps. HEAT links directly to CPU for attribution. Panels pad 8pt; rows stack 3pt apart. Names use 16 cells for sensors and 15 for processes/apps, with flexible spacing before fixed numeric/status columns so rows fit with persistent native scrollbars.

**The Fixed Platform Rule.** Measured rows keep a fixed order: sensors by board label, cores P1.. then E1.., memory parts APP to FREE. Rows never re-sort by value; ranked rows that jump were rejected.

**The Still Footer Rule.** The shell bounds the selected content instead of measuring every board. The single content viewport scrolls; navigation, updates and footer remain reachable. No blank filler rows or nested sensor/app scrolling. Changing boards or opening Settings resets the content scroll position and stops irrelevant process/footprint sampling.

## Elevation & Depth

Flat by construction: depth comes from material layering (steel frame, black housing, two-tone flap leaves, a dark hinge line) rather than shadow. The only shadow in the system is a lit lamp's glow.

### Shadow Vocabulary
- **Lamp glow** (lamp color at 70% opacity, 3pt radius, 0.5pt y offset): on lit lamps only; unlit lamps carry none.

### Named Rules
**The Housing Not Shadow Rule.** Separation is a black housing or a panel with a 1pt steel-mid hairline at 45%; never a drop shadow, blur or vibrancy material inside the board.

## Shapes

Small, mechanical radii that scale with the part: 1pt on meter lenses and load-bar lamps, 1.5pt on row cells, 2.5pt on row housings, 3pt on hero cells, 5pt on hero housings and board panels. Lamps are 6pt circles. Hero cells carry two 2.5 x 6pt steel axle pins at the hinge and a 2pt hinge line; row cells carry a 0.5pt hinge at 55%.

## Components

### Flap Strip (signature)
A housed row of split-flap cells. **Shape:** flap-black housing, padding equal to the cell spacing. **Ink:** letter white by default, steel light for names and placeholders, heat gradient for values and STATUS. **Motion:** when a character changes, the upper leaf falls (ease-in 0.08s) and the lower leaf rises (ease-out 0.1s), cascading 28ms per cell left to right. With Reduce Motion the character swaps instantly.

### Lamp
6pt circle. Unlit, a dark lens. Temperature lamps light from HOT up in the heat ramp. Utilization lamps mark HIGH in the restricted usage ramp. Tab lamps light amber for selection.

### Lamp Meter
Three minutes of history use 30 time columns (nearest six-second bucket, newest right) and eight adaptive rows. LAST 3 MIN and NOW identify time direction; MIN/MAX labels observed extrema, not axis bounds. Hover explains the adaptive scale. Time is anchored to now, including after sleep; at most one empty bucket holds a preceding value, and longer gaps remain empty. Source states distinguish collecting, waiting, unavailable and no recent readings. Accessibility describes rising, falling or steady direction plus extrema and gap semantics. Temperature lenses retain absolute heat meaning; CPU and memory lenses use utilization colors.

### Lens Bar
Eight horizontal lenses represent each core's utilization with the restricted usage ramp. In the memory breakdown, each lens is one eighth of installed RAM, apportioned by largest remainder so the bars never exceed the whole. Used parts are steel light; cached and free are steel mid. A note defines the categories.

### Fan Panel
On HEAT, fans sit between history and sensors when present. SMC order is stable; five-cell RPM values support 0...20,000. Lenses and ink show relative fan speed with utilization colors. Unreadable speeds show --; unavailable fan access has recovery guidance, while a successful zero-fan reading is simply omitted.

### Board Panel
Flap-black, 5pt radius, 1pt steel-mid hairline at 45%, 8pt padding. Holds the lamp meter, the sensor board, the core platforms, the process boards and the memory breakdown.

### Departure Row
Lamp, name, value and status remain aligned. CPU die rows use temperature reference bands; other sensor types stay neutral. Process and app rows use LOW, MOD or HIGH utilization, with full-name hover/accessibility. Ranked rows settle into position unless Reduce Motion is enabled. CPU has five ranked apps and a neutral UNMEASURED EST remainder derived from all sampled processes; smoothed rows are explicitly non-additive. App footprints are shares of installed RAM and do not add up to total used memory.

### Flap Tabs
Lamp plus 4-cell flap strip per option, 10pt apart. Selected: amber lamp lit, letter-white text. Unselected: unlit lamp, steel-light text. The board tabs carry Cmd-1 to Cmd-3.

### Quit Button
A QUIT flap strip with a separate key segment (command symbol and Q on a flap-top face). Hover turns both amber over 0.12s ease-out. Bound to Cmd-Q.

### New Version Row
Shown outside the scrolling viewport while Sparkle holds an available update: NEW VERSION, version strip and INSTALL. Installation uses Sparkle's own window. The row consumes space inside the fixed shell rather than increasing panel height.

### Login Item Failure Row
Settings distinguishes disabled, enabled, approval pending and failed login changes. Pending and failed states explain the condition and retain a button to Login Items. Heat Alerts distinguishes the requested preference from notification authorization; not-determined offers ALLOW, denied offers System Settings, and allowed notes that Focus can still silence notifications.

### Website (thermals.dev)
`site/index.html` carries the board world to the web: a sticky menu bar strip with a SAMPLE reading, THERMALS in giant flap cells, the offer and the brew command, then the three boards as numbered platforms (amber PLATFORM n signs) running on sample readings, then a ticket machine with install steps and requirements. The existing sample boards model the pre-audit app at a 372px board width (the 400pt popover less its 14pt frame), scaled down to fit narrow platforms; platforms sit side by side on wide screens and scroll-snap on phones, where HEAT / CPU / RAM flap tabs appear. A HOLD / RUN flap pauses the readings; they also stop offscreen and start held under Reduce Motion. Every flap strip is aria-hidden; each board carries its own label.

Website parity with these app changes is tracked separately in [#30](https://github.com/radkode/thermals/issues/30); changing site files deploys production.

### App Icon
The LAST 3 MIN lamp bank as the mark: 7 columns by 8 rows of lenses in a flap-black housing, columns climbing left to right from cool to burn, each lens tinted by its row's heat and unlit HOT and BURN lenses at 16%, on an 824pt continuous squircle (185.4pt radius) in a steel gradient on the 1024pt macOS grid. Chosen by the owner over a single flap cell with a degree sign (read as an O and blurred to a ring at 16px). Source: `AppIcon` in `ThermalsTests/AppIconTests.swift`.

### Menu Bar Reading
CPU die temperature, whole-system load, or both use Barlow Condensed at 15pt, colored for the current appearance and rendered as a non-template image. Missing readings retain an accessible description. OS pressure warnings remain visible even without temperature or in load-only mode. Menu-bar freshness uses timer delivery rather than TimelineView, which caused a status-item update loop on macOS 27 during hosted testing.

## Do's and Don'ts

### Do:
- **Do** use `Board.heat` for temperature and `Board.usage` for utilization, with OS pressure kept explicit.
- **Do** set board values in flap strips at hero (38 x 58pt) or row (11.5 x 19pt) size, uppercase, numbers right-aligned.
- **Do** keep measured rows ordered and let only the selected board scroll inside the bounded shell.
- **Do** reserve heat words for CPU temperature reference bands; use utilization words for CPU and memory.
- **Do** honor Reduce Motion: flips swap instantly and ranked rows stop animating.
- **Do** show placeholders (--, UNAVAILABLE, SAMPLING, COLLECTING READINGS) in steel light rather than a guessed value.

### Don't:
- **Don't** use gauges, rings or system-gray list rows; the board is flaps, lamps and lenses.
- **Don't** use gamer RGB: no rainbow cycling, neon, or glow beyond a lit lamp.
- **Don't** step colors per band or hand-pick a band color; the gradient is continuous within bands.
- **Don't** sort measured rows by value or let rows jump; only processes rank, and they slide.
- **Don't** band a derived aggregate; UNMEASURED EST stays neutral steel.
- **Don't** let the menu bar reading fall back to a monochrome template.
- **Don't** add drop shadows, blur or vibrancy inside the board.
