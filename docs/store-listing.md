# Connect IQ Store listing

The text of the app's Connect IQ Store listing. Kept here so it is reviewed
like any other deliverable rather than typed into a web form and forgotten; a
change to the listing is made here first and then copied to the store.

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
- Where the car is parked, with an address, a distance and a bearing; on
  watches with onboard maps also a map, and navigation to it where the watch
  supports it

### What it cannot do

**It cannot lock or unlock your car.** The official Škoda API has no endpoint for
that, so no app built on it can. You can see whether the car is locked, and that
is all. If locking from your wrist is what you came for, this app is not it.

Nor can it do anything if your phone is out of range. Connect IQ sends every
request through the Garmin Connect app on your phone, so no phone means no data.
The app keeps showing what it last saw, with the age next to it.

The API is fire-and-forget: a command is only confirmed by reading the car
afterwards. The app does that once, about 15 seconds later ("Climate on"), for
one extra request. You can switch it off in the settings.

Every command asks first, so it no longer goes out on a single tap, and a
quick double tap sends nothing. If you would rather send on one tap, switch "Confirm commands" off in the settings in
Garmin Connect, or "Confirmation" in Settings on the watch.

### You need your own API key

Škoda's API is free and open to anyone, but each user creates their own key. In
the MyŠkoda app (version 8.16 or later), open the API key management screen at
https://go.skoda.eu/api-keys, create a key, and select the vehicle it may
access. Then enter that key and your VIN in this app's settings in Garmin
Connect.

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

The fastest route is to make the app a favourite in your watch's settings. On
the fēnix and Forerunner watches: hold MENU, go to Activities & Apps, select the
app, and choose Set as Favourite. On the Venu 3 and Venu 3S, hold BACK to reach
the same settings. On the other watches, the favourites are in the watch's own
settings menu. The app then sits at the top of the list you reach by pressing
START.

Inside the app, its menus open with MENU on the fēnix and Forerunner watches,
by holding BACK on the Venu 3 and Venu 3S, and with a swipe left on the
vívoactive 6, Venu 4 and Venu X1, where Garmin's action menu indicator at the
right edge shows that there is one.

There is also a glance showing charge, charging status and lock state, and four
complications you can put on your own watch face.

## Requirements

<!-- devicelists begin -->
<!-- products: fenix7pro="fēnix 7 Pro"; fenix7="fēnix 7"; fenix7pronowifi="fēnix 7 Pro Solar Edition (no Wi-Fi)"; fenix8solar47mm="fēnix 8 Solar 47mm"; fenix9prosolar47mm="fēnix 9 Pro Solar 47mm"; fr955="Forerunner 955"; venu3s="Venu 3S"; venu3="Venu 3"; vivoactive6="vívoactive 6"; venu441mm="Venu 4 41mm"; venu445mm="Venu 4 45mm"; venux1="Venu X1"; fenix7s="fēnix 7S"; fenix7spro="fēnix 7S Pro"; fenix7x="fēnix 7X"; fenix7xpro="fēnix 7X Pro"; fenix7xpronowifi="fēnix 7X Pro Solar Edition (no Wi-Fi)"; fenix8solar51mm="fēnix 8 Solar 51mm"; fenix9prosolar51mm="fēnix 9 Pro Solar 51mm"; fr255="Forerunner 255"; fr255m="Forerunner 255 Music"; enduro3="Enduro 3"; epix2pro42mm="epix Pro (Gen 2) 42mm"; marq2="MARQ (Gen 2)"; marq2aviator="MARQ (Gen 2) Aviator"; descentmk343mm="Descent Mk3 43mm"; fenix847mm="fēnix 8 47mm and 51mm"; fenix8pro47mm="fēnix 8 Pro 47mm and 51mm"; fenix947mm="fēnix 9 47mm and 51mm"; fenix9pro47mm="fēnix 9 Pro 47mm"; fr965="Forerunner 965"; fr970="Forerunner 970"; d2mach2="D2 Mach 2"; d2mach2pro="D2 Mach 2 Pro"; epix2pro51mm="epix Pro (Gen 2) 51mm"; descentmk351mm="Descent Mk3i 51mm"; fr255s="Forerunner 255S"; fr255sm="Forerunner 255S Music"; vivoactive5="vívoactive 5"; descentg2="Descent G2"; epix2pro47mm="epix Pro (Gen 2) 47mm"; fenix843mm="fēnix 8 43mm"; fr265="Forerunner 265" -->

- One of these Garmin watches, with Connect IQ 5.1 or later:
  - Forerunner 255S, Forerunner 255S Music
  - fēnix 7S, fēnix 7S Pro
  - fēnix 7 Pro (also Solar, Sapphire Solar and Sapphire Dual Power), fēnix
    7 (also quatix 7 and Sapphire Dual Power), fēnix 7 Pro Solar Edition (no
    Wi-Fi), fēnix 8 Solar 47mm, fēnix 9 Pro Solar 47mm, Forerunner 955 (also
    955 Solar), Forerunner 255, Forerunner 255 Music
  - fēnix 7X (also tactix 7, quatix 7X Solar and Enduro 2), fēnix 7X Pro,
    fēnix 7X Pro Solar Edition (no Wi-Fi), fēnix 8 Solar 51mm (also tactix 8
    Solar 51mm), fēnix 9 Pro Solar 51mm, Enduro 3
  - epix Pro (Gen 2) 42mm, MARQ (Gen 2) (also Athlete, Adventurer, Captain,
    Golfer, Carbon Edition and Commander Carbon Edition), MARQ (Gen 2)
    Aviator, Descent Mk3 43mm (also Mk3i 43mm), Descent G2, Venu 3S,
    vívoactive 5, vívoactive 6, Venu 4 41mm
  - epix Pro (Gen 2) 47mm (also quatix 7 Pro), fēnix 8 43mm, Forerunner 265
  - fēnix 8 47mm and 51mm (also tactix 8 and quatix 8), fēnix 8 Pro 47mm and
    51mm (also MicroLED and quatix 8 Pro), fēnix 9 47mm and 51mm, fēnix 9
    Pro 47mm, Forerunner 965, Forerunner 970, D2 Mach 2, D2 Mach 2 Pro, epix
    Pro (Gen 2) 51mm (also D2 Mach 1 Pro and tactix 7 AMOLED Edition),
    Descent Mk3i 51mm, Venu 3, Venu 4 45mm (also D2 Air X15)
  - Venu X1
<!-- devicelists end -->
- The map in Find my car needs a watch with onboard maps; on the others Find
  my car shows the address, distance and bearing
- A Škoda with connected services active
- The MyŠkoda app, version 8.16 or later, to create an API key
  (https://go.skoda.eu/api-keys)
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

The same rule governs the watch side, with one deliberate softening. 21 device
ids are in the manifest; only the fēnix 7 Pro has been worn by anyone here. The
other 20 are claimed on the strength of checked facts rather than a hunch: each
is built locally with `tools/ciq verify`, with warnings fatal and the size
checked against that watch's memory budget from its own compiler.json, and the
unit tests run on one watch per screen family and input profile. The APIs the
app requires are checked in each watch's own api.debug.xml; the map is optional
and left out at build time where a watch has no MapView implementation. Every
screen is checked per watch on the devices design page
(`docs/design/vozidlo-devices.html`).

A green build is still not evidence of support, which is the lesson the glance
crash taught and the reason the Forerunner 255 was kept out until the map could
be left out of its build. `app/manifest.xml` carries the per-device reasoning.

The description states the unlock limitation twice, once in the summary list and
once under its own heading. That is deliberate. It costs a few installs and saves
a stream of one-star reviews from people who expected it.

Review takes about 72 hours. An upload signed with a different developer key than
the previous one is rejected, so `app/developer_key.der` needs a backup that
survives losing this machine.
