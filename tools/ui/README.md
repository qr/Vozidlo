# UI design tools

The Night Panel design reference and the checks on it. How and when to use
them is in [the style guide, section 11](../../docs/design/style-guide.md#11-tools).

| | |
|---|---|
| [poc/](poc) | Sources of `docs/design/vozidlo-poc.html`, one file per area, plus `style-examples.js` for the guide's images |
| [build.sh](build.sh) | Rebuilds the page from `poc/`; `--check` fails when they differ (CI) |
| [fitcheck.mjs](fitcheck.mjs) | Checks every new render against the round screen and the style guide (CI) |
| [render-style.sh](render-style.sh) | Redraws `docs/design/style/*.png` (needs Chrome or Chromium and Pillow) |

The drawing code is a JavaScript port of the app's Connect IQ calls, with the
watch's own font widths. It tests the design, not the Monkey C: the app's own
tests run with `tools/ciq test`.
