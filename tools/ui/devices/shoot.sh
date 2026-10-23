#!/usr/bin/env bash
#
# Opens docs/design/vozidlo-devices.html headless with every watch rendered (?all=1) and checks that it
# booted without script errors, that every hooked poc name exists and that the fēnix self-test passes
# (the devices renderer draws a fēnix screen pixel-identical to the poc's own Dc). Optionally writes a
# full-page screenshot for review.
#
# Usage:
#   tools/ui/devices/shoot.sh                 check only
#   tools/ui/devices/shoot.sh out.png [W]     check and write a screenshot, W px wide (default 1800)
#
# Needs: google-chrome or chromium (headless). Google Fonts are loaded over the network, as on the page.

set -euo pipefail
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
PAGE="$ROOT/docs/design/vozidlo-devices.html"
[[ -f "$PAGE" ]] || die "build the page first: tools/ui/build-devices.sh"

CHROME=""
for c in google-chrome chromium chromium-browser; do
  command -v "$c" >/dev/null && { CHROME="$c"; break; }
done
[[ -n "$CHROME" ]] || die "no google-chrome or chromium found."

dom="$(mktemp)"; trap 'rm -f "$dom"' EXIT
"$CHROME" --headless=new --disable-gpu --virtual-time-budget=20000 --dump-dom "file://$PAGE?all=1" 2>/dev/null > "$dom"

attr() { grep -o "data-$1=\"[^\"]*\"" "$dom" | head -1 | sed -E 's/.*="([^"]*)"/\1/'; }
booted="$(attr booted)"; errors="$(attr js-errors)"; selftest="$(attr selftest)"; missing="$(attr hook-missing)"
printf 'booted=%s js-errors=%s selftest=%s hook-missing=%s\n' "${booted:-no}" "${errors:-?}" "${selftest:-?}" "${missing:-none}"
canvases=$(grep -o '<canvas' "$dom" | wc -l)
printf 'watches rendered: %s\n' "$canvases"
[[ "$booted" == "1" ]] || die "page did not boot"
[[ "$errors" == "0" ]] || die "script errors on the page: $errors"
[[ "$selftest" == "pass" ]] || die "fēnix self-test failed: $selftest"
[[ -z "$missing" ]] || die "hooked poc names missing: $missing"

if [[ -n "${1:-}" ]]; then
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --virtual-time-budget=20000 --window-size="${2:-1800},20000" \
    --screenshot="$1" "file://$PAGE?all=1" 2>/dev/null
  printf 'screenshot: %s\n' "$1"
fi
