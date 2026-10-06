# Connect IQ Store listing

Draft text for the store submission. Kept here so it is reviewed like any other
deliverable rather than typed into a web form and forgotten.

---

## App name

**Vozidlo**

Czech for "vehicle". Deliberately not named after the marque: no third-party
licence exists for the Škoda marks, so the brand belongs in the description as a
statement of compatibility, not in the product name. Garmin's own review
guidance on this is blunt, "Ask the IP owner, not us", and the IP owner has no
channel to ask.

## Short description

For Škoda drivers. Check your car from your wrist: charge, climate, and where
you parked it.

## Full description

Vozidlo controls a Škoda from a Garmin watch, through Škoda's official MyŠkoda
Public API. Czech for "vehicle", and an independent app with no connection to
Škoda Auto.

I built it for my own car, because pulling out a phone to start the climate
in a cold car park is more work than it should be.

It shows the state of your vehicle and lets you control the things the official
API actually exposes:

- State of charge, remaining range, and charging status
- Whether the car is locked, and whether any door, window or the boot is open
- Odometer and fuel level, with both engines on a plug-in hybrid
- Start and stop the air conditioning, with a target temperature
- Start and stop charging, set the charge limit and the charge mode
- Where the car is parked, with an address, a bearing, a map, and navigation to it

### What it cannot do

**It cannot lock or unlock your car.** The official Škoda API has no endpoint for
that, so no app built on it can. You can see whether the car is locked, and that
is all. If locking from your wrist is what you came for, this app is not it.

Nor can it do anything if your phone is out of range. Connect IQ sends every
request through the Garmin Connect app on your phone, so no phone means no data.
The app keeps showing what it last saw, with the age next to it.

### You need your own API key

Škoda's API is free and open to anyone, but each user creates their own key. In
the MyŠkoda app (version 8.16 or later), open the API key management screen,
create a key, and select the vehicle it may access. Then enter that key and your
VIN in this app's settings in Garmin Connect.

Keys are valid for about six months. There is no automatic renewal, so twice a
year you will need to create a new one and type it in again.

### About the request limit

Škoda allows 20 requests per hour per vehicle, shared with anything else you run
against the same car, such as Home Assistant. That is roughly one every three
minutes, which sounds tight and mostly is not, as long as the app never polls in
the background. It does not. Everything happens when you ask for it.

One consequence worth knowing: the data comes from whatever your car last
reported, not from a live reading. Sometimes that is minutes old, sometimes
hours. The app shows the age of each piece of information rather than pretending
it is current.

### Getting to it quickly

The fastest route is to make the app a favourite: hold MENU, go to Activities &
Apps, select the app, and choose Set as Favourite. It then sits at the top of the
list you reach by pressing START.

There is also a glance showing charge, charging status and lock state, and four
complications you can put on your own watch face.

## Requirements

- Garmin fēnix 7 Pro, fēnix 7, fēnix 7 Pro Solar, fēnix 8 Solar 47mm,
  fēnix 9 Pro Solar 47mm or Forerunner 955, with Connect IQ 5.2 or later
- A Škoda with connected services active
- The MyŠkoda app, version 8.16 or later, to create an API key
- Your phone within Bluetooth range

## Permissions

- **Communications**, to reach the Škoda API through your phone
- **Positioning**, to work out how far away your car is and in which direction
- **ComplicationPublisher**, to offer complications to your watch face
- **PersistedContent**, to save your car's position as a waypoint for navigation

## Disclaimer

Required verbatim in the store description:

> Independent, unofficial app. Not affiliated with, endorsed by, or sponsored by
> Škoda Auto a.s. or the Volkswagen Group.

## Privacy policy

Links to [`privacy-policy.md`](privacy-policy.md), which has to be published at a
public URL before submission. Garmin's own policy does not cover us.

---

## Notes for whoever submits this

Do not claim compatibility with anything we have not tested. The app is built and
verified against one plug-in hybrid, and the API's own `operations[]` list decides what
appears for other models, but that is not the same as having tried them.

The same rule governs the watch side, with one deliberate softening. Six device
ids are in the manifest; only the fēnix 7 Pro will be worn by anyone here. The
other five are claimed on the strength of three checked facts rather than a
hunch: identical device family and memory budgets in their own compiler.json,
the full implementation of all four APIs we use in their own api.debug.xml, and
a clean `-l 3 -w` build plus the unit suite in CI for each.

That bar is what keeps the Forerunner 255 out. It passes the first and the
third (same family, builds clean) and fails the second: no MapView
implementation behind the type. A green build is not evidence of support, which
is the same lesson the glance crash taught. `app/manifest.xml` carries the
per-device reasoning.

The description states the unlock limitation twice, once in the summary list and
once under its own heading. That is deliberate. It costs a few installs and saves
a stream of one-star reviews from people who expected it.

Review takes about 72 hours. An upload signed with a different developer key than
the previous one is rejected, so `app/developer_key.der` needs a backup that
survives losing this machine.
