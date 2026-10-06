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
it: the screen family, the buttons, and whether the APIs are genuinely
implemented rather than merely resolving.

The short version of the third one, because it is the trap: **a clean build does
not mean a device is supported.** The Forerunner 255 builds perfectly at this
project's strictest settings and is excluded, because it has no
`WatchUi.MapView` implementation behind a type that type-checks fine.

## Setting up

The toolchain runs in a container. Not for isolation: the Connect IQ SDK
Manager and simulator link `webkit2gtk-4.0` against `libsoup2`, and Ubuntu
24.04 ships only 4.1 with `libsoup3`, which cannot coexist in one process.

```bash
cd tools && docker build \
  --build-arg UID=$(id -u) --build-arg GID=$(id -g) --build-arg HOME_DIR="$HOME" \
  -t ciq:22.04 .

tools/ciq sdkmanager   # once: sign in, download the device files
tools/ciq run          # build and launch in the simulator
tools/ciq test         # unit tests
tools/ciq              # no arguments: prints the commands and the device list
```

`tools/ciq` generates a developer signing key on first use. It is gitignored
and yours; it never leaves your machine.

The device files require a Garmin account. That is Garmin's restriction, not
ours, and it is why CI restores them from a cache rather than downloading them.

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

**Strict typing, warnings are errors.** `-l 3 -w`. If a build seems to hang
rather than fail, it is likely the type checker's memory use exploding on
chained booleans over nullable calls, not your machine.

**Tests for logic that broke, or could.** Pure functions with the platform
passed in as a callback are the pattern used throughout, see
`ui/TextBlock.mc` and its tests for the clearest example. It is what lets the
geometry be tested without a `Dc`.

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
- **Use the Škoda logo, brand colour or typeface.** No trademark licence exists
  for third parties. [decisions.md](docs/decisions.md#branding) has the
  reasoning and the case law.
- **Ship a watch face.** Out of scope by choice. The app publishes
  complications so you can put its data on the watch face you already use.
