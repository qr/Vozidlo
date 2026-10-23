# Releasing

How a version goes from `main` to the Connect IQ Store. The store is the only
place a release exists: there is no other distribution, and the CHANGELOG's
versions are the store's versions.

Releasing needs what only the maintainer has: the signing key
(`app/developer_key.der`) and the store listing in the Garmin developer
dashboard. Everything else is in this repository.

## 1. Before you package

- [ ] **Everything is merged to `main`**, and you release from `main`.
- [ ] **`tools/ciq verify` is green on that exact commit**, with a clean working
  tree: the summary must not say "dirty". It builds every product with
  warnings fatal and within its memory budget, and runs the unit tests on the
  verify devices ([CONTRIBUTING.md](../CONTRIBUTING.md)).
- [ ] **The CHANGELOG has the version and today's date** in its heading
  (`## 1.3.0: 2026-10-23`), and its entries say what changed for users. The
  date is the day you upload.
- [ ] **The generated lists are current**: `python3 tools/checks.py` passes,
  which includes `tools/devicelists.py --check`. The store listing's
  requirements come from there.
- [ ] **The manifest carries the production app id**
  (`96a4e892-508e-4772-8a91-2c464b118264`). `tools/ciq package --beta` swaps
  in the beta id and puts it back, even on failure; `git diff app/manifest.xml`
  showing nothing confirms it.
- [ ] **You have the signing key that signed the previous upload.** Garmin
  rejects an upload signed with a different key, so a lost key means a lost
  listing ([INSTALL.md](../INSTALL.md)). Keep a backup outside this machine.

## 2. Try it as a beta (optional)

A beta is private to your Garmin account, needs no review, and can be replaced
as often as you like. [INSTALL.md](../INSTALL.md) has the steps:

```bash
tools/ciq package --beta        # writes app/bin/vozidlo-beta.iq
```

Upload it over your beta entry and run it on a real watch. Anything the
simulator cannot show (the real panel, a real car, the phone in between) is
only seen this way.

## 3. Package and upload

```bash
tools/ciq package               # writes app/bin/vozidlo.iq, every product
```

In the developer dashboard (<https://apps.garmin.com/developer/dashboard>),
upload `app/bin/vozidlo.iq` as a new version of the existing app, not as a new
app and without the "Beta App" box:

- **Version**: the CHANGELOG's version. The manifest has no version number, so
  the one entered here is the one users see.
- **What's new**: a short summary of the CHANGELOG entry.
- **Listing**: [store-listing.md](store-listing.md) is the source; copy any
  changed text from there, including the requirements (the supported watches,
  the Connect IQ version) when watches were added.
- **Screenshots**: `store-assets/`, when a screen they show has changed.

Then wait for the review. 1.2.0 was uploaded on 2026-10-08 and published on
2026-10-23; until then the store keeps the previous version.

## 4. Tag

Tag the commit you packaged, with the version, and push the tag:

```bash
git tag v1.3.0
git push origin v1.3.0
```

Only versions that were uploaded get a tag; a version folded into a later one
(1.1.0 to 1.1.6, which went out as part of 1.2.0) keeps "unreleased" in the
CHANGELOG and gets none.

## 5. When the store publishes it

- [ ] Open the listing and check the version, the "What's new" text and the
  supported watches.
- [ ] Install it from the store on your own watch, over the beta if you had
  one.
- [ ] Anything that waited for the listing, such as a post linking to it, can
  go out now.
