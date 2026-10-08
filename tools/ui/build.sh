#!/usr/bin/env bash
#
# Builds docs/design/vozidlo-poc.html, the Night Panel design reference, from
# the parts in tools/ui/poc/.
#
# Why parts: the page is about 190 KB of drawing code written by several people
# at once; one file per area keeps changes reviewable. The page itself is
# committed so it opens without a build step, and `--check` keeps the two from
# drifting apart (CI runs it).
#
# Usage:
#   tools/ui/build.sh           build the page
#   tools/ui/build.sh --check   build into a temp file, fail if it differs
#
# Needs: node (for the syntax check only).

set -euo pipefail

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
note() { printf '%s\n' "$*"; }

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
POC="$HERE/poc"
OUT="$ROOT/docs/design/vozidlo-poc.html"

# Order matters: core first, the board and boot last. style-examples.js is not
# part of the page; render-style.sh adds it.
JS=(10-core.js 20-old.js 30-new-home.js 31-new-status.js 32-new-other.js 40-sim.js 50-board.js 90-boot.js)

command -v node >/dev/null || die "node not found; it is needed for the syntax check."

for f in "${JS[@]}"; do
  node --check "$POC/$f" || die "syntax error in tools/ui/poc/$f"
done

# Every part except the core is one IIFE exposing one namespace; a second
# top-level name with the same spelling would silently shadow the first once
# the parts share one <script>.
dups=$(cd "$POC" && grep -hoE '^(const|let|var|function|class) [A-Za-z_$][A-Za-z0-9_$]*' "${JS[@]}" \
  | awk '{print $2}' | sort | uniq -d)
[[ -z "$dups" ]] || die "duplicate top-level names across parts: $dups"

build() {
  printf '<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
  printf '<meta name="viewport" content="width=device-width, initial-scale=1">\n</head>\n<body>\n'
  cat "$POC/00-head.html"
  (cd "$POC" && cat "${JS[@]}")
  cat "$POC/99-tail.html"
  printf '</body>\n</html>\n'
}

if [[ "${1:-}" == "--check" ]]; then
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  build > "$tmp"
  cmp -s "$tmp" "$OUT" || die "docs/design/vozidlo-poc.html is out of date with tools/ui/poc/; run tools/ui/build.sh"
  note "docs/design/vozidlo-poc.html matches tools/ui/poc/"
else
  build > "$OUT"
  note "built docs/design/vozidlo-poc.html ($(wc -c < "$OUT") bytes)"
fi
