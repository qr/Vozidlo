# Vozidlo UI improvements (fēnix 7 Pro)

Status: implemented in 1.1.0. All seven decisions are settled (section 6): D1, D2, D4 and D7 decided as hero list, separate charging screen, action list and own page dots; D3 decided as Škoda Electric Green; D5 implemented as solid icons; D6 implemented as one tap runs a row (`CustomMenu`). Two checks on the watch are still open: what the number font draws for missing glyphs, and whether a single tap runs a row. The rest of this document is kept as the record of the proposal.

Proposal of 2026-10-07. Basis: code at `3c4d005`, the screen board `docs/design/vozidlo-screens.html`, fēnix 7 Pro device files from SDK 9.2.0, and desk research on MyŠkoda, Škoda corporate design and Garmin UX guidelines (sources at the end).

## 1. Summary

**What is wrong today**

1. **Text falls off the round screen.** 15 distinct lines lose pixels to the curve; the bottom hints on Status, Charging and Find my car lose 60 to 65 % (section 2.1).
2. **The big number font has no letters.** `FONT_NUMBER_MEDIUM` on the fēnix 7 Pro holds only digits, space and `# % + - . / : °`, yet it draws LOCKED, OFF, km, m, °C and the em-dash glyph.
3. **Home does not scroll properly.** Tiles are not clipped (a scrolled row covers the status strip, a fourth row peeks out at the bottom), focus jumps back to the top after every action, and touch can never scroll the grid because swipes open Status and Charging.
4. **No consistent visual language.** Raw API enums on screen (`READY_FOR_CHARGING`, `GASOLINE`), ALL CAPS next to sentence case, orange meaning both "error" and "unlocked", four different age formats, two icon styles.
5. **Navigation is inconsistent.** Menus slide in left and out down, More stays open after a choice, a profiles screen asks for SELECT that does nothing.

**Direction**

- Short term: a batch of low-risk fixes inside the current architecture (Part A, three PR-sized batches).
- Target: a calm, dark "Night Panel" look that borrows the *design language* of MyŠkoda and Škoda's current cars (one hero value per screen, status chips, solid flat shapes, symmetry, one accent, timestamps on every value) without any protected Škoda element (Part B), with per-screen layouts verified against the circle (Part C).
- Seven decisions for Bart (section 6). The big one: whether DOWN on home keeps opening Status, or scrolls a list of actions.

## 2. Findings

### 2.1 Text lost to the round edge (measured)

Every screen's drawing code from the board was run headless; each line's glyph band was checked against the chord at its height (r = 130). Garmin's own menus excluded.

| Screen | Text | Font, y | Width | Hidden |
|---|---|---|---|---|
| Home | `100%  READY_FOR_CHARGING  LOCKED` | xtiny, 18 | 255 | 110 px (43 %) |
| Home, scrolled | tile labels of row 0 | xtiny, 4 | 31 | 20 px (63 %) |
| Home | `Settings` (fourth row) | xtiny, 222 | 54 | 3 px |
| Home | `UP charging - DOWN status` | xtiny, ≈208 | 175 | fits, but pushed into the grid, on the caret, grey on grey tiles |
| Status 1 to 5 | `UP/DOWN pages - SELECT refresh` | xtiny, 238 | 221 | 137 px (62 %) |
| Status, no data | `No data yet - refresh to fetch` | small, 150 | 302 | 58 px (19 %) |
| Charging detail | `SELECT refresh - MENU actions` | xtiny, 240 | 204 | 133 px (65 %) |
| Charging profiles | `CHARGING PROFILES` | xtiny, 12 | 138 | 12 px |
| Charging profiles | `1/2 - UP/DOWN` | xtiny, 236 | 99 | 4 px |
| Find my car | `FIND MY CAR` | small, 12 | 141 | 6 px |
| Find my car | address, cut at 40 characters | xtiny, 56 | 268 | 49 px (18 %) |
| Find my car, moving | last parked address | xtiny, 168 | 268 | 31 px |
| Find my car | `SELECT map - MENU navigate` | xtiny, 240 | 193 | 122 px (63 %) |
| Find my car, GPS or moving | `MENU for options` | xtiny, 240 | 113 | 42 px (37 %) |
| Target temperature | `UP/DOWN to adjust` | xtiny, 230 | 124 | 3 px |

Root causes: plain `drawText` at `y = height - 20/22` (StatusView.mc:604, ChargingDetailView.mc:355, LocationView.mc:745); truncation by character count (`_shorten` 30/36/40/42, no ellipsis); and a bug in `TextBlock.drawFittedLine`: `fittedLineY` checks a box centred on y (TextBlock.mc:173) but `drawText` draws y as the top (:204), so every fitted line lands about 9 px lower than checked.

### 2.2 Number font without letters

`FONT_NUMBER_MEDIUM` (Bionic Cond Bold 36, line box 74 px) is used for words and units at StatusView.mc:344, :416; LocationView.mc:703; TargetTemperatureSettingsView.mc:52. Toggle "Font gaps" on the board to see the gaps. What the watch actually draws for missing glyphs still needs a look on the device.

### 2.3 Scrolling and navigation

fēnix 7 Pro input: UP = previousPage (hold = menu), DOWN = nextPage, START = select, BACK = back; swipe up = nextPage, swipe down = previousPage, tap = select.

| Area | Problem | Where |
|---|---|---|
| Home grid | Tiles not clipped; the comment claims the Dc clips them | ControlsView.mc:560-564 |
| Home grid | `onShow` rebuilds the grid and resets scroll, so focus jumps to the top after any menu, confirmation or child view | :399-401, :519, :528 |
| Home grid | Tile reset to default after firing, focus outline lost | :1075 |
| Home grid | Swipes open Status and Charging, so touch can never scroll | :1079-1096 |
| Home grid | Checked on the watch (2026-10-07): UP/DOWN move the tile focus (`setKeyToSelectableInteraction`, :529). `onPreviousPage`/`onNextPage` are never reached by the buttons, so Charging detail, charge limit, charge mode and profiles cannot be reached with buttons (only an unconfirmed swipe down), and the hint "UP charging - DOWN status" is wrong | ControlsView.mc:529, :983, :1079-1096 |
| Home grid | Scroll jumps 52 px with no animation | GridScroll.mc |
| Status | Up to 6 door/window items built, 3 drawn; bonnet and trunk lost. Sub-lines at 16 px pitch with a 19 px font overlap | StatusView.mc:446, :451 |
| Status, Charging | Any stray tap refreshes and spends quota | StatusView.mc:634, ChargingDetailView.mc:478 |
| Charging profiles | Shows "SELECT to load", no `onSelect` in the delegate | ChargingProfilesView.mc:229, :310-342 |
| Charge limit, target temp | Swipe up lowers the value | ChargingLimitView.mc:193-206 |
| Menus | Pushed SLIDE_LEFT, popped SLIDE_DOWN; Find my car menu SLIDE_UP. Garmin: menus slide in from and out to the right | ChargingDetailView.mc:534, ChargingModeView.mc:92, LocationView.mc:845 |
| More | `onSelect` does not pop, BACK returns to More | ControlsView.mc:1120-1125 |
| More | Labels carry the tile's "\n" | :732 |
| Tile order | Focus does not follow a moved item (no `setFocus`) | TileOrderView.mc:38-44 |
| Map | No MENU handler, no way to navigate from the map | MapPreviewView.mc |

### 2.4 Reachability after the device check

Because UP/DOWN move the tile focus, nothing on home opens Charging detail with buttons. No tile opens it (the charging tiles send start/stop commands), More never lists it, and home has no MENU handler. Everything under it (charge limit, charge mode, profiles) is unreachable with buttons too. Status stays reachable through the Status tile (or More). Both NEW home variants fix this: the grid gets a Charging tile, the hero list has Charging and Status rows.

### 2.5 Visual consistency

- **Raw enums**: home strip (ControlsView.mc:927), glance (GlanceView.mc:190), complications (Complications.mc:74), Status sub-lines (doors, windows, lights, engine type, climate, window heating). `ChargingLogic.stateLabel` exists but Status does not use it.
- **Casing**: ALL CAPS titles ("LOCK & DOORS", "FIND MY CAR") next to sentence-case menus; "LOCKED" on watch screens, "Locked" in complications.
- **Colour meanings overlap**: orange = error and unlocked; green = success, selected tile, bearing arrow. Home hint is dark grey on dark grey tiles.
- **Monochrome test (US-060)** only wraps ControlsView and StatusView; in mono mode tile labels become white on white.
- **Duplicated helpers**: `_ageText` ×3 plus GlanceFormat ("1h 5m ago", "1h ago", "1 h ago"), `_lockLabel` ×4, `_shorten` ×7.
- **Icons**: StateIcons are filled shapes; complication SVGs are 1.6 px outlines on #2B2F36 plates, 24×24 while the device expects 28×28.
- **Best-practice breach**: onboarding views load resources inside `onUpdate` (OnboardingView.mc:94, :96; OnboardingExpiryNoticeView.mc:26).

## Part A. Quick fixes inside the current architecture

Each item: fix, location, effort (S/M), test.

**Batch 1: geometry and fonts (biggest visible gain, lowest risk)**

| # | Fix | Where | Effort | Test |
|---|---|---|---|---|
| A1 | Draw fitted lines with `TEXT_JUSTIFY_VCENTER` so the checked box is the drawn box | TextBlock.mc:204 | S | extend `aBottomHintMovesUpUntilItFits` |
| A2 | New `TextBlock.drawHint(dc, text, minY)`: never rises above `minY`, draws nothing if it cannot fit. Usable widths for xtiny box tops: y 210 = 152 px, 216 = 137, 222 = 119, 228 = 97, 238 = 39 | TextBlock.mc | S | `aHintNeverRisesAboveMinY` |
| A3 | Replace bottom hints with short ones via `drawHint`: Status "SELECT refresh", Charging "MENU actions", Find my car "SELECT map". Home: only when no status message and no rows below | StatusView.mc:604, ChargingDetailView.mc:355, LocationView.mc:745, ControlsView.mc:983 | S | |
| A4 | `TextBlock.drawTitle`: fit from the top edge downward (mirror of `fittedLineY`); sentence case | LocationView.mc:605, ChargingProfilesView.mc:213 | S | `aTopTitleMovesDownUntilItFits` |
| A5 | `TextBlock.fitToWidth(text, maxWidth, measure)` with "…", width from `lineWidth()` at the line's y; replaces all `_shorten` | 7 call sites | S | reuse `measurer()` stub |
| A6 | Home strip becomes "100% · Locked", fitted; charging state stays as icon | ControlsView.mc:943 | S | |
| A7 | Status "No data yet" on two lines: "No data yet" / "SELECT to refresh" | StatusView.mc:465 | S | |
| A8 | Number font guard `isNumberGlyphs(s)`; words in `FONT_MEDIUM`; numbers with unit via `drawValueWithUnit` (digits in number font, unit in text font, shared baseline) | StatusView.mc:344, :416, LocationView.mc:703, TargetTemperatureSettingsView.mc:52 | M | `isNumberGlyphsRejectsLettersAndEmDash` |
| A9 | Sub-line pitch = font height; `StatusSummary.lines(values, max)`: open or unlocked first, "All closed" collapse, "+N more", never hide an insecure item | StatusView.mc:446-451 | M | `StatusSummaryTests` ("open trunk survives truncation") |

**Batch 2: home grid behaviour** (first check on the watch which input wins for UP/DOWN)

| # | Fix | Where | Effort |
|---|---|---|---|
| A10 | `dc.setClip(0, 50, 260, 154)` around `View.onUpdate`, carets outside the clip; correct the comment | ControlsView.mc:416, :560 | S |
| A11 | Keep layout and scroll on `onShow` when the tile signature is unchanged; only refresh the strip | :399, :519, :528 (+ `ControlTiles` signature test) | S |
| A12 | After firing, return the tile to `:stateHighlighted` | :1075 | S |
| A13 | `onSwipe` in `ControlsDelegate`: scroll the grid when rows remain, else fall through to page behaviour | delegate | S |
| A14 | More: pop before `activate`; strip "\n" from menu labels | :1120-1125, :732 | S |
| A15 | Ignore taps for refresh (`onTap` returns true); refresh only on START or the menu | StatusView.mc:634, ChargingDetailView.mc:478 | S |

**Batch 3: consistency**

| # | Fix | Where | Effort |
|---|---|---|---|
| A16 | One label source: `chargingShort` ("Charging", "Plugged in", "Plug in", "Paused"), door/window/lights/engine/climate words; unknown values humanised, not raw | GlanceFormat (glance-safe), StatusView, ControlsView, Complications | M |
| A17 | One age helper and one lock label; delete the copies | GlanceView.mc, StatusView.mc:585, ChargingDetailView.mc:371, LocationView.mc:766 | S |
| A18 | Sentence case everywhere; "…" instead of "..." | all views | S |
| A19 | Charging age gets the stale style; profiles get `onSelect` retry; steppers: swipe up increases | ChargingDetailView, ChargingProfilesView, ChargingLimitView, TargetTemperatureSettingsView | S |
| A20 | Menus: push SLIDE_LEFT, pop SLIDE_RIGHT everywhere; tile order `setFocus` on the moved item | ChargingDetailView.mc:534, ChargingModeView.mc:92, :123, LocationView.mc:845, :875, Onboarding menu, TileOrderView.mc:38 | S |
| A21 | Colour roles: error = red + "!", insecure = amber + word or icon, focus = accent (Škoda green); selected tile white fill, black text; mono mode draws outlines; route all views through `MonochromeTest` and cache its flag per `onShow` | ControlsView, ChargingDetailView, LocationView, MonochromeTest.mc | S |
| A22 | Load onboarding strings in `onShow`, not `onUpdate` | OnboardingView.mc:94, :96, OnboardingExpiryNoticeView.mc:26 | S |
| A23 | Two `tools/checks.py` rules: no `loadResource` in `onUpdate`; no SLIDE_UP/DOWN in `Menu2InputDelegate` files | tools/checks.py | S |

### Resolutions applied in the proof of concept

The proof of concept (`docs/design/vozidlo-poc.html`) settles small conflicts between Parts A, B and C as follows: titles FONT_TINY in the accent at y 34 (none on Find my car and the glance); hints only as bezel arcs or glyphs (A3's short text hints are superseded); digits and % in the number font, words in FONT_MEDIUM; no text on grey fills (home band black with a rule at y 66, closed chips and unfocused tiles as outlines); stale in amber (amends US-009's red); cable chip "! Plug in"; green only for transient success icons (battery care and "Here" become white chips); "Windscreen heat off".

## Part B. Target rework: "Night Panel"

The name refers to a car's instrument panel at night and avoids Škoda's own vocabulary.

### B1. Principles

1. One hero per screen, at the widest chord (y ≈ 95 to 165). Everything else is a chip or one line.
2. Every value shows its age; stale is shape plus colour (amber chip with "!").
3. A gesture means the same on buttons and touch: UP/DOWN and swipes either scroll the list you are in or page the loop you are in, never both on one screen.
4. Garmin components first (CustomMenu, Menu2, ViewLoop, ActionMenu, Confirmation, toast, Personality hint arcs); custom drawing only for hero, chips and icons.
5. One accent, words before colour, every screen passes the monochrome test.
6. The chord is the grid: no constant y or width without `TextBlock.halfChord`/`lineWidth`.
7. Škoda-like in calm, not in identity.

### B2. Škoda feel without Škoda marks

Borrowed from MyŠkoda and Škoda's current design language (generic, safe):
- One hero value per screen with its label; "updated" timestamp per value (the MyŠkoda widgets do this).
- Status chips: icon plus one word ("Locked", "Plugged in").
- A mostly monochrome dark UI with one accent; greys as "dark chrome".
- Solid flat 2D shapes, symmetry, straight edges with soft rounding; a horizontal band or thin line as a layout motif (echo of the black front panel and light strip on current Škodas).
- Scope like Škoda's own Apple Watch app: battery, lock and heating first; everything else one level down.
- Deliberate friction for risky actions (Škoda uses the S-PIN; Garmin's Confirmation is the native equivalent).

Never use (docs/decisions.md "Branding"): the winged arrow or wordmark, Škoda Next or a lookalike, the angled "facet" polygons, official car renders or MyŠkoda assets, the labels "MyŠkoda", "Simply Clever", "Modern Solid".

### B3. Palette (64-colour MIP)

| Token | Value | Role |
|---|---|---|
| BG | 0x000000 | everywhere |
| RULE | 0x555555 | lines, chip and unfocused row outlines, inactive dots; never text on a grey fill |
| TEXT_1 | 0xFFFFFF | hero, labels |
| TEXT_2 | 0xAAAAAA | units, sub-labels, age |
| ACCENT | 0x55FFAA Škoda Electric Green (#78FAAE on skoda-auto.com, as the 64-colour screen shows it) | focus fill (black text), titles, START hint, page indicator, ring while charging |
| POSITIVE | 0x00FF00 | transient check icon or toast only |
| WARNING | 0xFFAA00 amber | unlocked, open, stale, connect cable; always with icon or "!" |
| DESTRUCTIVE | 0xFF0000 | failed request, phone offline, stop-type confirmations; always with "!" or ✕ |

Accent decided 2026-10-07 (D3): Škoda's Electric Green, read from skoda-auto.com with Chrome (#78FAAE on the action buttons; Emerald #0E3A2F for dark areas, which the watch shows as #005555, too dark for an accent). The success check stays Garmin's #00FF00 and only appears as a small transient icon. Orange 0xFF5500 is retired. docs/decisions.md "Branding" records this decision; the logo, typeface and name rules there are unchanged.

### B4. Type, shapes, icons, copy

- **Type**: titles `FONT_TINY` (or xtiny) sentence case at y ≥ 34; hero digits `FONT_NUMBER_MEDIUM`; hero words `FONT_MEDIUM`; units `FONT_MEDIUM`/`FONT_TINY` in TEXT_2, baseline-aligned; chips, age, meta `FONT_XTINY`. No text hints at the bottom: Personality hint arcs or small glyphs at the bezel next to the button (START right-top, UP left-middle, DOWN left-bottom; BACK needs none). The bezel zone (r ≥ 122) holds only arcs, dots and glyphs.
- **Shapes**: chip = pill 20 to 22 px high, radius = half height, icon r 6 plus one word; at most 3 per row. Focused row = full accent pill with black text; under monochrome a white fill. Cards radius 6.
- **Icons**: one family, solid silhouettes with 2 px cut-outs drawn by `StateIcons.mc` (thin round-cap outlines fade on MIP and cost extra draw calls). Add battery, range, fan, pin, list, gear, stop, refresh. Redraw the four complication SVGs as white silhouettes at 28×28 on transparent.
- **Copy**: sentence case everywhere; enums humanised in one `Labels` module (unknown values humanised generically); one word per chip; age "Just now / 5 min / 2 h / 3 d" (+ "ago" only on age lines); truncate by pixels with "…".

### B5. Code modules

- `ui/Theme.mc` (glance-safe): colour and font tokens, transitions, `c(token)` with the monochrome flag cached per `onShow`.
- `ui/Age.mc` (glance-safe): `text(seconds)`, `isStale(seconds)`; replaces the four age variants.
- `ui/Labels.mc`: all enum-to-word mapping (takes over `ChargingLogic.stateLabel`, `chargeTypeLabel`, `modeLabel`, the lock labels).
- `ui/Ui.mc` (app only, keeps the 64 KB glance small): `drawHeader`, `drawHero`, `drawValueWithUnit`, `drawChip`/`drawChipRow`, `drawHintArc`, `drawRing`; pure helpers `chipWidth`, `fit`, `numberFontSafe` with unit tests.
- `TextBlock` stays the geometry layer (plus the top-edge mirror of `fittedLineY`); `StateIcons` the icon layer; `model/StatusModel.mc` moves fetch and cache projection out of `StatusView` so all pages share one request.
- Every view precomputes strings, icons and colours in `onShow` or the response callback; `onUpdate` only calls `Ui`.

### B6. Navigation model

**The core conflict.** With `setKeyToSelectableInteraction(true)` the buttons cycle tiles, while the delegate also maps UP to Charging and DOWN to Status, and swipes arrive as the same two events. No design keeps "DOWN = Status" and a scrolling home at the same time. Bart decides (D1).

| | A. Grid plus fixes | B. Hero + action list (recommended) | C. Fixed deck |
|---|---|---|---|
| Shape | Selectable grid, clipped, swipe scroll (Part A) | `CustomMenu`: title area = hero (SoC, lock chip, age), rows = up to 7 actions in TileOrder order, focus on the primary | Hero + primary on START; other actions in a hold-UP menu |
| Scroll | custom, no momentum | native drag, flick, focus animation, clipping | none |
| START | fires highlighted tile | fires focused row: primary in 1 press (US-037) | fires primary |
| UP at landing | moves focus (checked on the watch) | overscroll opens Charging (1 press, US-023) | Charging |
| DOWN at landing | moves focus (checked on the watch) | next action; Status = last row, hero tap, or overscroll at the end | Status |
| Cost | conflict stays | DOWN no longer opens Status in one press | actions 2 to 7 hidden |

Risk for B: the SDK only fires `onWrap` on button devices, so touch users reach Status via the hero tap or a Status row.

**Status**: `ViewLoop` over the visible pages, wrap on, accent indicator. Each page: title, hero, up to 3 chips (lock page: a 2×3 chip grid for doors, windows, bonnet, trunk, lights, sunroof), age. START opens an ActionMenu with Refresh first (quota friction, same on every page). Option D2: merge Charging detail into the loop as the charging page; home opens the loop at that page for UP and at the lock page for DOWN.

**Charging**: charge limit as a Menu2 of 6 values focused on the current one with a "Recommended" sub-label (or keep the stepper with the scale-dot spec in C4); charge mode as single-choice Menu2 with a check; profiles as a ViewLoop of cards.

**Find my car**: distance hero, bearing as a pointer on the bezel ring, address wrapped in two lines; START = map; ActionMenu Navigate / Refresh; MENU on the map also offers Navigate.

**Menus**: in Škoda green, drawn by the app as a `CustomMenu` (title and focused row in the accent, black text on the focused row), because Menu2 cannot be recoloured on the fēnix 7 Pro (themes unsupported, per the SDK docs); a CustomMenu keeps Garmin's scrolling and key/touch handling. Action menus become a small custom view in the same style. Icons per row via `CustomMenuItem.draw` with StateIcons, `ToggleMenuItem` for on/off, sentence case, at most 7.

**Transitions**: Status SLIDE_UP, Charging SLIDE_DOWN, drill-in SLIDE_LEFT and back SLIDE_RIGHT, system dialogs SLIDE_IMMEDIATE; as `Theme` constants.

### B7. Phasing

1. P0: `Theme`, `Age`, `Labels`, `Ui`; move the existing screens onto them (no navigation change).
2. P1: Status as ViewLoop (+ D2).
3. P2: home per D1.
4. P3: menus, transitions, icons, complications.

Each phase signed off on the watch, not only in the simulator (decisions.md: "a screen that looks correct in the simulator has not been checked"). Store screenshots and the screen board are regenerated after each phase.

### B8. Risks

- Firmware variance in CustomMenu title and ViewLoop indicator (fēnix 7 vs 8/9): test on fenix7pro and fenix8solar47mm.
- Memory: about 256 KB of 786 KB used; ViewLoop creates pages lazily; only Theme, Age, StateIcons go into the glance (measure before and after). No custom fonts needed.
- The stock fēnix ViewLoop indicator is a large left arc that developers find inferior to Garmin's own dots; custom dots mean owning the paging (D7).

## Part C. Screen specs (verified against the circle)

Conventions: drawText y is the top of the box; usable width = chord minus 2 × margin (8 px default; 12 on ring screens; 20 on Find my car). Every check is `box top to bottom → usable ≥ text width`.

### C1a. Home, grid variant

| Element | Spec | Check |
|---|---|---|
| Deck band | `fillRectangle(0,0,260,66)` 0x555555 | |
| Row 1 | "100%" small white, y 14 | 14 to 46 → 100 ≥ 56 |
| Row 2 | charge icon · padlock + "Locked" xtiny · climate icon, y 45 (icons cy 54) | 178 ≥ 118 |
| Tile window | `setClip(0,68,260,144)` | |
| Tiles | 90×44, r 8, x 35/135, rows y 70/118/166 (48 pitch); focused = accent fill, black label, 2 px white outline | worst corner r 121 ≤ 122 |
| Scroll indicator | arc r 126, ±15°, pen 3, thumb sized visible/total (replaces carets) | bezel zone |
| Status line | xtiny y 214: age or command result, max 142 px ("Phone offline", full text in the toast) | 142 ≥ 128 |
| UP / DOWN glyphs | bolt at (20,111), list at (24,166) | clear of x 35 |

### C1b. Home, hero + action list variant

| State | Element | Spec | Check (margin 12) |
|---|---|---|---|
| all | SoC ring | `drawArc` r 126, pen 4, track 0x555555, white fill (accent while charging, plus bolt chip) | |
| focus on row 0 | Hero | "100" numMed y 20 + "%" small baseline-aligned | 114 ≥ 102 |
| | Chips | y 96, 20 px pills: padlock "Locked", plug "Plugged in" | 226 ≥ 190 |
| | Focused row | pill (24,120,212,40) accent, label medium black at 140; fallback small if > 196 px | "Start ventilation" 196 |
| | Next rows | tiny y 164; xtiny y 196 | 202 ≥ 152; 172 ≥ 102 |
| | Status line | xtiny y 218, max 100 px ("12 min ago", "Sent") | 122 ≥ 71 |
| focus ≥ 1 | Summary | xtiny "100%  Locked" y 22, previous rows mirrored above the focus | 120 ≥ 89 |

No 7-tile cap needed; Charging, Status, Find my car and Settings become rows in TileOrder order.

### C2. Status pages

Shared: page dots at r 118 on the left (current filled white r 4, others grey r 3, so size also marks the page); title tiny y 34; refresh glyph at START; no "1/5" and no bottom hint.

| Page | Spec | Check |
|---|---|---|
| Titles | "Lock & doors", "Fuel & range", "Charging", "Odometer", "Air conditioning" at y 34 | usable 158 ≥ 153 max |
| Lock & doors | padlock r 12 + "Locked" medium y 70; chip grid 2×3, 89×22, x 38/133, y 116/140/164 (closed: grey fill white text + check; open: amber fill black text + "!"); unsupported items drop out; age y 192 | 214 ≥ 142; corner r 108 |
| Fuel & range | "436" numMed y 64 + "km" medium; sub-lines xtiny y 142/162 "Petrol 62%", "Electric 100%" | 210 ≥ 206 (tight; else unit to sub-line) |
| Charging | "100%" numMed + plug icon; "Plugged in", "36 km range" | 210 ≥ 155 |
| Odometer | "123456" + "km", no sub-lines | 210 ≥ 206 |
| Air conditioning | climate icon + "Off"/"Heating" medium y 70; "Windscreen heat off", "Rear window heat off" | 222 ≥ 135 |
| Age | xtiny y 188; stale tiny "! 17h 0m ago" amber y 186 | 192 ≥ 128 |
| No data | "No data yet" small y 98; "START to refresh" xtiny grey y 136 | 236 ≥ 156 |

### C3. Charging detail

SoC ring with a tick at the charge limit; "Charging" tiny y 34; hero "80%" numMed y 58; state chip y 134 ("Charging" / "Plugged in" / amber "! Connect cable"); xtiny "7.2 kW · AC" y 160; "Full by 18:40 (95 min)" y 180; age y 202; rows with missing data are left out (no "Label: —" lines).

### C4. Charge limit

"Charge limit" tiny y 36; "80%" numMed VCENTER 124; six stop dots on an arc at r 116 from 220° to 320° (current: accent r 7); "Battery care" chip with check at y 166 when it matches; "+" glyph at UP, "−" at DOWN, check at START.

### C5. Find my car

Ring track r 125 + accent pointer at the bearing (outline when no heading); no title; address xtiny 2 lines at y 46/65 wrapped to [158, 186] with "…"; distance numMed y 88 + unit medium; age y 172. Moving: "Car is moving" small y 92, "Last parked" y 130, address y 150/169, age y 196. GPS: "Waiting for GPS" small y 112, pointer hidden.

### C6. Glance (171×63)

Row 1 y 2: "Vozidlo" xtiny grey left, "12 min" right. Row 2 y 22: "100%" tiny, padlock + "Locked", bolt and climate icons (ends at x 165). Row 3 y 55: 4 px SoC bar. Empty: "Open for your car".

### C7. Onboarding

Keep `TextBlock.draw`; use `small` when the text wraps to 4 lines or fewer, else xtiny; replace "Select to continue" / "Menu for more" with button glyphs. Longest text (expired + guidance) wraps to 6 lines, y 73 to 187, widest 229 of 240.

### C8. How to check a layout fits

1. Box: top = y (or y − h/2 with VCENTER), bottom = top + font height.
2. Usable: `TextBlock.lineWidth(130, 130, top, bottom)` (includes 2 × 8), minus extra margin on ring screens.
3. Width: `dc.getTextWidthInPixels`; for composite rows add icons, gaps, pill padding.
4. Shapes: for every corner arc centre, `hypot(cx−130, cy−130) + radius ≤ 122`.
5. Dynamic text: `wrapLines` with per-row widths and a line cap.
6. Number fonts: only `0-9 space # % + - . / : °`.
7. Add a `TextBlockTests` case per fixed string so longer copy fails CI; re-render on the screen board with Guides and Font gaps on.

## 6. Decisions for Bart

| | Decision | Recommendation | Changes |
|---|---|---|---|
| D1 | Home: A (grid + fixes), B (hero + action list), C (fixed deck) | Decided 2026-10-07: B, hero list | B rewords US-036 "one press below" |
| D2 | Merge Charging detail into the Status loop | Decided 2026-10-07: no, a separate screen reached from a Charging row | US-023 unchanged |
| D3 | Accent colour | Decided 2026-10-07: Škoda Electric Green (0x55FFAA on the watch) | decisions.md "Branding" colour line updated in 1.1.0 |
| D4 | START on status pages: ActionMenu (Refresh in 2 presses) or refresh directly | Decided 2026-10-07: action list | |
| D5 | Icons solid or outline | Solid | outline is closer to MyŠkoda, weaker on MIP |
| D6 | One tap on a row runs it | Yes | ConfirmationPolicy unchanged |
| D7 | ViewLoop indicator: native left arc or custom dots | Decided 2026-10-07: own dots (own pager, no ViewLoop) | |

Checks on the fēnix 7 Pro: (1) what UP/DOWN do on home: answered 2026-10-07, they move the tile focus; (2) what the number font draws for missing letters: open; (3) whether a single tap fires a tile: open.

## 7. Sources

- Code and device: `app/source/ui/*.mc`, `docs/decisions.md` (Branding, round display, colour), `docs/best-practices/garmin-connect-iq.md`, `~/.Garmin/ConnectIQ/Devices/fenix7pro/` (simulator.json, personality.mss, api.debug.xml), SDK 9.2.0 docs (User Experience Guidelines, Personality Library, ViewLoop, CustomMenu).
- MyŠkoda: skoda.co.uk news on the new app (2024); Škoda Storyboard press releases (new MyŠkoda app; Red Dot 2021 for ŠKODA Flow; new in-car controls); App Store listing MyŠkoda (watch app: battery, lock, heating; widget timestamps).
- Škoda design: Škoda Storyboard (Elroq Modern Solid press kit; new logo and identity 2022); retailer CI guidelines PDF (colour rules, facets).
- Garmin UX: developer.garmin.com Connect IQ User Experience Guidelines (views, menus, visual design); Garmin forum thread on the ViewLoop page indicator; github.com/Likenttt/garmin-ciq-page-indicator.
- Comparable apps: Tesla watch app (The Driven), Tessie complications, Tesla-Link for Garmin (GitHub), BMW i Remote, Hyundai Bluelink, myVW, Mercedes; Wear OS Material 3 Expressive (Android Developers Blog).

## 8. After implementation

- Use the redesigned screens (as rendered in `docs/design/vozidlo-poc.html`) as the store assets for the Connect IQ listing once the new design is in the app; they replace the current `store-assets/screen-*.png`.
