# Contributing

Pull requests are open to anyone. There is no CLA, no contributor agreement,
and nothing to sign. Open a PR, I read it, and if it makes sense it gets
merged.

The change I most expect, and most want, is **another watch**. There is a
procedure for it below and it is short.

## On using AI

Using AI to write code here is fine. Two conditions:

**Say so.** The pull request template has a line for it. Not as a confession:
nobody is going to think less of your PR, but because a reviewer reads
AI-assisted code differently, and finding out afterwards wastes everyone's
time. Say roughly how much: "wrote the tests", "the whole thing", "used it to
find the API".

**Make it make sense.** The bar is the same as for anything else: you
understand what you sent, you can answer a question about it, and it does what
the description says. A PR that is obviously unread model output: plausible
code that does not compile, tests that assert nothing, comments describing a
function that is not there: gets closed regardless of who or what wrote it. A
well-reasoned change that happens to be AI-assisted is as welcome as any other.

Most of this repository was written with AI assistance. It would be strange to
hold contributors to a rule the maintainer does not follow.

## Adding a device

**This is the change most wanted, and there is a guide for it:
[docs/adding-a-watch.md](docs/adding-a-watch.md).**

It is the full procedure, which files to read, which commands to run, what the
output should look like, and what to do when a check fails. Three checks decide
it: a screen family the layouts have been through, with enough memory; one of
the three input profiles (five buttons, START and BACK with MENU on a long
press of BACK, or START and BACK without MENU); and whether the required APIs
are genuinely implemented rather than merely resolving.

The short version of the third one, because it is the trap: **a clean build does
not mean a device is supported.** The Forerunner 255 builds perfectly at this
project's strictest settings and has no `WatchUi.MapView` implementation
behind a type that type-checks fine. It ships since 1.3.0 only because the map
is now left out of its build; the device file said so, not the compiler.

## Setting up

The toolchain runs in a container. Not for isolation: the Connect IQ SDK
Manager and simulator link `webkit2gtk-4.0` against `libsoup2`, and Ubuntu
24.04 ships only 4.1 with `libsoup3`, which cannot coexist in one process.

```bash
cd tools && docker build \
  --build-arg UID=$(id -u) --build-arg GID=$(id -g) --build-arg HOME_DIR="$HOME" \
  -t ciq:22.04 .

tools/ciq              # no arguments: the commands, and every device and whether it is present
tools/ciq sdkmanager   # once: sign in, download every device that list names
tools/ciq run          # build and launch in the simulator
tools/ciq test         # unit tests on the primary watch
tools/ciq verify       # the gate before a pull request, see House style
```

Download every device `tools/ciq` lists, not only your own watch: `tools/ciq
verify` builds all of them and stops before it starts when one is missing.

Besides Docker, the host needs `python3` (with `fontTools`, `pip install
fonttools`, for `tools/ui/devices/devdata.py`) and `node` for the design
checks. Chrome or Chromium is optional: `tools/ui/devices/shoot.sh` uses it to
open the devices page headless, and `tools/ciq verify` skips that step without
it.

`tools/ciq` generates a developer signing key on first use. It is gitignored
and yours; it never leaves your machine.

The device files require a Garmin account. That is Garmin's restriction, not
ours, and it is why CI does not build the app: a hosted runner cannot log in to
the SDK Manager, so it never has the device files. CI checks that the
repository is consistent instead, and the build happens locally, with
`tools/ciq verify`, run by contributors before a pull request and by the
maintainer before merging.

### The mock server

Develop against `mock/`, not against a real car. It reproduces the measured
response shapes (including the ones that look like bugs) and can play the
failures you cannot trigger on demand: expired key, exhausted quota, partial
data, a car in motion.

```bash
mock/run.sh                              # HTTPS :8792, HTTP :8793
mock/run.sh --scenario rate-limit-exceeded
python3 -m venv mock/.venv && mock/.venv/bin/pip install -r mock/requirements-dev.txt
mock/.venv/bin/python -m pytest mock/tests
```

Pointing the simulator at it needs the mock's CA in the container's trust
store; `mock/README.md` has the two commands.

## House style

**Comments explain why, not what.** The code says what it does. A comment earns
its place by recording a decision, a measurement, or a trap: something a
reader cannot recover by reading more carefully. There are a lot of comments
here and most of them cite a specific reason.

**Strict typing, warnings are errors.** `-l 3 -w`, and a compiler warning
fails `tools/ciq build` (the log is in `app/bin/logs/build-<id>.log`).
`CIQ_ALLOW_WARNINGS=1` lets a build through while you iterate; `tools/ciq
verify` ignores it. If a build seems to hang rather than fail, it is likely the
type checker's memory use exploding on chained booleans over nullable calls,
not your machine.

**`tools/ciq verify` before every pull request that touches `app/`.** It runs
`tools/checks.py`, the design checks and the device facts check, builds every
product in the manifest with warnings as errors and within its memory budget,
and runs the unit tests in the simulator on one watch per screen family and
input profile. Paste the block it prints under "For the pull request" into the
PR. Exit 0 is green and 1 is red. Exit 2 means it did not run, because
something is missing on your machine (a device file, the display, a tool); it
says what. **Exit 2 is not a pass**, and a PR that says "verify: 2" has not
been verified.

**What CI does and does not check.** On every push and pull request CI runs
the mock suite, `tools/checks.py` (links and anchors, every list of watches
agreeing with the manifest and the committed device facts, the map left out
where it is missing, no personal data) and the design checks in `tools/ui/`.
You can run all of it locally:

```bash
mock/.venv/bin/python -m pytest mock/tests
python3 tools/checks.py
tools/ui/build.sh --check && tools/ui/build-devices.sh --check
node tools/ui/fitcheck.mjs && node tools/ui/fitcheck.mjs --devices
```

The Connect IQ app itself is **not** built in CI, and cannot be: the device
files come only from Garmin's SDK Manager behind an account login, and signing
needs a key that must never be committed. A green CI says the repository is
consistent, not that the app builds. Your `tools/ciq verify` summary is the
only evidence of that anyone has until the maintainer runs it again before
merging.

**Tests for logic that broke, or could.** Pure functions with the platform
passed in as a callback are the pattern used throughout, see
`ui/TextBlock.mc` and its tests for the clearest example. It is what lets the
geometry be tested without a `Dc`. The layout functions take the screen as a
`Geo.Display` (`ui/Geometry.mc`), so one test run on one simulator can check
the numbers of every watch: `GeoTests` pins the fēnix 7 Pro's, and the other
suites run fixtures for the other screens.

**Screens follow the style guide.** [docs/design/style-guide.md](docs/design/style-guide.md)
has the colours, fonts, components and wording every screen uses, and a
checklist for a new or changed screen. Draw through `Ui`, `Chips`, `Bezel` and
`NightMenu` rather than with raw `dc` calls, and the outline, monochrome and
number-font rules mostly hold by themselves: every line is fitted to the
screen's outline at its own y, a chord on a round watch and the rounded
rectangle on the Venu X1. Section 11 of the guide lists the
tools that check a screen, in the app and in the design reference.

**Requirement ids** like `US-036` appear in comments; they resolve in
[docs/requirements.md](docs/requirements.md).

## Never commit

- `app/developer_key.der`: the signing key. Gitignored. Anyone holding it can
  publish as you.
- `mock/tls/`: locally generated certificates and private keys.
- **Real vehicle data.** No VIN, no API key, no coordinates, no addresses, no
  odometer readings.

That last one is not hypothetical. This repository previously carried a real
street address and its GPS coordinates, copied from a live response while
building fixtures. A parking position is somebody's home address.

`mock/tests/test_privacy.py` enforces it and will fail your PR. Use the
placeholders already there: VIN `TMBMOCKVIN0000017`, coordinates
`52.100000, 5.100000`, address `Testlaan 1, 1000 AA Teststad`. Copy a real
response for its **shape**, never for its **values**.

## Reporting things

Issues are open. There are templates for a bug, a feature and a device request.

For anything security- or privacy-shaped, read [SECURITY.md](SECURITY.md)
first: the short version is that there is no server to attack, but there are
real considerations around where the API key lives.

## What this project will not do

Not to discourage the PR, but to save you writing it:

- **Lock or unlock the car.** The API has no endpoint. Nothing built on it can.
- **Poll in the background.** 20 requests per hour per vehicle, shared with
  every other client on the same car.
- **Claim a command succeeded.** The API is fire-and-forget; the app can
  honestly say "sent" and nothing more.
- **Use the Škoda logo or typeface.** No trademark licence exists for third
  parties, so the name stays a plain word. Škoda Electric Green is the app's
  one accent colour by decision, not an opening for more of the brand.
  [decisions.md](docs/decisions.md#branding) has the reasoning and the case
  law.
- **Ship a watch face.** Out of scope by choice. The app publishes
  complications so you can put its data on the watch face you already use.
