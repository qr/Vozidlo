# Changelog

Notable changes, newest first. Versions match what is published to the Connect
IQ Store.

## 1.3.0: 2026-10-23

### Added

- **Vozidlo runs on 43 watches instead of six.** New are the Forerunner
  255S and 255S Music (218 round), the fēnix 7S and 7S Pro (240 round), the
  fēnix 7X, 7X Pro, 7X Pro Solar Edition (no Wi-Fi), 8 Solar 51mm and 9 Pro
  Solar 51mm and the Enduro 3 (280 round), the Forerunner 255 and 255 Music,
  and on AMOLED the Venu 3S, vívoactive 5 and 6, Venu 4 41mm, epix Pro
  (Gen 2) 42mm, MARQ (Gen 2), Descent Mk3 43mm and Descent G2 (390 round),
  the epix Pro (Gen 2) 47mm, fēnix 8 43mm and Forerunner 265 (416 round),
  the Venu 3, Venu 4 45mm, fēnix 8 and 8 Pro (AMOLED), fēnix 9 and 9 Pro
  47mm (AMOLED), epix Pro (Gen 2) 51mm, Forerunner 965 and 970, D2 Mach 2
  and Mach 2 Pro and Descent Mk3i 51mm (454 round) and the Venu X1 (448×486
  rectangle). Only the fēnix 7 Pro has been worn; the others are
  built and unit-tested with `tools/ciq verify` and checked on the devices
  design page.

- **Connect IQ 5.1 is enough.** The minimum is 5.1 instead of 5.2, for the
  Descent Mk3 and Mk3i; the app uses nothing newer without checking for it.

- **The map is optional.** It is on the fēnix watches, the Forerunner 955
  and the Venu X1. Elsewhere the app is built without it, Find my car shows
  the address, distance and bearing, and START opens the Find my car list
  with Navigate and Refresh. Navigate is hidden where the watch has no
  waypoint support, which the app checks at runtime; on the Venu 3 and 3S
  that is not yet verified.

- **The app follows each watch's buttons.** Five-button watches work as
  before, with touch where the watch has it; the Forerunner 255 has no
  touchscreen. On the Venu 3 and 3S, MENU is holding BACK. The vívoactive
  6, Venu 4 and Venu X1 have no MENU button: the app's menus open with a
  swipe left, shown by Garmin's action menu indicator.

### Changed

- **Home opens on Status.** The default order is Status, Find my car, then
  the commands and the rest, and home opens on its first row so the state of
  charge and chips are in view. The most-used command is the first climate
  row, two rows down. An order you saved yourself is kept.

- **The target temperature is a list.** It offers 16 to 30 °C, like the
  charge limit, instead of a value you step up and down.

- **Empty screens no longer name a button.** They say "Refresh from the
  menu" or "Try again from the menu", which reads the same on every watch.

- **START on Find my car opens the list where there is no map.** On a
  watch with the map it still opens the map.

- **The app icon is drawn at each watch's launcher size.**

- **Layouts are computed from the screen.** Sizes and positions follow each
  watch's resolution and fonts. The fēnix 7 Pro is pixel-identical to
  1.2.0; the fēnix 7, 8 and 9 and the Forerunner 955 follow their own
  fonts, which fixes the age overlapping the status text there.

### Fixed

- **One "rate limit exceeded" stopped the app for good.** After that error
  the app never asked the car again until you cleared all stored data. It
  now waits an hour, the length of the quota window, shows when it may ask
  again, and then carries on. A watch stuck this way on 1.2.0 can ask again
  as soon as 1.3.0 is installed.

- **"Clear stored data" left the car's position behind.** It now also
  removes the last parked position, the saved location for Navigate, the
  tile order and the parking flag, as the privacy policy says, and it is in
  Settings, not only in the menu during setup. After clearing, the app
  closes; the next start opens setup.

- **A tap could spend a request from the hourly quota.** A tap on Charging
  profiles after a failed fetch, and on the onboarding retry or blocked
  screens, sent a request. Taps there are now consumed.

- **Refresh and Navigate on Find my car were only behind MENU.** Where
  there is no map, START now opens the Find my car list with both; on
  watches without a MENU button the list also opens with a swipe left.

### Project

- **`tools/ciq verify` is the check before every pull request.** It runs
  `tools/checks.py`, the design page checks, `build --all` with warnings
  fatal and each build's size against that watch's memory budget, and the
  unit tests on one watch per screen family and input profile.

- **Warnings fail the build.**

- **CI checks that the product lists agree.** The manifest, the README, the
  store listing and the committed device facts in
  `tools/ui/devices/11-devdata.js` must name the same watches. CI cannot
  build the app, because the device files need a Garmin login.

- **The lists of watches are generated.** `tools/devicelists.py` writes the
  README and guide tables, the store listing's requirements, the manifest
  comment and the jungle's per-watch lines from the manifest and the device
  facts, and the devices page builds its columns from them, so adding a
  watch is a manifest line and two generator runs.

- **A build larger than its watch's memory budget fails**, and so does
  `tools/ciq verify`.

- **`tools/ciq run` loads the watch it built.** With `CIQ_DEVICE` set it
  used to load the fēnix 7 Pro's build.

- **How to release** is written down in `docs/releasing.md`.

- **A devices design page**, `docs/design/vozidlo-devices.html`, shows every
  screen on every supported watch, fit-checked by
  `node tools/ui/fitcheck.mjs --devices`.

## 1.2.0: 2026-10-08

### Added

- **The app checks the car after a command.** About 15 seconds after a
  command is accepted, the app reads the car once and says what it
  reported: "Climate on", "Charging stopped", "Limit set to 80%", or "Car
  reports: Off" in amber when the car shows something else. When the car
  has not reported anything newer yet, the line says so in grey; it is
  never shown as an error. This covers every command: climate,
  ventilation, auxiliary heater, charging, the charge limit and the charge
  mode. It costs one extra request per command, so it is a setting, "Check
  the car after a command", on by default. It is skipped when the phone is
  not connected or the hourly quota is spent or nearly spent.

## 1.1.6: unreleased

### Fixed

- **Stop climate, start and stop charging and ventilation never reached the
  car on Android.** The watch showed "Not sent (0)". These commands carry
  no body, and Garmin Connect on Android does not send a JSON request
  without one: it answers the watch with code 0 and nothing goes out.
  Measured on 2026-10-08 with adb and the API's rate-limit counter: start
  climate, which has a body, arrived; stop climate did not. Every command
  now sends at least an empty JSON object, which Škoda accepts with the
  same 202, and `tools/checks.py` refuses a POST or PUT with a null body.

## 1.1.5: unreleased

### Fixed

- **A failed command never said why.** Every refusal read "Not sent:
  Something went wrong (status …)", and the status was cut off at the end
  of the line. A command's error body cannot be read on the watch (see
  `ApiClient.mc`), so the reason now comes from the status: "Your car can't
  do this." for 422, "The API key was not accepted." for 401, and so on.
  The status goes first, "Not sent (422): …", where the cut never reaches
  it. The charge limit and charge mode menus say it the same way, instead
  of "Vehicle refused".

- **Home offered commands the car does not have**, ventilation on a car
  without it for example. Home hides a command the car does not list, but
  the Status refresh never asked for that list: with `include`, the API
  leaves it out. It now asks for it.

## 1.1.4: unreleased

### Fixed

- **1.1.3 crashed at launch** with the Connect IQ error screen. The list
  kept its own record of the focused row, but the watch sets the opening
  focus while the list is still being built, before that record existed.
  The record is now made first, and the unit tests build the real home
  screen and lists so a crash like this fails the tests.

## 1.1.3: unreleased

### Fixed

- **A list opened with no rows drawn.** In 1.1.2 a list, home included,
  showed none of its rows at first, and they appeared a moment later. Each
  row worked out which row had the focus by asking every row whether it was
  focused, which the watch only answers reliably for the row being drawn. A
  list now starts from the row it opens on, follows the focus as rows report
  it, and redraws once when it moves.

## 1.1.2: unreleased

### Changed

- **The three rows of a list sit closer together.** In 1.1.1 they were
  spread over the whole face. Rows are now 65 px apart and only the focused
  row and the one above and below are drawn, so the rest stays off screen
  until the list scrolls to it: the row at one end leaves and the next one
  comes in at the other. On home the battery figure is large again, and the
  Plugged in chip is back.

## 1.1.1: unreleased

### Fixed

- **Scrolling home opened Charging or Status by itself.** Pressing UP on the
  first row opened charging detail, and DOWN on the last row opened the status
  pages, so someone scrolling through the list saw a screen open that they
  never chose. The list now wraps at both ends, like Garmin's own menus;
  Charging and Status are rows in it.

- **Lists showed five rows and cut off the outer two.** Rows were sized from
  the font, so five fitted on the screen and the top and bottom ones ran into
  the round edge. Every list now shows three rows: the focused one in the
  middle and one above and below, with their text fitted to the circle. On
  home the battery figure is a little smaller to make room.

## 1.1.0: unreleased

### Changed

- **A new look: the Night Panel.** Every screen is redrawn on black with one
  accent colour, Škoda Electric Green, and words where 1.0 showed raw API
  values. Stale data is marked in amber with a "!" (`! 17 h ago`) rather than
  red, so an old reading no longer looks like an error.

- **Home is a list with the car's state on top.** State of charge with a ring
  around the bezel, lock and charging chips and the age of the data sit above
  the actions; every action is a row, so UP and DOWN scroll and START runs the
  focused row. Your most-used action still has the focus at launch.

- **Charging detail is reachable again.** In 1.0 it could only be opened with
  UP on home, and on the watch UP moved the tile focus instead, so charging
  detail, the charge limit, the charge mode and the profiles could not be
  reached with buttons at all. It is now a Charging row on home, and UP past
  the first row.

- **Status pages have page dots and an action list.** DOWN past the last row
  on home opens them; UP and DOWN page through lock, range, charging,
  odometer and climate, with dots in the bezel showing where you are. START
  opens a short list with Refresh and the charging details.

- **The charge limit is a list** of steps with the current one ticked, instead
  of a value you step up and down.

- **Find my car** shows the distance inside a ring, with a pointer on the ring
  towards the car, and MENU on the map now offers Navigate.

- **The glance, the onboarding screens and the complication icons** follow
  the same design. The complication icons are 28×28.

- **Complications show words.** A watch face now reads "Plugged in" or
  "Locked", with the same wording as the app, where the charging
  complication showed the API value (`READY_FOR_CHARGING`).

- **Tile order has a Charging row.** The order screen lists Charging, the
  detail screen's row on home, and the start/stop pair is now called
  "Charge on/off". An order saved in 1.0 keeps its sequence and gets
  Charging right after the charging commands.

- **Charging detail no longer shows the charging rate.** The "Rate" row in
  km/h is gone; power and the other details stay.

- **A steering wheel as the app icon.** The car silhouette on a grey tile is
  replaced by a three-spoke steering wheel in Electric Green with an Emerald
  hub, on a transparent background, so it sits on the watch's own black in
  the app list and the glance list.

### Fixed

- **Text was clipped by the round screen.** Lines placed near the top or
  bottom were wider than the circle allows there. Every line is now fitted to
  the width available at its height, measured with the fonts the watch
  actually has.

- **Letters were drawn in the number font.** The large number font holds only
  digits and a few symbols, so words like LOCKED, OFF and units came out
  garbled. Numbers stay in the number font; words and units use a text font.

- **The focus jumped back to the top after every action.** Home now keeps the
  row you left, after a command, a confirmation or a visit to another screen.

- **The More menu stayed open after a choice.** There is no More menu any
  more; menus close when you pick something.

- **Menus slid out the wrong way.** They came in from the right and left
  downwards; every menu now slides in from and out to the right.

- **Profiles said "SELECT to load" and SELECT did nothing.** START now loads
  them again after a failed or blocked fetch, shown by a glyph at the button.

- **Swiping up lowered values** on the charge limit and the target
  temperature. Swipe up now raises them, like UP.

- **A stray tap on status or charging refreshed**, spending a request from the
  hourly quota. Refresh is now only in the action list.

### Removed

- **The tile grid**, its scrolling (`GridScroll`) and the More menu: home is a
  list now.

- **Text hints along the bottom of the screen** ("UP charging - DOWN status",
  "SELECT to load", "Menu for more."). Where a button does something worth
  showing, an arc or glyph at the button says so.

### Development

- **A style guide**, [docs/design/style-guide.md](docs/design/style-guide.md):
  colours, fonts, components and wording for every screen, with a checklist
  for a new or changed one.

- **A design reference and UI checks in `tools/ui`.** The reference
  (`docs/design/vozidlo-poc.html`) is built from `tools/ui/poc/`, and a new
  CI job checks it matches its sources and that every screen fits the round
  display.

- **Three new checks in `tools/checks.py`**: no `loadResource` inside
  `onUpdate`, no vertical slide in a menu delegate file, and no orange in
  the app.

## 1.0.3: 2026-10-07

### Fixed

- **Opening the map showed the Connect IQ error screen.** "Find my car" drew the
  bearing arrow and the parked address correctly, but selecting it to open the
  map crashed the app with `UnexpectedTypeException: Screen visible area top
  left is not set`.

  `MapPreviewView` built its markers, map mode and visible area in `onShow()`,
  which runs once the view is already being rendered, too late for state the
  render reads. It also never called `setScreenVisibleArea()`. Both are fixed:
  every map call now happens in the constructor, in the order Garmin's own
  `MapSample` uses.

  Nothing else was affected. The bearing arrow and the address come from the
  cached parking position and never touch `MapView`, which is why that half kept
  working.

## 1.0.2: 2026-10-06

### Project

- **Repository and CI changes only, as in 1.0.1.** 1.0.2 tags the same
  commit; the application binary is identical to 1.0.0.

## 1.0.1: 2026-10-06

### Project

- **CI runs checks that can actually pass.** The Connect IQ app build left
  CI: a hosted runner cannot get the device files, which come only from
  Garmin's SDK Manager behind an account login, nor the signing key, which is
  never committed. The build happens locally before merging, and
  CONTRIBUTING.md says so.

  In its place `tools/checks.py` runs alongside the mock suite: documentation
  links, YAML validity, the manifest and the device guide agreeing, unfilled
  placeholders, and a sweep for personal or vehicle data.
  `actions/checkout` and `actions/setup-python` move to v7, off the
  deprecated Node 20 runtime.

  The application binary is identical to 1.0.0.

## 1.0.0: 2026-10-06

First public release.

Vozidlo reads and controls a Škoda from a Garmin watch, through Škoda's official
MyŠkoda Public API: state of charge, range, lock status, doors, odometer and
fuel, starting and stopping the air conditioning and charging, and finding where
the car is parked. There is also a glance, and four complications for your own
watch face.

Supported watches, all device family `round-260x260`: fēnix 7 Pro, fēnix 7,
fēnix 7 Pro Solar (no Wi-Fi), fēnix 8 Solar 47mm, fēnix 9 Pro Solar 47mm and
Forerunner 955.

### What it cannot do

- **Lock or unlock the car.** The API has no endpoint for it, so no app built on
  that API can.
- **Confirm a command worked.** The API is fire-and-forget. Commands report
  "sent", and a separate request is the only way to learn what happened.
- **Show live data.** Readings are whatever the car last reported, sometimes
  minutes old and sometimes hours. Every section shows its own age.
- **Work with your phone out of range.** Connect IQ routes every request through
  the Garmin Connect app, so no phone means no new data. The last known state
  stays on screen with its age beside it.

### Verification

Run on a fēnix 7 Pro. The other five devices are verified in the simulator and
against the included mock server only; they are claimed on matching device
family, memory budgets and API implementations rather than on anyone having worn
one. [docs/adding-a-watch.md](docs/adding-a-watch.md) explains how that decision
is made, and [docs/decisions.md](docs/decisions.md) why the code is shaped the
way it is.
