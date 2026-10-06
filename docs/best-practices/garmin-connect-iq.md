# Garmin Connect IQ best practices

House rules for this project, distilled from the official Garmin documentation.
Every rule states what to do, why it matters, and where it comes from. Rules
marked **[inferred]** are our reading of combined sources rather than something
Garmin states in one place; rules marked **[unverified]** still need checking.

Scope: a Monkey C **watch app** (`type="watch-app"`) for six devices in one
device family (round-260x260): fēnix 7 Pro, fēnix 7, fēnix 7 Pro Solar, fēnix 8
Solar 47mm, fēnix 9 Pro Solar 47mm and Forerunner 955: API level
5.2, 260×260 round, 64-colour memory-in-pixel: making authenticated HTTPS calls
to a third-party REST API through the paired phone. A watch face is out of scope.

These rules are part of the process, not a reading list. A pull request that
contradicts one of them should say so and why: several were learned the hard
way, and [decisions.md](../decisions.md) records which.

---

## 1. Memory and performance

Our budgets on this device, taken from
`~/.Garmin/ConnectIQ/Devices/fenix7pro/compiler.json` (identical for `fenix7`):

| App type | Limit |
|---|---|
| Watch app | 786,432 B |
| Glance | 65,536 B |
| Background service | 65,536 B |

**Never load resources inside `onUpdate()`.** Loading a resource is expensive.
Load bitmaps and fonts once in `onLayout()` or `onShow()`.
→ [Resources](https://developer.garmin.com/connect-iq/core-topics/resources/)

**Pre-compute, then draw.** Parse the API response once when it lands and store
the display-ready values. `onUpdate()` should only draw. A careless full-screen
redraw can take ~700 ms, which the user sees as lag and the battery pays for.
→ [Improve your app performance](https://www.garmin.com/en-US/blog/developer/improve-your-app-performance/)

**Break reference cycles with `weak()`.** Monkey C frees objects by reference
counting, so an A→B→A cycle leaks until one side is broken. Any back-reference
from a child to its parent, a delegate to its owner, or a callback to its
subscriber must be a `WeakReference`: call `obj.weak()`, guard with
`stillAlive()`, and only `get()` a strong reference for the shortest scope you
need.
→ [Objects and memory](https://developer.garmin.com/connect-iq/monkey-c/objects-and-memory/)

**Don't allocate in hot paths.** Every unique object costs a heap handle.
Per-frame string concatenation and dictionary construction are the usual
culprits. Reuse buffers.
→ [Objects and memory](https://developer.garmin.com/connect-iq/monkey-c/objects-and-memory/)

**Prefix globals with `$.` in hot code.** Without it the VM walks the whole
instance → superclass → module → parent-module chain at runtime.
→ [Objects and memory](https://developer.garmin.com/connect-iq/monkey-c/objects-and-memory/)

**Scope every resource.** The `scope` attribute (`background`, `glance`,
`foreground`) on `<layout>`, `<bitmap>`, `<string>`, `<font>` and `<jsonData>`
decides what gets loaded into our 65,536-byte glance and background budgets.
Unscoped defaults to `foreground`. This is the single biggest lever we have.
The same applies to code via the `:background` and `:glance` annotations.
→ [Resources](https://developer.garmin.com/connect-iq/core-topics/resources/),
[Annotations](https://developer.garmin.com/connect-iq/monkey-c/annotations/)

**`:glance` and `:background` are linking rules, not budget hints.** The
compiler builds a separate binary for each restricted scope containing *only*
annotated code. An unannotated symbol is not "discouraged" there, it is absent,
and calling it throws `Illegal Access (Out of Bounds): Failed invoking
<symbol>` at runtime. Annotating a module is enough; its members follow.

**Never reach for `(:typecheck(disableGlanceCheck))` to silence that warning.**
It suppresses the diagnostic without adding the symbol, so it converts a
compile-time error into a guaranteed crash. It is only ever correct on a method
that is not *invoked* in glance scope at all: `getInitialView()` and
`getSettingsView()`, but not `onStart()`, which runs in both scopes.
Cheapness is not the test: "it only does a Storage read" is true and
irrelevant. We shipped this bug; see `VozidloApp.mc`'s header comment.

**A fresh simulator renders the glance first** for any app that has one, so
`./tools/ciq run` on a just-started simulator exercises glance scope before app
scope. That is the cheapest guard we have: unit tests link everything and
cannot catch a missing `:glance`.

**A clean build does not mean a device is supported.** Adding a product to the
manifest and getting `BUILD SUCCESSFUL` proves the types resolve, nothing more.
The Forerunner 255 is the worked example: same device family as the fēnix 7,
same Connect IQ version, builds clean at `-l 3 -w`, and has **no
`WatchUi.MapView` implementation at all**. Check the device's own
`~/.Garmin/ConnectIQ/Devices/<id>/<id>.api.debug.xml` for the symbols you
actually call: `grep -c Toybox_WatchUi_MapView` gives nine on a device that
has it and zero on one that does not, and read the memory budgets out of its
`compiler.json` rather than trusting the model name.
→ [Glances](https://developer.garmin.com/connect-iq/core-topics/glances/),
[Annotations](https://developer.garmin.com/connect-iq/monkey-c/annotations/)

**Release graphics-pool references quickly.** Since API 4.0 runtime bitmaps and
fonts live in a separate graphics pool, not the app heap. `ResourceReference.get()`
locks the object in the pool for as long as the reference is in scope.
→ [Graphics](https://developer.garmin.com/connect-iq/core-topics/graphics/)

**Profile before optimising.** Use the simulator profiler (File → View Profiler)
and sort by call count as well as time: "a function that has a low average time
but is repeatedly called can sometimes cause performance bottlenecks". Build
with `-k` to profile on real hardware; the `.PRF` lands in `/GARMIN/APPS/LOGS`.
→ [Profiling](https://developer.garmin.com/connect-iq/core-topics/profiling/)

---

## 2. Monkey C style and safety

**Naming.** Modules and classes `UpperCamelCase`; functions `lowerCamelCase`;
private members `_leadingUnderscore`; enums share a prefix (`COLOR_RED`).
One class per file. Four-space indent. Call the superclass `initialize()` as the
first statement of every `initialize()`.
→ [Coding conventions](https://developer.garmin.com/connect-iq/monkey-c/coding-conventions/)

**Type checking is off unless you ask for it.** Levels are `-l 0` silent,
`-l 1` gradual, `-l 2` informative, `-l 3` strict. Combine with `-w` or you will
not see the warnings.

> **Our rule:** build at `-l 3 -w`. We are a single-device project with fully
> annotated source; there is no reason to accept ambiguity. **[inferred]**:
> Garmin documents the levels but does not prescribe one.

→ [Compiler options](https://developer.garmin.com/connect-iq/monkey-c/compiler-options/),
[Monkey Types](https://developer.garmin.com/connect-iq/monkey-c/monkey-types/)

**Build a dictionary literal in one go.** The compiler infers a dictionary's
type at construction, so assembling options with `put()` produces a type that no
longer matches `makeWebRequest()`. We hit this during the feasibility spike.

**Do not chain boolean operators over nullable method calls.** A single
expression combining several `substring()` / `toNumber()` results with `&&` and
`||` made the SDK's type checker exhaust the JVM heap and abort the build: a
crash in `FunctionTypeChecker.combineSubstitutions`, not a slow compile. Split it
into stepped `if` returns instead. Found while writing an ISO 8601 shape check;
the rewrite compiles faster and reads better.

This is an algorithmic blow-up, not a resource shortage. The JVM's default
ceiling here is a quarter of physical memory: 30 GB on the development machine,
with 75 GB free and no container limit, and it still ran out. Each `&&` over a
nullable result multiplies the type-substitution space the checker explores, so
no heap size saves you. Raising `-Xmx` is not the fix; rewriting the expression
is. **[inferred]**: the mechanism is our reading of the stack trace and the
memory figures, not something Garmin documents.

**Use `import`, not `using`,** when working with Monkey Types.
→ [Objects and memory](https://developer.garmin.com/connect-iq/monkey-c/objects-and-memory/)

**Probe optional API surface with `has`.** `if (Graphics has :createBufferedBitmap)`.
Interfaces are compile-time only, so `has` is also the runtime membership test.
→ [Monkey Types](https://developer.garmin.com/connect-iq/monkey-c/monkey-types/)

**Many errors cannot be caught.** Array out of bounds, out of memory, stack
overflow, watchdog tripped, symbol not found: these are fatal. Validate indices
yourself instead of hoping for a `catch`. "Watchdog tripped" means a function ran
too long and was killed, which is another reason to keep callbacks short.
→ [Exceptions and errors](https://developer.garmin.com/connect-iq/monkey-c/exceptions-and-errors/)

---

## 3. Interaction and interface

**Stay out of the way.** "Watches are best when used to observe… keep
interactions to a minimum." All information should be reachable **within three
to four interactions**. For this app that is the design constraint behind the
fast-access epic.
→ [User experience guidelines](https://developer.garmin.com/connect-iq/user-experience-guidelines/)

**Use `Menu2`, not the legacy `Menu`.** Cap each menu at about **seven items**.
Group longer lists into a parent/child structure. Toggles for on/off, checkboxes
for multi-select, and for other choices open a secondary menu while showing the
current value as sub-text on the parent item.
→ [Menus](https://developer.garmin.com/connect-iq/user-experience-guidelines/menus/),
[Native controls](https://developer.garmin.com/connect-iq/core-topics/native-controls/)

**Confirm only when the friction is warranted.** A confirmation dialog
interrupts; use it for actions with real consequences, not for everything. Phrase
it as an explicit yes/no question.
→ [Confirmations](https://developer.garmin.com/connect-iq/user-experience-guidelines/confirmations/)

**Show progress for every asynchronous action, and always offer a way out.**
Determinate when the end is known, infinite otherwise. Chained steps get one
continuous indicator, not several. Every web request in this app needs this.
→ [Progress bars](https://developer.garmin.com/connect-iq/user-experience-guidelines/progress-bars/)

**Prefer `BehaviorDelegate` over `InputDelegate`.** It maps device input to
portable behaviours (`onBack`, `onMenu`, `onSelect`, `onNextPage`,
`onPreviousPage`) so the same code survives a change of target device.
→ [Input handling](https://developer.garmin.com/connect-iq/core-topics/input-handling/)

**Never remap the back behaviour.** It is one of the most common behaviours on
Garmin devices.
→ [Input handling](https://developer.garmin.com/connect-iq/core-topics/input-handling/)

**Navigate vertically.** Up/down page loops map to both buttons and touch;
left/right does not map well to physical buttons.
→ [Designing workflows](https://developer.garmin.com/connect-iq/user-experience-guidelines/designing-workflows-and-interactions/)

**Minimise on-device text entry.** Long strings belong in the phone's app
settings, not on the watch. This is why the API key and VIN are configured from
the phone.
→ [Designing workflows](https://developer.garmin.com/connect-iq/user-experience-guidelines/designing-workflows-and-interactions/)

**But do not make the app useless without settings.** "Don't require the user to
use mobile app settings before they can use your app." We cannot avoid needing a
key, so the unconfigured state must be a helpful onboarding screen that explains
what to do: never a blank screen or an error.
→ [Designing workflows](https://developer.garmin.com/connect-iq/user-experience-guidelines/designing-workflows-and-interactions/)

**Use the Personality library** for native-feeling colours, icons, typography,
prompts and confirmations instead of hand-rolling visuals.
→ [Personality library](https://developer.garmin.com/connect-iq/personality-library/)

---

## 4. Application structure

**Lifecycle.** `onStart(state)` restores state; `getInitialView()` returns
`[View]` or `[View, InputDelegate]`; `onStop(state)` should persist when
`state.get(:suspend)` is set, because the system is reclaiming memory rather than
quitting. Do not depend on `onAppInstall()` or `onAppUpdate()`: they are not
guaranteed to run.
→ [Application and system modules](https://developer.garmin.com/connect-iq/core-topics/application-and-system-modules/)

**Storage, Properties and Settings are three different things.**

| | What it is | API | Limits |
|---|---|---|---|
| **Storage** | Runtime read/write, app-private, invisible to the user | `Application.Storage` | **8 KB per key, 128 KB total** |
| **Properties** | Build-time declared values and Settings defaults | `Application.Properties` | throws `InvalidKeyException` on an undeclared key |
| **Settings** | User-editable from the phone | `<setting>` bound to a `<property>` | typed: list, boolean, numeric, alphaNumeric, password, … |

Cached vehicle state goes in Storage. The API key and VIN are Settings backed by
Properties. Storage accepts only `Number, Float, Long, Double, Char, String,
Boolean, Array, Dictionary`, and arrays or dictionaries may only contain those
same types.
→ [Persisting data](https://developer.garmin.com/connect-iq/core-topics/persisting-data/),
[Properties and app settings](https://developer.garmin.com/connect-iq/core-topics/properties-and-app-settings/)

**React to settings changes** in `AppBase.onSettingsChanged()`, and to
background writes in `AppBase.onStorageChanged()`.

**A watch app may offer on-device settings** via `AppBase.getSettingsView()`:
watch faces and data fields may not. Useful for the things that are awkward to
change from the phone, such as target temperature.
→ [Properties and app settings](https://developer.garmin.com/connect-iq/core-topics/properties-and-app-settings/)

**Background services: five minutes minimum, thirty seconds to finish.**
`registerForTemporalEvent()` runs at most every five minutes, services can be
killed at any time to free memory for the foreground, and one that has not called
`Background.exit()` within thirty seconds is force-killed. Everything reachable
from the service must carry `(:background)`.
→ [Backgrounding](https://developer.garmin.com/connect-iq/core-topics/backgrounding/)

**A watch app can publish complications**, up to four, with the
`ComplicationPublisher` permission. Only watch faces subscribe. This is how we
give the user glanceable state without building a watch face.
→ [Complications](https://developer.garmin.com/connect-iq/core-topics/complications/)

---

## 5. Talking to a third-party web API

**Every request is proxied over BLE through the phone.** There are no raw
sockets; the API is a mailbox, not a socket. Latency and throughput are
BLE-bound even when the phone has fast connectivity, and the watch app can be
killed mid-exchange. Design every handler to survive being relaunched.
→ [Communicating with mobile apps](https://developer.garmin.com/connect-iq/core-topics/communicating-with-mobile-apps/)

**Wrap each request in its own function or class** rather than inlining url,
params, options and callback at the call site.
→ [JSON REST requests](https://developer.garmin.com/connect-iq/core-topics/https/)

**The `:responseType` rule for this project.** Measured against the real API,
not assumed, see [decisions.md](../decisions.md#the-api-and-what-it-does-to-the-code):

> Reads (`GET`): set `:responseType => HTTP_RESPONSE_CONTENT_TYPE_JSON`.
> Without it, `application/problem+json` error bodies come back as `-400` and
> the reason is lost.
>
> Commands (`POST`/`PUT`): leave `:responseType` out. Škoda answers `202` with an
> empty body and no `Content-Type`; with `:responseType` set that becomes `-400`
> and every successful command looks like a failure.

**Build URLs with a tested helper.** We shipped two path bugs during the spike:
a missing `/vehicles/` segment and a stray trailing slash before a query string.
Both reached a mock that was too lenient to catch them. URL construction gets
unit tests, and the mock rejects anything the real API would reject.

**Storage is the right home for a secret [inferred].** Properties are
build-time declared and Settings are user-visible; a runtime token belongs in
`Application.Storage`. Note that a key entered as a Setting is stored in plain
text on the device: say so in the UI rather than pretending otherwise.

---

## 6. Testing

**Unit tests run in the simulator only.** Annotate with `(:test)`, take a
`Test.Logger`, build with `-t`, run via `monkeydo <app>.prg <device> /t`. Tests
are stripped from release builds, and each test is isolated so one crash does not
stop the suite.
→ [Unit testing](https://developer.garmin.com/connect-iq/core-topics/unit-testing/)

**`System.println()` only reaches a device log** if you manually create
`/GARMIN/APPS/LOGS/<APPNAME>.TXT`. Crashes write `CIQ_LOG.YAML` there. Be aware
that the `ConnectIQ-Version` field in that log is the SDK you built with, not the
device's version. Logs rotate at 5 KB and cap around 10 KB, so pull them promptly.
→ [Debugging](https://developer.garmin.com/connect-iq/core-topics/debugging/)

**The simulator can trigger background services manually** (Simulation menu) and
edit persisted values (File → Edit Persistent Storage). Use ADB BLE simulation to
get realistic phone-proxy latency instead of the simulator's optimistic speed.
→ [Backgrounding](https://developer.garmin.com/connect-iq/core-topics/backgrounding/),
[Communicating with mobile apps](https://developer.garmin.com/connect-iq/core-topics/communicating-with-mobile-apps/)

**[unverified]** A simulator toggle to fake "no phone connected" is often
mentioned but is not in the official docs. Check the simulator's Connection menu
before writing a test that depends on it.

**After release, the Exception Reporting Tool** shows crash reports for 30 days
for published apps.
→ [Exception reporting tool](https://developer.garmin.com/connect-iq/core-topics/exception-reporting-tool/)

---

## 7. Publishing to the Connect IQ Store

**Third-party brands need the owner's permission: in writing.** "Your app may
be the perfect complement for someone else's product or brand. That doesn't mean
you have a right to use their intellectual property." Garmin explicitly refuses
to adjudicate: "Ask the IP owner, not us." The Developer Agreement makes you
warrant you hold the rights and indemnify Garmin.

For this project that settles it: **no Škoda logo, no Škoda colours or
typeface.** See [decisions.md](../decisions.md#branding) and [NOTICE](../../NOTICE).
→ [App review guidelines](https://developer.garmin.com/connect-iq/app-review-guidelines/)

**Do not claim compatibility you have not certified**, and never imply a
partnership with Garmin or with Škoda.

**Ship something finished.** "By the time you submit, your app should be fully
completed, tested, and ready for use… The app should not contain any broken links
or functionality." For a network-backed app that means every failure state is
handled, not just the happy path.

**Publish your own privacy policy.** You cannot rely on Garmin's. Collect and
retain the minimum, ask permission before using location, and expect GDPR to
apply. We use the `Communications` and `Positioning` permissions and handle a
vehicle location, which puts us squarely in scope.
→ [Publishing to the store](https://developer.garmin.com/connect-iq/core-topics/publishing-to-the-store/)

**Guard the signing key.** Uploads signed with a different developer key than the
previous upload are rejected. Losing it means losing the app listing.
→ [Security](https://developer.garmin.com/connect-iq/core-topics/security/)

**Review takes about 72 hours**, plus 48 more if you declare ANT+ usage. Beta
Apps let you stage a build under a separate UUID first.
→ [Publishing to the store](https://developer.garmin.com/connect-iq/core-topics/publishing-to-the-store/),
[Beta apps](https://developer.garmin.com/connect-iq/core-topics/beta-apps/)

---

## Checklist

Use this at the end of every task.

- [ ] Builds clean at `-l 3 -w`
- [ ] No resource loading in `onUpdate()`; parsing happens once, on response
- [ ] Every back-reference is a `WeakReference`
- [ ] New resources carry an explicit `scope`
- [ ] `Menu2` used; no menu exceeds seven items
- [ ] Every async action shows progress and can be cancelled
- [ ] `BehaviorDelegate` used; back behaviour untouched
- [ ] `GET` sets `:responseType`; commands do not
- [ ] Every new URL is covered by a unit test
- [ ] The mock rejects what the real API rejects
- [ ] Failure states designed, not just the happy path
- [ ] Nothing in the UI, icon or store text uses Škoda's marks beyond the plain word
