# Decisions

Why the code is shaped the way it is. Read this before proposing a change that
contradicts one of these, not because they are sacred, but because most of
them cost something to learn and the reasoning is not obvious from the code.

Several were mistakes first. Those are marked, because a decision you can see
the scar on is easier to trust than one asserted flat.

---

## Architecture

### The watch talks to Škoda directly. There is no server of ours.

Connect IQ cannot open a socket. `Communications.makeWebRequest()` is proxied
through the Garmin Connect app on the paired phone, which performs the actual
HTTPS call. So the path is already watch → phone → Škoda.

Inserting a server of our own would add a fourth party that can see the API key
and the vehicle's position, give us data to protect and a bill to pay, and buy
nothing: the API is per-user keyed and CORS-irrelevant, so there is nothing a
proxy would unlock. The privacy policy can therefore say something unusually
short: no data reaches the author, because there is nowhere for it to go.

The cost is real and worth stating: no phone in range means no data, and every
request is subject to the phone's own connectivity.

### One `Settings.Config`, read once, passed down.

Nothing outside `source/Settings.mc` touches `Application.Properties`. Views
receive a parsed, validated `Config`. This is why a phone-side settings edit
takes effect without an app restart: `onSettingsChanged()` reloads in exactly
one place, and why the VIN is length-checked before any URL is ever built.

### The cache is a projection, not the response.

`model/Cache.mc` stores a hand-picked subset of the vehicle response, never the
decoded body. `Application.Storage` allows 8 KB per key and 128 KB in total, and
a full response does not comfortably fit. Storing a projection also means a
change in the API's shape cannot silently corrupt what we render from cache.

---

## The API, and what it does to the code

### `:responseType` must be set on reads and omitted on commands.

This is the single most important line in the codebase, and it was measured
rather than reasoned:

```monkey-c
// Reading -> set it, or the error detail is lost.
{ :method => Communications.HTTP_REQUEST_METHOD_GET,
  :headers => { "X-API-Key" => key },
  :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON }

// Commanding -> omit it, or every success looks like a failure.
{ :method => Communications.HTTP_REQUEST_METHOD_POST,
  :headers => { "X-API-Key" => key } }
```

Škoda answers a command with `202`, an empty body and **no `Content-Type`
header at all**. With `:responseType` set, Connect IQ cannot parse that and
hands back `-400`. Every successful command would report as an error.

`mock/tests/test_shapes.py` pins this shape deliberately, including the absent
header. A mock that added a `Content-Type` "to be helpful" would make the bug
untestable.

### Commands report "sent", never "succeeded".

The API is fire-and-forget. A `202` means Škoda accepted the request for
delivery to a car that may be in a car park with no signal. The UI says the
command was sent, and a separate, quota-costing read is the only way to learn
whether anything happened. Claiming success would be a lie about a car the user
cannot see.

So "Climate on" is only ever said from the car's own report, read after the
command: see the next entry.

### One check after a command.

Since 1.2.0, 15 seconds after a `202` the app reads the one section the
command touches, once (`ui/CommandCheck.mc`). It says what the car reported:
"Climate on" when the car's report, timestamped after the command, shows the
change; "Car reports: Off" in amber when it shows something else; "the car has
not reported yet" in grey when nothing newer came back. It is never red: a car
that has not answered yet has not failed.

- **15 s.** Measured on 2026-10-08: the car reported a new climate state 8 s
  after stop and 12 s after start.
- **One read, no retry.** A command costs 2 of the 20 requests per hour with
  the check, 1 without. Refresh on Status is the second look, on request.
- **The user's choice.** The setting "Check the car after a command" is on by
  default and can be switched off on the phone. The check is skipped when the
  phone is not connected or the quota is spent or nearly spent.

### Never poll. Not in the background.

20 requests per hour per vehicle, shared with everything else the owner runs
against the same car: Home Assistant, the official app, this. A background
refresh would spend somebody else's budget. Every request in this app is caused
by a user action: a refresh, a command, or the one check that follows a
command the user just sent (above), which the user can switch off.
`api/Quota.mc` tracks what it can locally, because Connect IQ exposes no
response headers, so `RateLimit-*` is unreadable from a watch app.

### Data is not live, and every section ages separately.

The response is whatever the car last uploaded. We measured sections twelve
minutes old sitting next to one seventeen hours old, in the same response. So
the UI never shows a single global timestamp; each section carries its own age.
A refresh that changes nothing is normal and must not look like a failure.

### The app cannot lock or unlock the car.

The API has no endpoint for it. This is stated twice in the store listing on
purpose: once in the feature list and once under its own heading. It costs
installs and prevents a stream of one-star reviews from people who assumed.

### The UI shows only what `operations[]` advertises.

The car tells us what it supports. Hiding unavailable actions is better than
offering them and explaining a 422 afterwards. Note the API is not perfectly
self-consistent here: our reference vehicle advertises `setChargeMode` while
returning an empty `availableChargeModes`, so code must tolerate an advertised
operation with nothing behind it.

---

## Connect IQ platform traps

### `(:glance)` is a linking rule, not a budget hint.

The compiler builds a **separate binary** for glance scope containing only
annotated code. An unannotated symbol is not discouraged there, it is *absent*,
and calling it throws `Illegal Access (Out of Bounds): Failed invoking
<symbol>` at runtime.

**This shipped.** `VozidloApp.onStart()` runs in glance scope as well as app
scope and called `Settings.load()`, which had no `(:glance)`. The glance crashed
on every single launch. Three call sites carried
`(:typecheck(disableGlanceCheck))` with comments arguing the calls were cheap
enough for the 65,536-byte arena. They were cheap. That was never the question:
the annotation silences the warning **without adding the symbol**, converting a
compile-time error into a guaranteed crash.

144 tests passed throughout, because a test build links everything.

So: annotate the module, never suppress the check to get past it. The
suppression is legitimate only on a method that is not *invoked* in glance
scope: `getInitialView()` and `getSettingsView()` qualify, `onStart()` does
not.

A fresh simulator renders the glance before the app, so `tools/ciq run` after a
simulator restart is the cheapest guard available.

### `WatchUi.Text` does not wrap.

Its `:width` bounds justification, not layout. A long string is drawn as one
line running off both edges.

**This shipped too.** The first thing a new user saw was a 190-character
sentence rendered as `rks for the vehicles you selected when y`.

`ui/TextBlock.mc` replaces it. On a round display the usable width depends on
how far a line sits from the centre: the widest chord is in the middle, and a
line near the top or bottom has much less room, so each line is wrapped to the
chord available at its own height. The line count and those widths depend on
each other, so it solves to a fixed point. The geometry and the wrapping are
pure functions over plain numbers and a measuring callback, which is what makes
them testable without a `Dc`.

### A round display is not a rectangle.

The usable width at any height is a chord, `2 * sqrt(r² - dy²)`, not the screen
width. On a 260-pixel face that is 260 pixels across the middle and about 84
near the bottom edge. Anything positioned by a constant y, and sized as though
the screen were square, is wrong somewhere.

The one rectangular watch, the Venu X1 (448×486, since 1.3.0), is not a
rectangle either: its corners are rounded, so near the top and bottom the
usable width is the width inside the corner curve, not the screen width. The
rule below is the same for both shapes: measure against the outline.

**Three bugs, one cause**, and all three were found by wearing the watch. The
simulator's bezel is more forgiving and had shown every one of these screens as
fine:

- **The control grid.** A row of two 90-pixel tiles reaches 95 pixels either
  side of centre, so it needs a chord of at least 190: `dy <= 88`, tiles only
  between y 42 and 218. That is three rows at a 52 pitch, and seven tiles need
  four. The fourth row sat where the chord is 78 pixels wide and the "More" tile
  was drawn under the rim. Hence `ui/GridScroll.mc` and a grid that scrolled to
  keep the focused tile whole, both gone in 1.1.0 with the grid itself (see
  [Night Panel navigation](#night-panel-navigation)).
- **Bottom hints.** A single line at `height - 20` had about 84 pixels for text
  needing 150, on four separate screens. Hence
  `TextBlock.drawFittedLine()`, which moves a line up to the lowest point where
  it fits rather than truncating something the user is meant to read. Since
  1.1.0 there are no text hints at all; the bezel carries arcs and glyphs.
- **Paragraphs**, which is `WatchUi.Text` not wrapping, above.

So the rule: **any text or box must have its width checked against the
outline at its own y**: the chord on a round screen, the width inside the
corners on the X1. Since 1.3.0 nothing is placed at a constant y either (see
[Layouts follow the screen, measured from the Dc](#layouts-follow-the-screen-measured-from-the-dc)).
The arithmetic already exists and is tested. Use it rather than guessing a
margin: `halfChord()` and `usable()` in `ui/Geometry.mc` (`Geo`), which know
both shapes; `halfChord()`, `lineWidth()` and `fittedLineY()` in
`ui/TextBlock.mc`; and `fit()`, `usable()` and `wrapFit()` in `ui/Ui.mc`.
They measure with the fonts the watch actually has: fēnix 8 and 9 scale them,
and on the vívoactive 6, Venu 4 and Venu X1 the owner can set the font size
up to 1.4× in the watch's settings.

A corollary worth stating, because it caught us twice: a screen that looks
correct in the simulator has not been checked. The simulator draws a generous
bezel and clips less than the hardware does.

### Connect IQ exposes no response headers.

Not one. `X-API-Key-Expires-At` and `RateLimit-*` exist on the wire and are
unreadable from a watch app. Hence a `429` as the only quota signal, and a
key-expiry *estimate*: presented as an estimate, rather than the exact date
the header carries. After a `rate-limit-exceeded` the app does not ask again
for an hour, the length of the quota window, and says so as an estimate
("resets in ~60 min"); nothing else could ever tell it the window turned
over, and up to 1.2.0 it stayed blocked until the user cleared all data. The
app does not count its own requests, so the "nearly spent" warning
(`Quota.isLow()`) only fires on header values it cannot read yet.

### `Application.Storage` limits are 8 KB per key, 128 KB total.

Which is why the cache is a projection. Worth knowing before designing anything
that persists.

---

## Interface

### Night Panel navigation.

Version 1.0 put every action on a fixed 260×260 tile grid, three rows visible,
with UP and DOWN meant to page to charging and status through
`onPreviousPage`/`onNextPage`. On the watch (checked 2026-10-07) UP and DOWN
moved the tile focus instead, so those pages never opened, and charging detail,
reachable only that way, had become unreachable with buttons. 1.1.0 replaces
the grid, decided per the options in
[ui-improvements.md](design/ui-improvements.md):

- **Home is a list with a hero (D1).** A `CustomMenu` whose title area shows
  state of charge, chips and one status line; every action is a row, so UP
  and DOWN do what the system list does and the focus stays where it was left.
- **Charging detail is a separate screen (D2)**, reached from a Charging row
  on home. **This shipped** in 1.1.0 with a shortcut as well: UP past the
  first row opened Charging and DOWN past the last opened Status. On the
  watch that read as a screen opening by itself while scrolling, so since
  1.1.1 the list wraps at both ends like Garmin's own menus and nothing opens
  that the user did not choose.
- **START on status opens an action list (D4)**: refresh and charging details,
  instead of a hidden press.
- **Status uses our own page dots (D7)**, drawn in the bezel like the rest,
  rather than the system pager. `StatusPager` swaps in a fresh page view per
  page with `WatchUi.switchToView` and a slide (next page up, previous page
  down), so the page stack stays one deep and BACK returns home. One view
  that only redraws its page is the fallback, behind the constant
  `StatusPager.SWITCH_VIEWS`, should switching views misbehave on a watch.
- **All menus are `CustomMenu`s in the accent.** `Menu2` cannot be recoloured
  on these watches, so a native menu would have drawn the system colour next
  to our green. Only confirmations and toasts stay native, and since 1.3.0
  Garmin's action menu indicator on the watches without MENU (see
  [Three input profiles](#three-input-profiles-and-every-action-reachable-in-each)).
- **Stale data is amber**, `! 17 h ago`, not red. This amends US-009: red is
  kept for errors, so an old reading no longer looks like a failure.

The outline rule above (the chord, on a round screen) applies to all of it,
on every watch.

### Target temperature is a list, on every watch.

Up to 1.2 the target temperature was a stepper: UP and DOWN changed it by one
degree, with + and − glyphs next to those buttons. The Venu watches have no UP
or DOWN, so since 1.3.0 it is a list titled "Temperature", like the charge
limit: 16 to 30 °C, or 60 to 86 °F, focused on the current value. One screen
for every watch is less code than a stepper with a touch fallback, and it
works the same with buttons, swipes and taps. Decided 2026-10-10 by the
owner.

### On-screen copy names the action, not the button.

Empty states used to say "START to refresh" and, on Find my car, "MENU to
refresh". On a watch without MENU the second was an instruction nobody could
follow, and the right button differs per input profile. Since 1.3.0 the copy
says "Refresh from the menu" and "Try again from the menu" on every watch,
the wording Charging already used. Capitals stay reserved for button names,
which on-screen copy no longer uses. Decided 2026-10-10 by the owner.

### Home opens on its first row.

Up to 1.2 the default order put climate first and home focused the primary
action, so it opened on "Start climate" with the hero in view. Since 1.3.0
the default order is Status, Find my car, then the rest (climate, charging,
Charging, Settings), and home focuses its first row, so it opens on Status
with the hero in view: the hero is only drawn while row 0 has the focus. A
stray START now opens a screen instead of sending a command. This amends
US-037: the primary action still comes first within the climate rows, two
rows down by default. An order the user saved is kept. Decided 2026-10-10 by
the owner.

---

## Devices

### Support is evidence-based, and a clean build is not evidence.

The procedure for adding one is in [adding-a-watch.md](adding-a-watch.md).

The short version, and the reason it exists: the Forerunner 255 is the same
device family as the fēnix 7, the same Connect IQ version, and it **builds
clean at `-l 3 -w`**. Up to 1.2 it was excluded, because its `api.debug.xml`
contains zero `Toybox_WatchUi_MapView` implementation entries against nine on
every watch that has the map. The type resolves; the implementation is
absent. Those watches have no onboard maps, and `ui/MapPreviewView.mc`
extends `WatchUi.MapView` at class level.

That is the same shape as the glance crash: it compiled, and it would not have
run.

Since 1.3.0 the FR255 and FR255 Music ship, with the map left out of their
build (see [The map is optional](#the-map-is-optional-and-left-out-per-product-where-it-is-missing)).
That changed the code, not the lesson: they were added because the device
files showed what was missing and the code was changed to match, not because
the build was clean.

### Layouts follow the screen, measured from the Dc.

Up to 1.2 every supported watch was `round-260x260`, and the bezel
(`ui/Bezel.mc`) and the page coordinates were plain constants for that face.
Since 1.3.0 the app runs on round screens of 218, 240, 260 and 280 px
(memory-in-pixel), round 390, 416 and 454 (AMOLED), and the 448×486
rectangle of the Venu X1. The per-watch design is
[docs/design/vozidlo-devices.html](design/vozidlo-devices.html).

There is one layout, not one per screen. It is drawn in a logical frame 260
wide and scaled by s = width / 260, but only the positions that belong to the
screen scale: the title starts 34·s from the top (20·s on the rectangle), the
status line ends 29·s above the bottom, and everything in between is stacked
from the font heights the watch reports. Every width comes from the outline
at its y, and the bezel parts sit at R − k·s. A title too wide for its chord
moves down, up to 20·s, rather than shrinking. `ui/Geometry.mc` (`Geo`)
computes these tokens once from `System.getDeviceSettings()` and
`Graphics.getFontHeight()`, without a Dc, so tests can run any watch's
numbers on one simulator. Each watch also gets one hero number font: the
larger of `FONT_NUMBER_MEDIUM` and `FONT_NUMBER_MILD` that fits the Charging
screen's worst case, never `FONT_NUMBER_HOT`.

Scaling the 260 numbers would not have worked, because fonts do not scale
with the screen: the Venu 3S's fonts are taller for its width than the
fēnix's, and stacked at 1.5× they overlap. Constants per screen would have
been six tables to keep in step, and even within one family the fonts differ:
on the fēnix 7, 8, 9 and FR955 the age and status lines overlapped, because
the constants were measured with the fēnix 7 Pro's fonts. Their positions
now follow their own fonts, and the fēnix 7 Pro, the primary watch, stays
pixel-identical (`GeoTests` pins its tokens).

On the X1 the layout uses the full rectangle: the ring becomes a frame along
the display edge, hint arcs become short bars next to the keys, and the page
dots keep their arc formula, which there gives a near-vertical column.
Decided 2026-10-10 by the owner.

### Three input profiles, and every action reachable in each.

The new watches have fewer buttons, and three views depended on UP, DOWN and
MENU. Find my car hid Refresh and Navigate behind MENU and said "MENU to
refresh", which the watches without a MENU key could never do. Since 1.3.0
the app knows three profiles, chosen from the watch's `inputButtons`
(`Geo.inputFrom()`; `ui/InputProfile.mc` handles the indicator):

- **A, five buttons and touch** (fēnix, epix, MARQ, Descent Mk3, Enduro 3,
  D2 Mach 2, FR955, FR965, FR970). MENU is a long press on UP.
  **A0** is the same five buttons without touch: the FR255, or a fēnix with
  touch switched off. Everything works with the buttons alone.
- **B, START, BACK and touch, MENU as a long press on BACK** (Venu 3, Venu 3S).
- **C, START, BACK and touch, no MENU** (vívoactive 6, Venu 4, Venu X1).
  Garmin's action menu indicator (`setActionMenuIndicator`) takes MENU's
  place: a left swipe or a tap on it calls `onActionMenu`. It only fires while
  the indicator is on, so every view with an action list turns it on.

The rule: **every action is reachable in every profile**, and touch is an
extra, never the only route. The menu route opens the same list START opens,
unless START has a primary action of its own (the map, retry, continue). A
left swipe means nothing else anywhere. The app only uses Garmin's behaviours
(`BehaviorDelegate`: select, back, next and previous page, menu,
`onActionMenu`), so the same code serves all three profiles.

Three consequences. On the Venu 3 and 3S a long press on BACK is the
platform's menu route, so there is no left swipe there, and the menu glyph
sits at BACK only where MENU is the only route (Onboarding). A tap that would
spend quota is consumed (Charging profiles' retry, Onboarding's retry and
Blocked), which fixes it on the fēnix too. The native
`WatchUi.Confirmation` stays: on touch that is one tap on Yes, as on the
touch fēnix already. Decided 2026-10-10 by the owner.

### Connect IQ 5.1 is the floor, because nothing needs more.

Up to 1.3.0 `minApiLevel` was 5.2.0, the level of the fēnix 7 Pro, with no
API behind the choice. The Descent Mk3 and Mk3i run Connect IQ 5.1 (their
device files and Garmin's compatible devices list agree), so 5.2.0 kept them
out for nothing. Built against their own API lists at `-l 3 -w`, with the
minimum at 5.1.0, the app compiles clean and every unit test passes, so the
floor is 5.1.0 since 2026-10-23. What is newer than 5.1.0 (the action menu
indicator, `showToast`) was already guarded with `has`. The lowest version we
ship always has a device in `VERIFY_DEVICES`, enforced by `tools/checks.py`,
so a 5.1-only gap would show up in `tools/ciq verify`. Decided 2026-10-23 by
the owner.

### The map is optional, and left out per product where it is missing.

The map preview extends `WatchUi.MapView`, which the five-button watches
(except the FR255 and FR255 Music) and the Venu X1 implement. The FR255, FR255
Music, Venu 3, Venu 3S, vívoactive 6 and both Venu 4 sizes do not (see
[Support is evidence-based](#support-is-evidence-based-and-a-clean-build-is-not-evidence)).
Leaving those watches out for a convenience would be a poor trade, so the map
is left out of their build instead:

- `ui/MapPreviewView.mc` and its delegates carry `(:map)`, and
  `app/monkey.jungle` excludes `map` for each product without MapView and
  `nomap` for the rest. `ui/LocationView.mc` has a `(:map)`/`(:nomap)` pair
  for the one place that opens the map.
- The runtime check `WatchUi has :MapView` stays as a second guard.
- On Find my car, START opens the map when the car is parked and the watch
  has one; otherwise it opens the Find my car list.
- Navigate is hidden where `PersistedContent.saveWaypoint` is unavailable,
  checked at run time, because the Venu 3S's device files list it only
  partly.

`tools/checks.py` keeps the jungle in step with the device facts, so a new
watch without the map cannot be added with the map still linked in. Decided
2026-10-10 by the owner.

---

## Process

### Strict type checking from the first commit.

`-l 3 -w`, and a warning fails `tools/ciq build` and `tools/ciq verify`
(CI does not build the app; see below). Retrofitting strict typing onto a
Monkey C codebase is far more work than starting with it.

One gotcha: chained boolean expressions over nullable method calls can make the
type checker's memory use explode. If a build hangs, that is where to look,
not at the machine.

### The mock is strict on purpose.

Two URL bugs shipped during research: a missing `/vehicles/` segment and a
trailing slash before a query string, and both produced `404 "No static
resource"` from the real API. A permissive mock caught neither, because it used
`re.match` where it should have used `re.fullmatch`.

So `mock/` now rejects everything the real server rejects: exact paths, no
trailing slash, correct method, `X-API-Key` required. It is generated against
the vendored OpenAPI document and a contract test proves it still matches. It
serves over HTTPS because the simulator refuses plain `http://`.

### No real vehicle data in the repository, ever.

This one is also a scar. The mock and two test files carried a real street
address, its GPS coordinates and a real odometer reading, copied from a live
capture while building fixtures. A parking position is somebody's home address.

`mock/tests/test_privacy.py` is the tripwire: it pins the placeholders and
fails on any unexplained high-precision coordinate, street-address pattern, or
`msk_`-prefixed key anywhere in the repository. Copy a real response for its
**shape**, never for its **values**.

### The devices page and the lists of watches are generated.

Up to 1.3.0 the devices design page had its columns, the watches each covered,
and every list of watches in its copy written by hand, so each new watch meant
editing JavaScript and prose in several places, and the copy went stale (the
decisions it called open were long taken). Since 2026-10-23 `devdata.py`
also writes the columns: products share one when they share screen family,
input profile, MapView and font technology, drawn as the product the unit
tests run on. Lists of watches in the page's copy are filled from the facts,
and what differs per watch because of the layout (hero font, home chips,
lock grid, onboarding parts) is computed by drawing it and shown in the watch
table, not written into notes. Adding a watch no longer touches the page's
sources.

The same holds for the other lists of watches. `tools/devicelists.py` writes
the README and guide tables, the store listing's requirements, the product
block of the manifest comment, and the jungle's per-product lines (the map
exclusion and the launcher icon folder, one `resources-launcher-<size>` per
icon size instead of a copy per watch) from the manifest and the device
facts, and `tools/checks.py` fails when one is out of date. The manifest's
product list is the only list edited by hand. Decided 2026-10-23 by the
owner.

### Device facts are committed, so CI can check them without the SDK.

Garmin's device files come only through the SDK Manager, behind a Garmin
login, so a CI runner cannot have them. The facts the repository depends on
are therefore read once, locally, and committed:
`tools/ui/devices/devdata.py` reads the SDK's device and font files and
writes `tools/ui/devices/11-devdata.js`, with every product in the manifest:
its screen, keys and input profile, touch, MapView, memory budget, launcher
icon size, glance area and font metrics.

From that file CI can check what used to be checked by hand: that the
manifest, the README, the store listing and the devices design page name the
same watches, and that every watch without MapView has the map excluded in
the jungle. The devices page and `node tools/ui/fitcheck.mjs --devices` draw
and check every screen with those metrics. `devdata.py --check` regenerates
the file and compares; it needs the SDK, so it runs in `tools/ciq verify`,
not in CI.

### CI checks consistency; the app is built and tested locally with tools/ciq verify.

CI cannot compile Monkey C (no device files, no signing key; the reasons are
at the top of `.github/workflows/build.yml`). What it runs is everything that
needs no SDK: the mock server's tests, `tools/checks.py` (links and anchors,
the device lists agreeing, the map exclusion, cited decisions existing,
privacy) and the design checks (`tools/ui/build.sh --check`,
`tools/ui/build-devices.sh --check`, `node tools/ui/fitcheck.mjs` with and
without `--devices`). A green CI says the repository is consistent; it does
not say the app builds.

`tools/ciq verify` is the gate for that, run locally before a pull request
that touches `app/`: the checks, the design pages and the device facts, then
`tools/ciq build --all` with warnings fatal and every product within its
memory budget, then the unit tests on one watch per screen family and input
profile. It exits non-zero on any failure. A CI that claimed to build would
either fail on every run or pretend; saying plainly which half runs where is
the honest version.

---

## Branding

### The brand name in words, never the logo.

No third-party trademark licence exists for this API. Škoda's own terms state
that no rights are granted to use their marks in any manner; the API
documentation links no terms that would change that; and Garmin's Developer
Agreement makes the publisher warrant they hold the rights and indemnify
Garmin.

What is permitted is referential use **in words** to describe compatibility:
EUTMR art. 14. The Court of Justice's *Audi* ruling found that reproducing the
*logo shape* creates a false impression of authorisation, which is a different
act.

Hence: an original icon, no Škoda typeface, the name used as a plain word, and
the disclaimer carried verbatim. If you fork and publish, this constraint
travels with you.

The colour is the owner's decision of 2026-10-07: Škoda Electric Green
(`#78FAAE` on skoda-auto.com, `0x55FFAA` on the 64-colour panel) is the app's
single accent colour. The logo, the Škoda typeface and the plain-word name rule
above are unchanged.

The AMOLED watches added in 1.3.0 can show `#78FAAE` exactly, but they get
`0x55FFAA` too, so one token is one colour on every watch and the palette
stays a single table. Whether to use the true brand green on AMOLED is still
open.

### Colour is never the only signal.

64 colours on a memory-in-pixel panel, read outdoors, often in sunlight. Where
red and green appear together, an icon or shape distinguishes them too. The
check is cheap and decisive: render the screen without colour and every state
must still be identifiable.

The AMOLED watches show far more colours, and the rule stays there all the
same: the screens are the same on every watch, and a colour-blind owner reads
a Venu no better than a fēnix.
