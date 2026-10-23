#!/usr/bin/env python3
"""Writes tools/ui/devices/11-devdata.js: the device facts the multi-device UI plan draws with.

One entry per product in app/manifest.xml, in manifest order, one product per line (so a new watch is a
one-line diff), plus the devices page columns (DEV_COLUMNS, see columns() below). Reads the SDK Manager's device and font
files on this machine (~/.Garmin/ConnectIQ):
  Devices/<id>/compiler.json      name, family, display type, colour depth, memory budgets, launcher icon,
                                  lowest Connect IQ version over the part numbers
  Devices/<id>/simulator.json     display, ppi, touch, keys, fonts (fontSet "ww"), glance area, action menu hint
  Devices/<id>/<id>.api.debug.xml which APIs the device implements (MapView and a few others, by entry count)
  Fonts/*.cft                     Garmin bitmap fonts (fēnix 7 family, FR255): height, ascent, advances
  Fonts/*.ttf                     TrueType fonts (fēnix 8/9, FR955, Venu, vívoactive): needs fontTools
  Sdks/<current>                  the SDK version, from the directory name in current-sdk.cfg

Only numbers are written: no font file and no Garmin artwork is copied into the repo.

.cft layout (big-endian): u16 @0 header length L, u16 @0x16 height, u16 @0x18 ascent, u32 @L+0x0c number of
ranges n, then n ranges of (u32 first, u32 last, u32 glyph index) from L+0x10, then 4-byte glyph records at
L+0x10 + 12n. The glyph of character c is glyph index + (c - first). Header lengths 0x24 (fēnix 7 family,
Forerunner 255, 255S, vívoactive 5) and 0x28 (epix Pro, MARQ, Descent Mk3 and G2, one FR255 font) are
known. In both the record's low byte is the advance (at most 159 px, in a 177 px font) and the bits above
it the bitmap offset; in 0x24 files a set 0x8000 bit marks a glyph that has a bitmap. In a file larger than
64 KB the offset spills into bits 8 to 14, which is why taking the advance as `& 0x7FFF` gave the vívoactive
5's "…" 279 px. A character the font does not have is left out of that font's character list (the page then
measures it with the browser). Up to 2026-10-23 only 0x24 was read, and with `& 0x7FFF`.

TrueType metrics. The app lays out with Graphics.getFontHeight(), so the heights must be the simulator's
live values. No single rounding rule reproduces both those and the metrics simulator.json lists for some
fonts, so:
  em px   = size (pt) * ppi / 72
  height  = round(em * (hhea.ascent + |hhea.descent|) / upm)     matches every live getFontHeight() value
  ascent  = ceil(em * hhea.ascent / upm)                          matches the listed ascents but one
  advance = round(em * hmtx.advance / upm)
and where simulator.json lists ascent and height itself, those win (the simulator returns them; e.g. the
vívoactive 6 numberMild is 97 where the formula gives 96). The script fails when a listed value differs
from the formula by more than 1 px, and when a height differs from LIVE_HEIGHTS: getFontHeight() measured
in the simulator on 2026-10-10 (xtiny, tiny, small, medium, numberMild, numberMedium).

Self-check: the fēnix 7 Pro's .cft metrics must equal the poc's FM table (tools/ui/poc/10-core.js), which
the design reference draws with.

Usage:
  python3 tools/ui/devices/devdata.py           write 11-devdata.js
  python3 tools/ui/devices/devdata.py --check   fail if 11-devdata.js differs from a fresh run
"""
import json
import math
import os
import re
import struct
import sys
from pathlib import Path

try:
    from fontTools.ttLib import TTFont
except ImportError:  # pragma: no cover
    sys.exit("ERROR: fontTools is needed (pip install fonttools)")

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent.parent
OUT = HERE / "11-devdata.js"
MANIFEST = ROOT / "app" / "manifest.xml"
POC_CORE = HERE.parent / "poc" / "10-core.js"
CIQ = Path(os.environ.get("CIQ_HOME", Path.home() / ".Garmin" / "ConnectIQ"))

CIQ_TOOL = ROOT / "tools" / "ciq"
# simulator.json font name -> poc FM key
FONT_KEYS = {"xtiny": "xtiny", "tiny": "tiny", "small": "small", "medium": "medium", "large": "large",
             "numberMild": "numMild", "numberMedium": "numMed", "numberHot": "numHot"}
# Same character sets as the poc's FM table, so every string the screens use is measured.
TEXT_CHARS = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~°—…Š·"
NUMBER_CHARS = " #%+-./0123456789:°"
# api.debug.xml entries counted per device (0 = not implemented). Modules and classes by their Toybox_ symbol
# prefix (the rule docs/adding-a-watch.md section 3 uses: Toybox_WatchUi_MapView is 9 where MapView exists, else
# 0); methods by their quoted symbol/name attributes, so mentions in other entries' documentation do not count.
API_TERMS = {"MapView": "Toybox_WatchUi_MapView", "Complications": "Toybox_Complications",
             "PersistedContent": "Toybox_PersistedContent", "GlanceView": "Toybox_WatchUi_GlanceView",
             "setActionMenuIndicator": '"setActionMenuIndicator"', "saveWaypoint": '"saveWaypoint"'}
LISTED_TOLERANCE = 1   # px between the formula and a metric simulator.json lists (Roboto-Black ascent, Yantramanav heights)
# Graphics.getFontHeight() in the simulator (SDK 9.2.0), per device: xtiny, tiny, small, medium, numMild, numMed.
LIVE_HEIGHTS = {
    "fenix7pro": [19, 29, 32, 37, 60, 74], "fenix7s": [19, 26, 29, 34, 55, 67], "fenix7xpro": [19, 31, 34, 40, 64, 79],
    "fr255": [19, 29, 32, 37, 45, 53], "venu3s": [32, 40, 47, 53, 77, 100], "venu3": [35, 45, 50, 58, 89, 116],
    "vivoactive6": [30, 35, 45, 53, 97, 130], "venu445mm": [37, 47, 53, 61, 112, 152], "venux1": [37, 47, 53, 61, 112, 152],
    "fr255s": [19, 23, 26, 32, 40, 53], "vivoactive5": [32, 41, 48, 54, 74, 99], "descentg2": [29, 39, 44, 51, 82, 102],
    "fr265": [34, 43, 50, 58, 95, 117], "epix2pro47mm": [31, 42, 47, 55, 88, 109], "fenix843mm": [34, 43, 50, 58, 103, 141],
}
LIVE_KEYS = ["xtiny", "tiny", "small", "medium", "numMild", "numMed"]


def products():
    return re.findall(r'<iq:product id="([^"]+)"', MANIFEST.read_text())


def verify_devices():
    m = re.search(r"^VERIFY_DEVICES=\(([^)]*)\)", CIQ_TOOL.read_text(), re.M)
    if not m:
        sys.exit("ERROR: tools/ciq has no VERIFY_DEVICES=(...) line")
    return m.group(1).split()


def sdk_version():
    cfg = CIQ / "current-sdk.cfg"
    m = re.search(r"connectiq-sdk-[a-z]+-(\d+\.\d+\.\d+)", cfg.read_text() if cfg.exists() else "")
    if not m:
        sys.exit("ERROR: cannot read the SDK version from ~/.Garmin/ConnectIQ/current-sdk.cfg")
    return m.group(1)


class Cft:
    """Garmin bitmap font: one fixed pixel size."""

    def __init__(self, name):
        b = (CIQ / "Fonts" / f"{name}.cft").read_bytes()
        self.hl = struct.unpack(">H", b[0:2])[0]
        if self.hl not in (0x24, 0x28):
            sys.exit(f"ERROR: {name}.cft has a header of {self.hl:#x} bytes; only 0x24 and 0x28 are known")
        self.h, self.asc = struct.unpack(">HH", b[0x16:0x1A])
        n = struct.unpack(">I", b[self.hl + 0x0C:self.hl + 0x10])[0]
        start = self.hl + 0x10
        self.ranges = [struct.unpack(">III", b[start + 12 * i:start + 12 + 12 * i]) for i in range(n)]
        self.glyphs = start + 12 * n
        self.b = b

    def advance(self, c):
        for first, last, gi in self.ranges:
            if first <= c <= last:
                o = self.glyphs + 4 * (gi + c - first)
                return self.b[o + 3]
        return None

    def metrics(self, chars):
        w, a = "", []
        for ch in chars:
            adv = self.advance(ord(ch))
            if adv is not None:
                w += ch
                a.append(adv)
        return {"h": self.h, "asc": self.asc, "em": None, "w": w, "a": a, "kind": "cft", "weight": 700}


class Face:
    """TrueType face, sized per device from point size and ppi."""

    def __init__(self, name):
        f = TTFont(CIQ / "Fonts" / f"{name}.ttf")
        self.upm = f["head"].unitsPerEm
        self.asc = f["hhea"].ascent
        self.desc = abs(f["hhea"].descent)
        self.cmap = f.getBestCmap()
        self.hmtx = f["hmtx"].metrics
        self.weight = f["OS/2"].usWeightClass

    def metrics(self, size, ppi, chars):
        em = size * ppi / 72
        asc = math.ceil(em * self.asc / self.upm)
        h = round(em * (self.asc + self.desc) / self.upm)
        adv = []
        for ch in chars:
            g = self.cmap.get(ord(ch))
            adv.append(round(em * self.hmtx[g][0] / self.upm) if g else round(em * 0.35))
        return {"h": h, "asc": asc, "em": round(em, 2), "w": chars, "a": adv, "kind": "ttf", "weight": self.weight}


CACHE = {}


def font(f, ppi, chars):
    name, kind = f["filename"], f.get("type")
    if kind == "ttf":
        if ppi is None:
            sys.exit(f"ERROR: TrueType font {name} on a device without ppi")
        if name not in CACHE:
            CACHE[name] = Face(name)
        return CACHE[name].metrics(f["size"], ppi, chars)
    if name not in CACHE:
        CACHE[name] = Cft(name)
    return CACHE[name].metrics(chars)


def rect(d):
    return [d["x"], d["y"], d["width"], d["height"]]


def profile(touch, keys):
    ids = {k["id"] for k in keys}
    if not touch:
        return "A0"
    if {"up", "down"} <= ids:
        return "A"
    if any(k["behavior"] == "onMenu" and k["hold"] for k in keys):
        return "B"
    return "C"


def device(dev):
    base = CIQ / "Devices" / dev
    sim = json.loads((base / "simulator.json").read_text())
    comp = json.loads((base / "compiler.json").read_text())
    api = (base / f"{dev}.api.debug.xml").read_text(errors="replace")
    disp = sim["display"]
    w, h = disp["location"]["width"], disp["location"]["height"]
    ox, oy = disp["location"]["x"], disp["location"]["y"]
    ppi = sim.get("ppi")
    ww = next(fs for fs in sim["fonts"] if fs["fontSet"] == "ww")
    fonts, checked = {}, 0
    for f in ww["fonts"]:
        key = FONT_KEYS.get(f["name"])
        if not key:
            continue
        m = font(f, ppi, NUMBER_CHARS if key.startswith("num") else TEXT_CHARS)
        if "ascent" in f and m["kind"] == "ttf":
            if abs(m["h"] - f["height"]) > LISTED_TOLERANCE or abs(m["asc"] - f["ascent"]) > LISTED_TOLERANCE:
                sys.exit(f"ERROR: {dev} {f['name']}: formula gives {m['asc']}/{m['h']}, simulator says {f['ascent']}/{f['height']}")
            m["asc"], m["h"] = f["ascent"], f["height"]
            checked += 1
        m["file"] = f["filename"]
        fonts[key] = {k: m[k] for k in ("h", "asc", "em", "w", "a", "file", "kind", "weight")}
    keys = []
    cx, cy = ox + w / 2, oy + h / 2
    for k in sim["keys"]:
        L = k["location"]
        kx, ky = L["x"] + L["width"] / 2, L["y"] + L["height"] / 2
        keys.append({"id": k["id"], "behavior": k["behavior"], "hold": bool(k.get("isHold")),
                     "deg": round(math.degrees(math.atan2(ky - cy, kx - cx))), "y": round(ky - oy)})
    touch = bool(disp.get("isTouch"))
    am = sim["layouts"][0].get("actionMenu", {}).get("actionMenuHint")
    glance = sim.get("glance", {})
    budget = {a["type"]: a["memoryLimit"] for a in comp.get("appTypes", [])}
    ciq = min((p["connectIQVersion"] for p in comp.get("partNumbers", [])), key=lambda v: tuple(int(x) for x in v.split(".")))
    return {
        "id": dev, "name": comp.get("displayName", dev), "family": comp.get("deviceFamily"),
        "displayType": comp.get("displayType"), "bpp": comp.get("bitsPerPixel"),
        "w": w, "h": h, "shape": disp.get("shape", "round"), "ppi": ppi, "touch": touch, "keys": keys,
        "profile": profile(touch, keys),
        "api": {k: api.count(t) for k, t in API_TERMS.items()},
        "mapView": "Toybox_WatchUi_MapView" in api,
        "budget": {"watchApp": budget.get("watchApp"), "glance": budget.get("glance")},
        "ciq": ciq,
        "glance": rect(glance["contentArea"]) if "contentArea" in glance else None,
        "actionMenuHint": rect(am) if am else None,
        "launcher": comp.get("launcherIcon", {}).get("width"), "fonts": fonts, "_checked": checked,
    }


def poc_fm():
    src = POC_CORE.read_text()
    fm = json.loads(re.search(r"^const FM = (\{.*\});$", src, re.M).group(1))
    fm.update(json.loads(re.search(r"^Object\.assign\(FM, (\{.*\})\);$", src, re.M).group(1)))
    return fm


def live_check(devs):
    for dev, heights in LIVE_HEIGHTS.items():
        if dev not in devs:
            continue
        got = [devs[dev]["fonts"][k]["h"] for k in LIVE_KEYS]
        if got != heights:
            sys.exit(f"ERROR: {dev} font heights {got} differ from the simulator's getFontHeight() {heights}")


def self_check(devs):
    fm, mine = poc_fm(), devs.get("fenix7pro")
    if not mine:
        sys.exit("ERROR: fenix7pro is not in the product list")
    for key, ref in fm.items():
        got = mine["fonts"].get(key)
        if not got or (got["h"], got["asc"], got["w"], got["a"]) != (ref["h"], ref["asc"], ref["w"], ref["a"]):
            sys.exit(f"ERROR: fenix7pro {key}: the .cft metrics differ from the poc's FM table in tools/ui/poc/10-core.js")


PROFILE_ORDER = ["A", "A0", "B", "C"]


def columns(devs, verify):
    """The devices page columns. Products share a column when they share screen family, input profile,
    MapView and font technology (bitmap .cft or TrueType): close enough to share one design, and
    fitcheck --devices still checks every product on its own. A column is drawn as its product in
    VERIFY_DEVICES (the one the unit tests run on), else as its first product in manifest order.
    Order: the primary product's column first, then MIP before AMOLED, round before rectangle, by
    width, by profile, bitmap fonts before TrueType. Shown by default ("on"): the primary's column, per
    input profile the column with the most products, then per screen family still missing the one
    with the most products (ties: the first in this order)."""
    groups = {}
    for pid, d in devs.items():
        key = (d["family"], d["profile"], d["mapView"], d["fonts"]["medium"]["kind"])
        groups.setdefault(key, []).append(pid)
    primary = next(iter(devs))
    cols = []
    for (family, prof, has_map, kind), covers in groups.items():
        dev = next((p for p in covers if p in verify), covers[0])
        d = devs[dev]
        cols.append({"id": dev, "dev": dev, "input": prof, "covers": covers,
                     "_sort": (primary not in covers, d["displayType"] != "mip", d["shape"] != "round", d["w"], d["h"],
                               PROFILE_ORDER.index(prof), kind != "cft")})
    cols.sort(key=lambda c: c.pop("_sort"))
    on = {0}
    for attr in ("input", "family"):
        seen = {devs[cols[i]["dev"]]["family"] if attr == "family" else cols[i]["input"] for i in on}
        best = {}
        for i, c in enumerate(cols):
            v = devs[c["dev"]]["family"] if attr == "family" else c["input"]
            if v not in seen and (v not in best or len(c["covers"]) > len(cols[best[v]]["covers"])):
                best[v] = i
        on |= set(best.values())
    for i, c in enumerate(cols):
        c["on"] = i in on
    return cols


def build():
    devs = {d: device(d) for d in products()}
    if sum(d.pop("_checked") for d in devs.values()) == 0:
        sys.exit("ERROR: no explicit font metrics to check the TrueType formula against")
    self_check(devs)
    live_check(devs)
    cols = columns(devs, verify_devices())
    line = lambda v: json.dumps(v, ensure_ascii=False, separators=(",", ":"))
    body = "{\n" + ",\n".join(f"{line(k)}:{line(v)}" for k, v in devs.items()) + "\n}"
    colbody = "[\n" + ",\n".join(line(c) for c in cols) + "\n]"
    meta = json.dumps({"sdk": sdk_version()}, separators=(",", ":"))
    return ("// GENERATED by tools/ui/devices/devdata.py from the SDK device and font files; do not edit.\n"
            "// Per product (manifest order): display, input (keys with their angle from the display centre in canvas\n"
            "// degrees, touch, input profile), API counts, memory budgets, glance area, action menu hint, launcher icon\n"
            "// and font metrics in device px (h, asc, advances; em for TrueType). The fēnix 7 Pro equals the poc's FM.\n"
            f"const DEV_DATA = {body};\n"
            "// The devices page columns: which products share a design and which product each is drawn as (devdata.py columns()).\n"
            f"const DEV_COLUMNS = {colbody};\n"
            f"const DEV_META = {meta};\n")


def main():
    js = build()
    if "--check" in sys.argv[1:]:
        if not OUT.exists() or OUT.read_text() != js:
            sys.exit("ERROR: tools/ui/devices/11-devdata.js is out of date; run tools/ui/devices/devdata.py")
        print("tools/ui/devices/11-devdata.js matches the SDK files")
    else:
        OUT.write_text(js)
        print(f"wrote {OUT.relative_to(ROOT)} ({len(js)} bytes)")


if __name__ == "__main__":
    main()
