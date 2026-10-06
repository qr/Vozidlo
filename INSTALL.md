# Installing it on a watch

There is no public Connect IQ Store listing. To put this on a watch you build it
yourself and upload it as your own **beta app**, which takes about ten minutes
and needs a free Garmin developer account.

That sounds like a detour and is not: **app settings only reach a watch through
the store.** A sideloaded app has no entry in Garmin Connect, so there is
nowhere to type an API key or a VIN, and without those this app can show you
nothing but its onboarding screen. Garmin's own answer is a beta app: it stages
the real thing in production, settings and all, without publishing it:

> Connect IQ beta apps allows developers to test app settings and Garmin Connect
> integration in production without releasing the app. [...] URLs to the beta
> will not be visible outside of your account.

So your build stays private to your own Garmin account, and you can replace it
as often as you like with no review.

## Before you start

- A supported watch, see the table in [README.md](README.md). If yours is not
  there, [docs/adding-a-watch.md](docs/adding-a-watch.md) is the guide for
  changing that.
- A Garmin account, for the developer dashboard and the SDK Manager.
- The toolchain set up, see [CONTRIBUTING.md](CONTRIBUTING.md#setting-up).
- A Škoda with connected services active, and the MyŠkoda app (8.16 or later).

## 1. Build a beta package

```bash
tools/ciq package --beta        # writes app/bin/vozidlo-beta.iq
```

The first run generates your own beta app id into `app/beta-app-id.txt`. That
file is gitignored and is yours alone: a beta needs an application id different
from the production one in `app/manifest.xml` so the two can coexist in the
store. The build swaps it in, compiles, and puts the production id back, so
there is nothing to remember to undo.

It also generates `app/developer_key.der` if you have none. **Back that file
up.** Garmin rejects an upload signed with a different key than the previous
one, so losing it means losing the ability to update your own listing.

## 2. Upload it

Go to <https://apps.garmin.com/developer/dashboard>, upload the `.iq`, and tick
**Beta App**. Fill in a title and description: nobody else will see them, so
they can be anything.

The dashboard then shows a link to your beta. It is private to your account and
store search will not find it, so that link is the only way in.

## 3. Install it

Open your beta link **on the phone**. It hands off to the Connect IQ mobile app,
which is where the Install button lives.

## 4. Configure it

Create an API key in the MyŠkoda app (version 8.16 or later), via
<https://go.skoda.eu/api-keys>. Select the vehicle the key may access when you
create it. Keys last roughly 180 days and there is no renewal.

Then open the app's settings in Garmin Connect and fill in:

| Setting | |
|---|---|
| **API key** | The key you just created |
| **VIN** | Exactly 17 characters |
| **Temperature unit** | Optional; defaults to the watch's own setting |
| **S-PIN** | Optional. Only needed for the auxiliary heater, which many models do not have. It is stored unencrypted, see [SECURITY.md](SECURITY.md) |

Open the app, and keep your phone with you: every request travels over Bluetooth
through Garmin Connect, so out of range means no data.

## Updating

```bash
tools/ciq package --beta
```

Upload the new `.iq` over the same beta entry. No review, no waiting.

## Sideloading, and why it is only half useful

Sideloading shows you real screens on the real panel, which is genuinely worth
doing: the simulator's contrast is far more forgiving than a memory-in-pixel
display outdoors. It cannot do anything that needs a key, for the reason at the
top of this page.

```bash
tools/ciq build                       # writes app/bin/vozidlo.prg
```

Connect the watch by USB; it appears as an MTP device. On Linux you may need the
backend:

```bash
gio mount -li | grep -i garmin        # check it is seen
sudo apt install gvfs-backends        # if it is not
```

Copy the `.prg` into the watch's `GARMIN/APPS/` directory and unplug. The app
appears in the activity list.

## Reaching it quickly

Hold MENU, go to Activities & Apps, select the app, and choose **Set as
Favourite**. It then sits at the top of the list you reach by pressing START,
about two presses from the watch face.

That is the shortest route the platform allows. The Controls menu and the
press-and-hold hot keys are closed to third-party apps, verified on hardware,
not assumed, and no app can offer you better.

## What to expect once it runs

**The data is not live.** It is whatever the car last uploaded. Sections that
were 12 minutes old sitting beside one 17 hours old have been measured in the
same response, which is why every section shows its own age. A refresh that
changes nothing is normal.

**Twenty requests per hour, per vehicle**, shared with anything else you run
against the same car. This app never polls, so you spend requests only when you
ask. A command costs one, and checking whether it worked costs another.

**A command reports "sent", not "succeeded".** The API is fire-and-forget.

**It cannot lock or unlock the car.** The API has no endpoint for it.

## When something goes wrong

A crash writes `CIQ_LOG.YAML` to `GARMIN/APPS/LOGS` on the watch. Pull it over
USB; it carries the error and a stack trace with file and line, which usually
identifies the problem outright. Note its `ConnectIQ-Version` field is the SDK
the app was built with, not your firmware version: easy to misread.

`System.println()` output only reaches the watch if you first create
`GARMIN/APPS/LOGS/VOZIDLO.TXT` by hand. Logs rotate at 5 KB.

**Check that log for your VIN before pasting it into an issue.**
