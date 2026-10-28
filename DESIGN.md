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
  burn-red: "#E5383B"
  heat-cool: "#6F9CC8"
  heat-warm: "#DCE6EE"
  heat-warm-high: "#FFE3A3"
  heat-burn-edge: "#F25A2D"
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

Thermals is a rail concourse departure board where sensors, cores and processes are departures and heat is what lights them. Every reading is set in matte split-flap cells (two leaves with a hinge gap, axle pins on the large cells) inside black housings, mounted on a steel frame. Type is Barlow Condensed in capitals throughout the board. Color is not decoration: a cell's ink and a lamp's glow come from one continuous heat gradient, so the board reads hot or cool before a single number is parsed.

The board is dense and ordered the way a real departures board is. Rows hold their position (sensors by natural order of their board label, cores P1.. then E1..) so the eye can return to the same slot; only the user's processes are ranked, and they slide to their new rank rather than jumping. The popover is a fixed 400pt wide, and all three boards (HEAT, CPU and RAM) share one height so the footer and Quit never move when switching. The board is always rendered dark, regardless of system appearance; only the menu bar reading adapts to a light scheme.

This world was chosen by the owner over a liquid-crystal strip. It refuses the stock stats popover (gauges, rings, system-gray list rows) and refuses gamer RGB: no rainbow cycling, no neon, no glow beyond a lit lamp.

**Key Characteristics:**
- Split-flap cells for every value; steel column labels name the data.
- One heat gradient, continuous within bands, shared by the popover and the menu bar.
- Fixed row order; only processes rank, and they animate to their new place.
- Four named heat bands (COOL, WARM, HOT, BURN) spelled out on the board as STATUS.
- Steel frame, black housings, matte flaps; no cards, no translucency, no system materials inside the board.

## Colors

A near-black and steel board where all chroma belongs to heat: steel blue for cool, letter white for warm, amber for hot, red for burn.

### Primary
- **The Heat Gradient** (stops: Cool Steel Blue `heat-cool` at 0, Warm Letter Frost `heat-warm` at 1/3, Pale Sodium `heat-warm-high` at 0.55, Departure Amber `amber` at 2/3, Ember Orange `heat-burn-edge` at 0.85, Burn Red `burn-red` at 1): the single source of reading color, interpolated linearly in RGB between stops by `Board.heat(level)`. It inks hero numbers, row values, STATUS words, lit lamps, lamp-meter lenses, core load bars and the menu bar reading. Stop positions coincide with `HeatLevel` band edges, so a temperature and a load in the same band land in the same stretch of the gradient.
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
- **Steel Light** (`steel-light`): column labels, unselected tab text, sensor and process names below BURN, placeholder values, NOMINAL pressure, and the neutral KERNEL + OTHERS row.
- **Letter White** (`letter-white`): selected tab text, FAIR pressure, the default flap ink, the lamp-meter range readout.

### Named Rules
**The One Gradient Rule.** Every heat-colored element, in the popover and the menu bar, takes its color from `Board.heat(level)`. No element picks a band color by hand, and color is continuous within a band, never stepped.

**The Derived Is Neutral Rule.** An aggregate the app derives rather than measures (KERNEL + OTHERS) is shown in steel light with an unlit lamp and an empty STATUS. It is never banded with per-process thresholds.

**The Always Colored Rule.** The menu bar reading is always heat-colored (rendered as a non-template image), in both appearances, and its level is raised to at least HOT under serious and BURN under critical thermal pressure.

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
- **Label** (Medium 500, 11pt, 1.6pt tracking, uppercase, steel light): column and stat labels (SENSOR, °C, STATUS, LOAD, PRESSURE, LAST 3 MIN, MENU BAR, UPDATED) and the COLLECTING READINGS placeholder.
- **Menu bar** (SemiBold 600, 15pt, 0.4pt tracking, tabular digits): the reading in the menu bar only.

### Named Rules
**The Cell Is The Unit Rule.** Board text is set character by character into a fixed count of flap cells, uppercased, padded with blank cells or truncated to fit. Numbers are right-aligned in their strip; names are left-aligned.

**The Two Sizes Rule.** Flap text comes in exactly two sizes, hero and row. Hierarchy beyond that comes from position and heat color, not new sizes.

## Layout

A single vertical column inside a 400pt-wide popover with a 14pt frame and 14pt between sections: flap tabs (HEAT, CPU, RAM; Cmd-1 to Cmd-3), the selected board, MENU BAR tabs (TEMP, LOAD, BOTH), TEMPERATURE tabs (°C, °F), UPDATE EVERY tabs (3 S, 6 S, 10 S), LAUNCH AT LOGIN tabs (ON, OFF), a failure row only when macOS refuses a login-item change, a NEW VERSION row only while an update waits, then a footer with UPDATED clock left and Quit right.

Each board opens with a header (hero flap strip left under its label, two right-aligned stats stacked 9pt apart on the right), then the lamp meter, then board panels. Board panels pad 8pt; rows stack 3pt apart; columns sit 6pt apart at widths computed from cell counts (lamp 6pt, name 18 cells on HEAT or 17 on CPU processes, value 3 or 4 cells, STATUS 4 cells), so headers align with rows exactly. The CPU board splits cores into PERFORMANCE and EFFICIENCY platforms side by side, 12pt apart. The RAM board's hero is MEMORY USED (app + wired + compressed) with SWAP and PRESSURE stats, then a MEMORY breakdown panel (APP, WIRED, COMPRESSED, CACHED, FREE in fixed order, each with a share bar and GB), then YOUR APPS ranked by footprint.

**The Fixed Platform Rule.** Measured rows keep a fixed order: sensors by board label, cores P1.. then E1.., memory parts APP to FREE. Rows never re-sort by value; ranked rows that jump were rejected.

**The Still Footer Rule.** Every board is laid out at all times and the popover takes the tallest height, so switching boards never moves the footer. The HEAT and RAM boards fill spare height with rows, never with empty space: HEAT pads its sensors with blank flap rows (unlit lamp, empty strips) and scrolls past the space available; RAM shows as many ranked apps as fit, then blank rows.

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
6pt circle. Unlit, a dark lens. Lit, it fills with its color and glows. Row lamps light only from HOT up, in the row's heat color; tab lamps light amber for the selected option.

### Lamp Meter
Three minutes of history as a bank of 30 time columns (peak per 6s slice by nearest slice, newest right; an empty slice after the first reading holds the previous value, so the bank never shows holes) by 8 rows, 1.5pt gaps, 46pt tall, inside a board panel headed LAST 3 MIN with the low to high range at right. Rows are fitted to the window's readings with a minimum span (10° for temperature, 20% for load, 10% for memory). Lenses take the reading's own level, never the pressure-raised one: pressure raises only the hero (and the menu bar), since the meter keeps no per-sample pressure. A lit lens takes the heat color at its row's value; unlit lenses in HOT and BURN rows show that color at 16% so the danger zone is visible empty. Under two readings it shows COLLECTING READINGS.

### Lens Bar
The lamp meter's row vocabulary turned sideways: 8 lenses, 10pt tall. On a core it lights up to the core's load at fixed floors (1 to 87.5%), with the lit and dim-danger heat treatment. On the memory breakdown each lens is an eighth of physical memory, apportioned across the five parts by largest remainder so the bars never light more than the whole; it is a share, not a reading, so it is unbanded: steel light for the used parts (APP, WIRED, COMPRESSED), steel mid for the reclaimable ones (CACHED, FREE). Breakdown rows carry an unlit lamp and no STATUS.

### Fan Panel
On the HEAT board between the lamp meter and the sensors, only on Macs with fans: FANS and RPM labels, then one row per fan in SMC order (lamp, FAN n, lens bar, 4-cell RPM). The lens bar and RPM ink take the heat color of how far the fan is through its min to max range, on the load scale, with the core rows' lit and dim-danger treatment. An unreadable fan shows -- in steel light.

### Board Panel
Flap-black, 5pt radius, 1pt steel-mid hairline at 45%, 8pt padding. Holds the lamp meter, the sensor board, the core platforms, the process boards and the memory breakdown.

### Departure Row
Lamp, name strip, value strip, STATUS strip. The name is steel light until BURN, when it takes the heat color too. Process rows animate to a new rank with the settle curve (cubic-bezier 0.16, 1, 0.3, 1 over 0.5s), disabled under Reduce Motion; on CPU the top 5 processes show, then KERNEL + OTHERS pinned last, 6pt apart, in neutral steel. On RAM, app rows show GB and band by share of physical memory (WARM 10%, HOT 25%, BURN 40%); there is no derived remainder row, since footprints don't add up to memory used.

### Flap Tabs
Lamp plus 4-cell flap strip per option, 10pt apart. Selected: amber lamp lit, letter-white text. Unselected: unlit lamp, steel-light text. The board tabs carry Cmd-1 to Cmd-3.

### Quit Button
A QUIT flap strip with a separate key segment (command symbol and Q on a flap-top face). Hover turns both amber over 0.12s ease-out. Bound to Cmd-Q.

### New Version Row
Shown only while Sparkle holds a found update: NEW VERSION label left, like the settings rows, then at right the version in a flap strip behind a lit amber lamp (a selected tab's treatment) and an INSTALL flap button 10pt after it. The flap button is a plain flap strip that hovers amber like Quit. INSTALL brings up Sparkle's own window to download, verify and relaunch.

### Login Item Failure Row
Shown directly under LAUNCH AT LOGIN when macOS rejects a register or unregister request. An amber lamp and a steel-light board label say LOGIN ITEM CHANGE FAILED, with a SETTINGS flap button that opens Login Items in System Settings. A successful retry clears the row. The underlying system error is logged.

### Website (thermals.dev)
`site/index.html` carries the board world to the web: a sticky menu bar strip with a SAMPLE reading, THERMALS in giant flap cells, the offer and the brew command, then the three boards as numbered platforms (amber PLATFORM n signs) running on sample readings, then a ticket machine with install steps and requirements. Boards are 1:1 ports at the app's 372px board width (the 400pt popover less its 14pt frame), scaled down to fit narrow platforms; platforms sit side by side on wide screens and scroll-snap on phones, where HEAT / CPU / RAM flap tabs appear. A HOLD / RUN flap pauses the readings; they also stop offscreen and start held under Reduce Motion. Every flap strip is aria-hidden; each board carries its own label.

### App Icon
The LAST 3 MIN lamp bank as the mark: 7 columns by 8 rows of lenses in a flap-black housing, columns climbing left to right from cool to burn, each lens tinted by its row's heat and unlit HOT and BURN lenses at 16%, on an 824pt continuous squircle (185.4pt radius) in a steel gradient on the 1024pt macOS grid. Chosen by the owner over a single flap cell with a degree sign (read as an O and blurred to a ring at 16px). Source: `AppIcon` in `ThermalsTests/AppIconTests.swift`.

### Menu Bar Reading
The CPU die temperature, load, or both, in the system face, each part colored from the heat gradient for the current appearance, rendered as a non-template image so macOS does not strip the color. With no reading, a thermometer SF Symbol.

## Do's and Don'ts

### Do:
- **Do** take every reading's color from `Board.heat(level)`, dark stops in the popover and light stops on a light menu bar.
- **Do** set board values in flap strips at hero (38 x 58pt) or row (11.5 x 19pt) size, uppercase, numbers right-aligned.
- **Do** keep measured rows in fixed order and pad short boards with blank flap rows so the footer stays put.
- **Do** spell the band out as COOL, WARM, HOT or BURN in a STATUS column wherever a row is banded.
- **Do** honor Reduce Motion: flips swap instantly and ranked rows stop animating.
- **Do** show placeholders (--, UNAVAILABLE, SAMPLING, COLLECTING READINGS) in steel light rather than a guessed value.

### Don't:
- **Don't** use gauges, rings or system-gray list rows; the board is flaps, lamps and lenses.
- **Don't** use gamer RGB: no rainbow cycling, neon, or glow beyond a lit lamp.
- **Don't** step colors per band or hand-pick a band color; the gradient is continuous within bands.
- **Don't** sort measured rows by value or let rows jump; only processes rank, and they slide.
- **Don't** band a derived aggregate; KERNEL + OTHERS stays neutral steel.
- **Don't** let the menu bar reading fall back to a monochrome template.
- **Don't** add drop shadows, blur or vibrancy inside the board.
