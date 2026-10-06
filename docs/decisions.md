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

### Never poll. Not once, not in the background.

20 requests per hour per vehicle, shared with everything else the owner runs
against the same car: Home Assistant, the official app, this. A background
refresh would spend somebody else's budget. Every request in this app is caused
by a user action, and `api/Quota.mc` counts them locally because Connect IQ
exposes no response headers, so `RateLimit-*` is unreadable from a watch app.

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

**Three bugs, one cause**, and all three were found by wearing the watch. The
simulator's bezel is more forgiving and had shown every one of these screens as
fine:

- **The control grid.** A row of two 90-pixel tiles reaches 95 pixels either
  side of centre, so it needs a chord of at least 190: `dy <= 88`, tiles only
  between y 42 and 218. That is three rows at a 52 pitch, and seven tiles need
  four. The fourth row sat where the chord is 78 pixels wide and the "More" tile
  was drawn under the rim. Hence `ui/GridScroll.mc` and a grid that scrolls to
  keep the focused tile whole.
- **Bottom hints.** A single line at `height - 20` had about 84 pixels for text
  needing 150, on four separate screens. Hence
  `TextBlock.drawFittedLine()`, which moves a line up to the lowest point where
  it fits rather than truncating something the user is meant to read.
- **Paragraphs**, which is `WatchUi.Text` not wrapping, above.

So the rule: **any text or box placed at a constant y must have its width
checked against the chord at that y.** The arithmetic already exists and is
tested. Use it rather than guessing a margin: `halfChord()`, `lineWidth()` and
`fittedLineY()` in `ui/TextBlock.mc`, and `offsetFor()` in `ui/GridScroll.mc`.

A corollary worth stating, because it caught us twice: a screen that looks
correct in the simulator has not been checked. The simulator draws a generous
bezel and clips less than the hardware does.

### Connect IQ exposes no response headers.

Not one. `X-API-Key-Expires-At` and `RateLimit-*` exist on the wire and are
unreadable from a watch app. Hence local quota counting with a `429` as the
authoritative correction, and a key-expiry *estimate*: presented as an
estimate, rather than the exact date the header carries.

### `Application.Storage` limits are 8 KB per key, 128 KB total.

Which is why the cache is a projection. Worth knowing before designing anything
that persists.

---

## Devices

### Support is evidence-based, and a clean build is not evidence.

The procedure for adding one is in [CONTRIBUTING.md](../CONTRIBUTING.md).

The short version, and the reason it exists: the Forerunner 255 is the same
device family as the fēnix 7, the same Connect IQ version, and it **builds
clean at `-l 3 -w`**. It is excluded because its `api.debug.xml` contains zero
`Toybox_WatchUi_MapView` implementation entries against nine on every supported
device. The type resolves; the implementation is absent. Those watches have no
onboard maps, and `ui/MapPreviewView.mc` extends `WatchUi.MapView` at class
level.

That is the same shape as the glance crash: it compiled, and it would not have
run.

### One device family, so one set of layouts.

Every supported device is `round-260x260`. `ui/ControlsView.mc` therefore holds
a fixed grid as plain constants rather than computing geometry at layout time.
Supporting a 240×240 or 280×280 device means making that adapt: real work, but
bounded and welcome. Supporting a Venu additionally means an input redesign:
those have two or three buttons and no UP/DOWN, and five views here depend on
`onPreviousPage`/`onNextPage`.

---

## Process

### Strict type checking from the first commit.

`-l 3 -w`, and warnings are errors in CI. Retrofitting strict typing onto a
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

Hence: an original icon, no Škoda brand green, no Škoda typeface, the name used
as a plain word, and the disclaimer carried verbatim. If you fork and publish,
this constraint travels with you.

### Colour is never the only signal.

64 colours on a memory-in-pixel panel, read outdoors, often in sunlight. Where
red and green appear together, an icon or shape distinguishes them too. The
check is cheap and decisive: render the screen without colour and every state
must still be identifiable.
