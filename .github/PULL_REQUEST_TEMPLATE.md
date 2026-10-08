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
     docs/decisions.md for two bugs that compiled cleanly and crashed. -->

- [ ] `tools/ciq build --all`: clean, no warnings  (CI cannot do this, see below)
- [ ] `tools/ciq test`: all tests pass  (CI cannot do this either)
- [ ] `mock/.venv/bin/python -m pytest mock/tests`: if anything under `mock/` changed
- [ ] `python3 tools/checks.py`: links, device list, no personal data
- [ ] Ran it in the simulator and looked at the screens I touched
- [ ] Screens follow docs/design/style-guide.md (fit, monochrome, labels)
- [ ] Ran it on real hardware: **which watch?**

## AI assistance

<!-- Using AI here is fine and normal; see CONTRIBUTING.md. Just say so. -->

- [ ] No AI was used
- [ ] AI-assisted: roughly what part:
- [ ] I have read the whole diff and can answer questions about it

## If this adds a device

<!-- Delete this section otherwise. The full procedure is in CONTRIBUTING.md.
     Paste the actual command output rather than ticking from memory:
     a device that builds cleanly can still be missing the implementation
     behind the API. -->

- [ ] `deviceFamily` is `round-260x260`, or the layout work is included here
- [ ] `watchApp` budget > 256 KB, `glance` budget 65,536 B, Connect IQ ≥ 5.2.0
- [ ] Non-zero counts for `Toybox_WatchUi_MapView`, `Toybox_Complications`,
      `Toybox_PersistedContent`, `Toybox_WatchUi_GlanceView` in the device's
      own `api.debug.xml`
- [ ] Five physical keys, or the input changes are included here
- [ ] Added to **both** `app/manifest.xml` and the CI matrix
- [ ] I own this watch and ran the app on it, or I say below that I did not

```
paste the compiler.json and api.debug.xml output here
```

## Anything you are unsure about

<!-- Genuinely useful. An honest "I could not test the map screen" saves more
     review time than a confident silence. -->
