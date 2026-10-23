#!/usr/bin/env bash
#
# Builds docs/design/vozidlo-devices.html, the multi-device UI plan: every screen on the fēnix 7 Pro
# today and on each supported watch (one column per group of products, generated with the device
# data), with the button and touch map per watch.
#
# The page reuses the Night Panel drawing code from tools/ui/poc/ unchanged (core and the NEW parts,
# not the OLD screens, the simulator or the poc board) and adds the parts in tools/ui/devices/.
# A change to a poc part therefore needs both pages rebuilt; CI runs `--check` for each.
#
# Usage:
#   tools/ui/build-devices.sh           build the page
#   tools/ui/build-devices.sh --check   build into a temp file, fail if it differs
#
# Needs: node (for the syntax check only). tools/ui/devices/11-devdata.js is generated from the
# SDK device files by tools/ui/devices/devdata.py, which only runs where the SDK is installed.

set -euo pipefail

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
note() { printf '%s\n' "$*"; }

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
DEV="$HERE/devices"
OUT="$ROOT/docs/design/vozidlo-devices.html"

# Order matters: poc core and NEW parts first, then the device parts (the generated device data before the
# columns built from it), board and boot last.
JS=(poc/10-core.js poc/30-new-home.js poc/31-new-status.js poc/32-new-other.js
    devices/11-devdata.js devices/10-profiles.js devices/20-render.js devices/30-native.js
    devices/40-screens.js devices/45-input.js devices/50-board.js devices/90-boot.js)

command -v node >/dev/null || die "node not found; it is needed for the syntax check."

for f in "${JS[@]}"; do
  node --check "$HERE/$f" || die "syntax error in tools/ui/$f"
done

# Same rule as build.sh: one IIFE per part, no top-level name twice once the parts share a <script>.
dups=$(cd "$HERE" && grep -hoE '^(const|let|var|function|class) [A-Za-z_$][A-Za-z0-9_$]*' "${JS[@]}" \
  | awk '{print $2}' | sort | uniq -d)
[[ -z "$dups" ]] || die "duplicate top-level names across parts: $dups"

build() {
  printf '<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
  printf '<meta name="viewport" content="width=device-width, initial-scale=1">\n</head>\n<body>\n'
  cat "$DEV/00-head.html"
  (cd "$HERE" && cat "${JS[@]}")
  cat "$DEV/99-tail.html"
  printf '</body>\n</html>\n'
}

if [[ "${1:-}" == "--check" ]]; then
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  build > "$tmp"
  cmp -s "$tmp" "$OUT" || die "docs/design/vozidlo-devices.html is out of date with tools/ui/devices/ or tools/ui/poc/; run tools/ui/build-devices.sh"
  note "docs/design/vozidlo-devices.html matches tools/ui/devices/ and tools/ui/poc/"
else
  build > "$OUT"
  note "built docs/design/vozidlo-devices.html ($(wc -c < "$OUT") bytes)"
fi
