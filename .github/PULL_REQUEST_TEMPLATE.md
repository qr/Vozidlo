<!--
Nothing here is bureaucracy for its own sake. Each line is something a reviewer
would otherwise have to ask you about. Delete any section that does not apply.
-->

## What this changes

<!-- One or two sentences. What is different afterwards? -->

## Why

<!-- What problem, or which requirement (US-nnn, see docs/requirements.md)? -->

## How it was verified

<!-- Replace with what you actually ran and what you saw. "Should work" is
     not verification; a green build is not verification either, see
     docs/decisions.md for two bugs that compiled cleanly and crashed.
     CI checks that the repository is consistent; it cannot build the app,
     so the verify summary below is the only build evidence in this PR. -->

- [ ] `tools/ciq verify` exited 0, and the block it printed under "For the pull request" is pasted below (exit 2 means it did not run: not a pass). Required when anything under `app/` changed
- [ ] `python3 tools/checks.py`: links and anchors, the lists of watches, no personal data (verify runs it too)
- [ ] `mock/.venv/bin/python -m pytest mock/tests`: if anything under `mock/` changed
- [ ] Looked at every screen I touched in the simulator, on one watch per affected input profile (A five buttons, A0 the same with touch off, B Venu 3 / 3S, C vívoactive 6 / Venu 4 / Venu X1): **which watches?**
- [ ] Screens follow docs/design/style-guide.md (fit to the outline, monochrome, labels)
- [ ] Rebuilt the devices page (`tools/ui/build-devices.sh`) if anything under `tools/ui/poc/` or `tools/ui/devices/` changed
- [ ] Ran it on real hardware: **which watch, and for how long?**

```
paste the tools/ciq verify summary here
```

## AI assistance

<!-- Using AI here is fine and normal; see CONTRIBUTING.md. Just say so. -->

- [ ] No AI was used
- [ ] AI-assisted: roughly what part:
- [ ] I have read the whole diff and can answer questions about it

## If this adds a device

<!-- Delete this section otherwise. The full procedure is in
     docs/adding-a-watch.md. Paste the actual command output rather than
     ticking from memory: a device that builds cleanly can still be missing
     the implementation behind an API. -->

- [ ] `deviceFamily` is one the layouts know (docs/adding-a-watch.md, section 1), or the layout pass is included here
- [ ] `watchApp` budget at least 524,288 B, `glance` budget 65,536 B, Connect IQ 5.1.0 or later (`minApiLevel`)
- [ ] Input profile: **A / A0 / B / C**, read from `simulator.json` as in section 2, or the new profile is included here
- [ ] Non-zero counts for `Toybox_Complications`, `Toybox_PersistedContent` and `Toybox_WatchUi_GlanceView` in the device's own `api.debug.xml`; `Toybox_WatchUi_MapView`: **count**
- [ ] Added to the product list in `app/manifest.xml`
- [ ] Ran `python3 tools/ui/devices/devdata.py` and committed `tools/ui/devices/11-devdata.js` (device facts and the devices page columns)
- [ ] Ran `python3 tools/devicelists.py` (README, guide, store listing, manifest comment, jungle); a `app/resources-launcher-<size>/` folder if it asked for one
- [ ] Rebuilt the devices page (`tools/ui/build-devices.sh`) and looked at the watch's column
- [ ] Added to `VERIFY_DEVICES` in `tools/ciq` if it brings a new family, input profile or a lower Connect IQ version
- [ ] `python3 tools/checks.py` passes
- [ ] I own this watch and ran the app on it, or I say below that I did not

```
paste the compiler.json, simulator.json and api.debug.xml output here
```

## Anything you are unsure about

<!-- Genuinely useful. An honest "I could not test the map screen" saves more
     review time than a confident silence. -->
