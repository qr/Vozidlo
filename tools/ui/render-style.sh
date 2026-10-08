#!/usr/bin/env bash
#
# Renders the example images of docs/design/style-guide.md into
# docs/design/style/*.png.
#
# Why from the design reference and not from the simulator: the images must be
# reproducible on any machine, and the simulator panel renders blank in the
# Docker setup (see the guide, section 11). The examples are drawn with the same
# code as docs/design/vozidlo-poc.html (tools/ui/poc/) plus
# tools/ui/poc/style-examples.js, which holds one function per image.
#
# Usage:
#   tools/ui/render-style.sh
#
# Needs: google-chrome or chromium (headless), python3 with Pillow.

set -euo pipefail

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
note() { printf '%s\n' "$*"; }

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
POC="$HERE/poc"
DEST="$ROOT/docs/design/style"

CHROME=""
for c in google-chrome chromium chromium-browser; do
  command -v "$c" >/dev/null && { CHROME="$c"; break; }
done
[[ -n "$CHROME" ]] || die "no google-chrome or chromium found; it renders the images headless."
python3 -c "import PIL" 2>/dev/null || die "python3 Pillow not found (pip install pillow); it writes and compresses the PNGs."

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# A minimal page: the drawing code of the design reference plus the examples.
{
  cat <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Vozidlo style guide examples</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Semi+Condensed:wght@500;600&family=Roboto:wght@700&family=Roboto+Condensed:wght@700&display=swap">
</head>
<body>
<div id="style-out"></div>
<script>
EOF
  (cd "$POC" && cat 10-core.js 20-old.js 30-new-home.js 31-new-status.js 32-new-other.js style-examples.js)
  cat <<'EOF'
Promise.all([document.fonts.load("700 20px Roboto"), document.fonts.load("700 20px 'Roboto Condensed'"),
  document.fonts.load("600 14px 'Barlow Semi Condensed'")])
  .catch(() => {}).finally(() => document.fonts.ready.then(() => { calibrate(); renderStyleExamples(); }));
</script>
</body>
</html>
EOF
} > "$work/render.html"

# The watch fonts come from Google Fonts, so this needs network access; the
# virtual time budget gives them time to load before the canvases are drawn.
"$CHROME" --headless=new --disable-gpu --virtual-time-budget=10000 \
  --dump-dom "file://$work/render.html" 2>/dev/null > "$work/dom.html"

mkdir -p "$DEST"
python3 - "$work/dom.html" "$DEST" <<'EOF'
import base64, html, io, json, os, re, sys
from PIL import Image

dom, dest = sys.argv[1], sys.argv[2]
m = re.search(r'<pre id="style-data" hidden="">(.*?)</pre>', open(dom, encoding="utf-8").read(), re.S)
if not m:
    sys.exit("ERROR: the render page produced no images (fonts not loaded or a script error)")
data = json.loads(html.unescape(m.group(1)))
total = 0
for name, url in sorted(data.items()):
    if not url.startswith("data:"):
        sys.exit(f"ERROR: example {name}: {url}")
    image = Image.open(io.BytesIO(base64.b64decode(url.split(",", 1)[1]))).convert("RGBA")
    # 256 colours is plenty for a 64-colour watch screen plus anti-aliased labels,
    # and keeps the whole set around 120 KB.
    path = os.path.join(dest, f"{name}.png")
    image.quantize(colors=256, method=Image.Quantize.FASTOCTREE).save(path, optimize=True)
    total += os.path.getsize(path)
print(f"wrote {len(data)} images to docs/design/style/ ({total // 1024} KB)")
EOF
