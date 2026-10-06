# Changelog

Notable changes, newest first. Versions match what is published to the Connect
IQ Store.

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
