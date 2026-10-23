# UI design tools

The Night Panel design reference and the checks on it. How and when to use
them is in [the style guide, section 11](../../docs/design/style-guide.md#11-tools).

| | |
|---|---|
| [poc/](poc) | Sources of `docs/design/vozidlo-poc.html`, one file per area, plus `style-examples.js` for the guide's images |
| [build.sh](build.sh) | Rebuilds the page from `poc/`; `--check` fails when they differ (CI) |
| [fitcheck.mjs](fitcheck.mjs) | Checks every new render against the round screen and the style guide (CI) |
| `fitcheck.mjs --devices [id]` | The same rules for the devices page: every product in the manifest with its column's layout and its own fonts, against its own outline (circle or the X1's rounded rectangle), at font size 1 and 1.4 (watches without MENU) and in monochrome (CI) |
| [render-style.sh](render-style.sh) | Redraws `docs/design/style/*.png` (needs Chrome or Chromium and Pillow) |
| [devices/](devices) | Sources of `docs/design/vozidlo-devices.html`: every screen on the fēnix 7 Pro today and on each supported watch (one column per group of products), with its button and touch map |
| [build-devices.sh](build-devices.sh) | Rebuilds the devices page from the poc parts plus `devices/`; `--check` fails when they differ (CI) |
| [devices/devdata.py](devices/devdata.py) | Regenerates `devices/11-devdata.js` for every product in `app/manifest.xml`, plus the page's columns (which products share one, which are shown by default): display, input profile, API counts, memory budgets, glance, and font metrics from the Garmin bitmap (`.cft`) and TrueType fonts; checks the fēnix 7 Pro against the poc's FM table. `--check` fails when the file is stale (needs the SDK and fontTools) |
| [devices/shoot.sh](devices/shoot.sh) | Opens the devices page headless with every column (`?all=1`) and checks it boots without script errors, every hooked poc name exists and the self-test passes; optional screenshot |

The drawing code is a JavaScript port of the app's Connect IQ calls, with the
watch's own font widths. It tests the design, not the Monkey C: the app's own
tests run with `tools/ciq test`.
