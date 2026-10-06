# Privacy policy

For **Vozidlo**, a Connect IQ app for Garmin watches that talks to Škoda vehicles.

Last updated: 7 September 2026.

This has to be published at a public URL before the app can be submitted, because
Garmin's own privacy policy describes Garmin's practices and not ours.

## The short version

I do not run a server. There is nothing for me to collect, because nothing
reaches me. Your API key, your VIN and your vehicle data stay on your watch and
travel only between your watch, your phone, and Škoda.

## What the app stores on your watch

- **Your Škoda API key**, so it can make requests on your behalf
- **Your VIN**, to say which vehicle those requests are about
- **Your S-PIN**, only if you enter one, and only used for the auxiliary heater
- **A cached copy of your vehicle's last known state**, including its parking
  position, so the app can show something without a network request
- **Small amounts of app state**, such as your tile order and a count of requests
  made in the current hour

All of it lives in Connect IQ's own storage on the watch. Connect IQ stores app
settings unencrypted, so anyone with physical access to your unlocked watch could
in principle read the key and the S-PIN. That is a property of the platform, not
a choice this app makes, but you should know it. The app has a "Clear stored
data" action that removes everything listed above.

## Where your data goes

Requests go from the watch, over Bluetooth, to the Garmin Connect app on your
phone, which performs the HTTPS call to Škoda's API. That is how Connect IQ
works; a watch app cannot make a network connection by itself.

So three parties see your requests: your watch, your phone's Garmin Connect app,
and Škoda. What Garmin and Škoda do with that is covered by their own policies,
not this one.

Nothing is sent anywhere else. There is no analytics, no crash reporting beyond
what Garmin collects for any Connect IQ app, no advertising, and no third-party
service of my own.

## Location

The app asks for the Positioning permission so it can tell you how far away your
car is and in which direction. Your position is read while the "find my car"
screen is open and is used only to draw that distance and bearing. It is not
stored and not transmitted. Position updates stop when you leave the screen.

Your car's parking position comes from Škoda, not from your watch, and is cached
on the watch so you can still see it without a connection.

## Your rights under GDPR

Since I hold no data about you, most of the usual requests have nothing to act
on. Concretely:

- **Access and portability**: everything the app knows is on your watch. There is
  no copy of it anywhere I control.
- **Erasure**: use "Clear stored data" in the app, or uninstall it. Both remove
  everything.
- **Rectification and objection**: there is no processing on my side to correct
  or object to.

For the data Škoda holds about your vehicle, contact Škoda. For data Garmin holds
about your device and account, contact Garmin. I cannot act on either.

## Children

The app is not directed at children under 13 and has no features aimed at them.

## Changes

If this policy changes, the updated version is published at the same URL with a
new date at the top. Material changes will also be noted in the app's store
listing.

## Contact

Questions about this policy go to the contact address on the app's Connect IQ
Store page.
