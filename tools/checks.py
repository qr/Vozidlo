#!/usr/bin/env python3
"""Repository checks that need no Connect IQ SDK.

These are the parts of "is this repository consistent" that a machine can
answer without Garmin's toolchain, which is why they can run in CI while the
device build cannot. Run them locally the same way CI does:

    python3 tools/checks.py

Every check prints what it looked at, so a failure says what to fix rather than
only that something is wrong.
"""
from __future__ import annotations

import json
import re
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
failures: list[str] = []

# Files that necessarily contain the very strings the checks look for, and so
# would report themselves. This file holds every pattern (the privacy ones, the
# placeholder, and the stale CI phrases); test_privacy.py holds
# the same ones again; openapi.json is Škoda's document, carrying their example
# coordinates. Kept in one place because the placeholder check and the privacy
# check both need it, and one of them having its own copy is exactly how this
# list goes stale.
SELF_REFERENTIAL = {
    "tools/checks.py",
    "mock/tests/test_privacy.py",
    "mock/openapi.json",
}


def check(name: str):
    """Decorator that runs a check and records its failures."""
    def wrap(fn):
        print(f"\n== {name}")
        try:
            problems = fn() or []
        except Exception as exc:                      # a broken check is a failure
            problems = [f"the check itself raised {exc!r}"]
        for p in problems:
            print(f"   FAIL  {p}")
            failures.append(f"{name}: {p}")
        if not problems:
            print("   ok")
        return fn
    return wrap


def tracked_files() -> list[pathlib.Path]:
    """Files git would commit: tracked ones, plus untracked ones that are not
    ignored, so a new file is checked before anyone remembers to add it. Falls
    back to everything outside .git."""
    import subprocess
    try:
        out = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard"],
                             cwd=ROOT, capture_output=True, text=True, check=True).stdout.splitlines()
        return sorted({ROOT / f for f in out if (ROOT / f).is_file()})
    except Exception:
        return [p for p in ROOT.rglob("*") if p.is_file() and ".git" not in p.parts]


def manifest_products() -> list[str]:
    """Product ids in app/manifest.xml, in manifest order (the first is the
    primary that tools/ciq builds and tests by default)."""
    return re.findall(r'<iq:product\s+id="([^"]+)"',
                      (ROOT / "app/manifest.xml").read_text(encoding="utf-8"))


FENCE = re.compile(r"^\s*(```|~~~)")


def without_fences(text: str) -> str:
    """Markdown with fenced code blocks blanked out, line numbers kept.

    A heading or a link inside a code sample is an example, not part of the
    document, so neither anchors nor link checks look there.
    """
    out, fence = [], None
    for line in text.splitlines():
        m = FENCE.match(line)
        if fence:
            if m and m.group(1) == fence:
                fence = None
            out.append("")
        elif m:
            fence = m.group(1)
            out.append("")
        else:
            out.append(line)
    return "\n".join(out)


def slug(heading: str) -> str:
    """The anchor GitHub gives a heading: lowercase, tags and backticks gone,
    punctuation other than - and _ dropped, spaces to hyphens."""
    s = re.sub(r"<[^>]+>", "", heading)
    s = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", s)    # a link keeps its label
    s = s.replace("`", "").strip().lower()
    s = re.sub(r"[^\w\- ]", "", s)
    return s.replace(" ", "-")


def anchors(md: pathlib.Path, _cache: dict = {}) -> set[str]:
    """Every fragment a link into md may use: heading slugs (a repeated
    heading gets -1, -2, as on GitHub) and explicit <a id=...> or name=..."""
    if md not in _cache:
        text = without_fences(md.read_text(encoding="utf-8"))
        found, seen = set(), {}
        for m in re.finditer(r"^ {0,3}#{1,6}[ \t]+(.+?)[ \t]*#*[ \t]*$", text, re.M):
            base = slug(m.group(1))
            n = seen.get(base, 0)
            seen[base] = n + 1
            found.add(base if n == 0 else f"{base}-{n}")
        found |= set(re.findall(r"<a\s[^>]*?(?:id|name)\s*=\s*[\"']([^\"']+)[\"']", text, re.I))
        _cache[md] = found
    return _cache[md]


@check("Internal documentation links and anchors resolve")
def _links():
    from urllib.parse import unquote
    bad = []
    # Files git would commit, not rglob: a virtualenv's vendored READMEs are
    # not our documentation.
    for md in (f for f in tracked_files() if f.suffix == ".md"):
        text = without_fences(md.read_text(encoding="utf-8"))
        for label, target in re.findall(r"\[([^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)", text):
            if target.startswith(("http://", "https://", "mailto:")):
                continue
            path, _, frag = target.partition("#")
            dest = (md.parent / unquote(path)).resolve() if path else md
            where = f"{md.relative_to(ROOT)} -> {target} (from [{label}])"
            if not dest.exists():
                bad.append(where)
            elif frag and dest.suffix == ".md" and unquote(frag).lower() not in anchors(dest):
                bad.append(f"{where}: no heading or anchor #{frag} in {dest.relative_to(ROOT)}")
    return bad


@check("YAML files parse")
def _yaml():
    try:
        import yaml
    except ImportError:
        return ["PyYAML is not installed, so this check could not run"]
    bad = []
    for f in list((ROOT / ".github").rglob("*.yml")) + list((ROOT / ".github").rglob("*.yaml")):
        try:
            yaml.safe_load(f.read_text(encoding="utf-8"))
        except Exception as exc:
            bad.append(f"{f.relative_to(ROOT)}: {exc}")
    return bad


@check("Supported devices agree between the manifest and the guide")
def _devices():
    manifest = set(manifest_products())

    guide = (ROOT / "docs/adding-a-watch.md").read_text(encoding="utf-8")
    # Only the "Currently supported" table, never the excluded one below it.
    start = guide.find("## Currently supported")
    if start < 0:
        return ["docs/adding-a-watch.md has no '## Currently supported' heading"]
    end = guide.find("Deliberately excluded", start)
    table = guide[start:end if end > 0 else len(guide)]
    documented = set(re.findall(r"^\|\s*`([a-z0-9]+)`", table, re.M))

    bad = []
    for missing in sorted(manifest - documented):
        bad.append(f"{missing} ships in app/manifest.xml but is not in the guide's table")
    for extra in sorted(documented - manifest):
        bad.append(f"{extra} is listed as supported in the guide but is not in app/manifest.xml")
    print(f"   {len(manifest)} products: {', '.join(sorted(manifest))}")
    return bad


@check("No unfilled placeholders")
def _placeholders():
    bad = []
    for f in tracked_files():
        if str(f.relative_to(ROOT)) in SELF_REFERENTIAL:
            continue
        try:
            text = f.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        if "OWNER/REPO" in text:
            bad.append(f"{f.relative_to(ROOT)} still says OWNER/REPO")
    return bad


@check("No personal or vehicle data")
def _privacy():
    # Deliberately blunt. mock/tests/test_privacy.py checks the fixtures in
    # detail; this is the repository-wide backstop, and it is the one that
    # matters when a pull request adds a file nobody thought to look at.
    patterns = {
        "a Škoda API key": r"\bmsk_[A-Za-z0-9]{6,}",
        "a high-precision coordinate": r"\b\d{1,3}\.\d{6,}\b",
        "a street address": r"[A-Z][a-zà-ÿ]+(?:straat|laan|weg|plein|dijk|kade|steeg|strasse)\s+\d+",
        "a private key": r"BEGIN [A-Z ]*PRIVATE KEY",
    }
    # The synthetic values this project uses on purpose. Anything else that
    # matches is either real data or a new placeholder nobody declared, and
    # both deserve a human looking at them.
    allowed_coords = {"52.100000", "5.100000"}
    allowed_addresses = {"Testlaan 1"}
    bad = []
    for f in tracked_files():
        rel = str(f.relative_to(ROOT))
        if rel in SELF_REFERENTIAL:
            continue
        try:
            text = f.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            for what, pattern in patterns.items():
                for hit in re.findall(pattern, line):
                    if what.endswith("coordinate") and hit.lstrip("-") in allowed_coords:
                        continue
                    if what.endswith("address") and hit in allowed_addresses:
                        continue
                    bad.append(f"{rel}:{lineno} looks like {what}: {hit}")
    return bad


def monkey_c_sources() -> list[pathlib.Path]:
    """Every .mc file under app/source, tracked or not.

    Not tracked_files(): a new view is exactly what these checks are for, and
    it is untracked until someone commits it.
    """
    return sorted((ROOT / "app/source").rglob("*.mc"))


def strip_comments(text: str) -> str:
    """Monkey C with // and /* */ comments blanked out, strings kept.

    Comments are where this code base explains why an old pattern is gone
    ("orange 0xFF5500 is retired"), so the UI checks below look at code only.
    Newlines survive, so line numbers still match the file.
    """
    out = []
    i, n = 0, len(text)
    in_string = False
    while i < n:
        ch = text[i]
        if in_string:
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if ch == '"':
                in_string = False
            i += 1
        elif ch == '"':
            in_string = True
            out.append(ch)
            i += 1
        elif text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            end = n if end < 0 else end + 2
            out.append("\n" * text.count("\n", i, end))
            i = end
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def function_bodies(code: str, name: str):
    """(line number, body) of every `function <name>(...) { ... }` in code."""
    for m in re.finditer(r"\bfunction\s+" + re.escape(name) + r"\s*\(", code):
        start = code.find("{", m.end())
        if start < 0:
            continue
        depth = 0
        in_string = False
        j = start
        while j < len(code):
            ch = code[j]
            if in_string:
                if ch == "\\":
                    j += 1
                elif ch == '"':
                    in_string = False
            elif ch == '"':
                in_string = True
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    yield code.count("\n", 0, m.start()) + 1, code[start:j + 1]
                    break
            j += 1


@check("No loadResource inside onUpdate")
def _load_resource_in_on_update():
    # ui-improvements.md A23: onUpdate runs on every redraw (a menu scroll
    # redraws per frame), and loadResource reads the resource from flash
    # each time. Load in initialize()/onShow() and keep the value.
    bad = []
    for f in monkey_c_sources():
        code = strip_comments(f.read_text(encoding="utf-8"))
        for lineno, body in function_bodies(code, "onUpdate"):
            if "loadResource" in body:
                bad.append(f"{f.relative_to(ROOT)}:{lineno} onUpdate calls loadResource")
    return bad


@check("No vertical slide in menu delegate files")
def _menu_slides():
    # ui-improvements.md A20/A23 and decisions.md "Night Panel navigation":
    # menus slide in from the right and out to the right (Theme.SLIDE_IN /
    # SLIDE_OUT); the old menus popped SLIDE_DOWN and Find my car's slid UP.
    # Only Status (up) and Charging (down) move vertically, and only through
    # the Theme constants, so a SLIDE_UP/SLIDE_DOWN literal next to a menu
    # delegate is that bug coming back. Subclasses count (NightMenuDelegate
    # is the Menu2InputDelegate every menu here uses).
    files = {f: strip_comments(f.read_text(encoding="utf-8")) for f in monkey_c_sources()}
    extends = {}
    for f, code in files.items():
        for cls, parent in re.findall(r"\bclass\s+(\w+)\s+extends\s+(?:\w+\.)*(\w+)", code):
            extends[cls] = (parent, f)
    menu_delegates = {"Menu2InputDelegate"}
    changed = True
    while changed:
        changed = False
        for cls, (parent, _) in extends.items():
            if parent in menu_delegates and cls not in menu_delegates:
                menu_delegates.add(cls)
                changed = True
    menu_files = {f for cls, (parent, f) in extends.items() if parent in menu_delegates}
    bad = []
    for f in sorted(menu_files):
        for lineno, line in enumerate(files[f].splitlines(), 1):
            for hit in re.findall(r"\bSLIDE_(?:UP|DOWN)\b", line):
                bad.append(f"{f.relative_to(ROOT)}:{lineno} uses {hit} in a file with a menu delegate")
    print(f"   {len(menu_files)} files define a Menu2InputDelegate subclass")
    return bad


@check("No orange in the app")
def _no_orange():
    # ui-improvements.md D3 and decisions.md "Branding": Škoda Electric Green
    # (0x55FFAA) is the single accent and orange is retired; it used to mean
    # both "error" and "unlocked". Warnings are amber (Theme.WARNING).
    bad = []
    for f in monkey_c_sources():
        code = strip_comments(f.read_text(encoding="utf-8"))
        for lineno, line in enumerate(code.splitlines(), 1):
            for hit in re.findall(r"\bCOLOR_ORANGE\b|\b0[xX][fF][fF]5500\b", line):
                bad.append(f"{f.relative_to(ROOT)}:{lineno} uses {hit}")
    return bad


@check("No request sent with a null body")
def _no_null_body():
    # Garmin Connect on Android does not send a JSON POST whose body is null:
    # the watch gets responseCode 0 and nothing reaches Škoda (measured
    # 2026-10-08). Every request passes a dictionary; a command without a
    # body passes ApiClient.noBody(), an empty one.
    bad = []
    for f in monkey_c_sources():
        code = strip_comments(f.read_text(encoding="utf-8"))
        # A GET has no body by definition; reading works with null.
        for m in re.finditer(r"makeWebRequest\(\s*[^,]+,\s*null\s*,\s*\{[^}]*?HTTP_REQUEST_METHOD_(POST|PUT)", code, re.S):
            lineno = code.count("\n", 0, m.start()) + 1
            bad.append(f"{f.relative_to(ROOT)}:{lineno} sends a {m.group(1)} with a null body")
    return bad


# ---------------------------------------------------------------- devices
# CI cannot build the app (the device files need a Garmin login), so the facts
# a build would need are committed: tools/ui/devices/11-devdata.js, generated
# by devdata.py from the SDK's own device files. The checks below hold every
# list of products in the repository to the manifest and to those facts, and
# `tools/ciq verify` is where the build itself happens, locally. See
# docs/decisions.md, "Device facts are committed, so CI can check them without
# the SDK."

DEVDATA_JS = ROOT / "tools/ui/devices/11-devdata.js"
PROFILES_JS = ROOT / "tools/ui/devices/10-profiles.js"
JUNGLE = ROOT / "app/monkey.jungle"
CIQ = ROOT / "tools/ciq"

# Every family the layouts have been through. A new family is not a manifest
# edit: it needs a layout pass (the Geo tokens, the devices page column, the
# fitcheck) and a device in VERIFY_DEVICES in tools/ciq, and only then a line
# here. See docs/adding-a-watch.md.
KNOWN_FAMILIES = {
    "round-218x218", "round-240x240", "round-260x260", "round-280x280",
    "round-390x390", "round-416x416", "round-454x454", "rectangle-448x486",
}
PROFILES = {"A", "A0", "B", "C"}
API_KEYS = ("MapView", "Complications", "PersistedContent", "GlanceView",
            "setActionMenuIndicator", "saveWaypoint")
MIN_WATCH_APP = 524_288    # bytes: the FR255 has 512 KB and the app fits
MIN_GLANCE = 65_536


def js_const(path: pathlib.Path, name: str):
    """The value of `const <name> = {...};` in a generated JS file, as JSON.

    Bare object keys ({sdk: "9.2.0"}) are quoted first if strict JSON fails.
    """
    text = path.read_text(encoding="utf-8")
    m = re.search(r"\bconst\s+" + re.escape(name) + r"\s*=\s*", text)
    if not m:
        raise ValueError(f"{path.relative_to(ROOT)} has no `const {name} = ...`")
    dec = json.JSONDecoder()
    try:
        return dec.raw_decode(text, m.end())[0]
    except json.JSONDecodeError:
        end = text.find(";\n", m.end())
        src = text[m.end():end if end > 0 else len(text)]
        src = re.sub(r'([{,]\s*)([A-Za-z_]\w*)\s*:', r'\1"\2":', src)
        return dec.raw_decode(src)[0]


def dev_data() -> dict:
    return js_const(DEVDATA_JS, "DEV_DATA")


def dev_meta() -> dict:
    return js_const(DEVDATA_JS, "DEV_META")


def jungle() -> dict[str, str]:
    """app/monkey.jungle as key = value, # comments ignored, $(key) resolved."""
    raw: dict[str, str] = {}
    for line in JUNGLE.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if "=" in line:
            k, v = line.split("=", 1)
            raw[k.strip()] = v.strip()
    def resolve(v: str, depth: int = 0) -> str:
        if depth > 10:
            return v
        return re.sub(r"\$\(([^)]+)\)", lambda m: resolve(raw.get(m.group(1), ""), depth + 1), v)
    return {k: resolve(v) for k, v in raw.items()}


def section(text: str, heading: str, end: str | None = None) -> str | None:
    """From the line `heading` to the next heading of the same or a higher
    level (or to `end`, if given and found first). None if absent."""
    m = re.search(r"^" + re.escape(heading) + r"[ \t]*$", text, re.M)
    if not m:
        return None
    level = len(heading) - len(heading.lstrip("#"))
    body = text[m.end():]
    stop = re.search(r"^#{1,%d}\s" % level, without_fences(body), re.M)
    cut = stop.start() if stop else len(body)
    if end is not None:
        e = body.find(end)
        if 0 <= e < cut:
            cut = e
    return body[:cut]


def table_ids(text: str) -> list[str]:
    """Every `backticked` lowercase id in the table rows of text. A row may
    group several ids (one row per screen size, say)."""
    ids = []
    for line in text.splitlines():
        if line.lstrip().startswith("|"):
            ids += re.findall(r"`([a-z0-9]+)`", line)
    return ids


def version(v: str) -> tuple[int, ...]:
    return tuple(int(x) for x in re.findall(r"\d+", v))


def list_diff(what: str, have: list[str], want: list[str]) -> list[str]:
    """Problems with `have` against the manifest's products `want`."""
    bad = []
    for p in sorted(set(want) - set(have)):
        bad.append(f"{p} ships in app/manifest.xml but is missing from {what}")
    for p in sorted(set(have) - set(want)):
        bad.append(f"{p} is in {what} but not in app/manifest.xml")
    for p in sorted({p for p in have if have.count(p) > 1}):
        bad.append(f"{p} appears more than once in {what}")
    return bad


@check("Supported watches agree between the manifest and the README")
def _readme_watches():
    sec = section((ROOT / "README.md").read_text(encoding="utf-8"), "## Supported watches")
    if sec is None:
        return ["README.md has no '## Supported watches' heading"]
    ids = table_ids(sec)
    print(f"   {len(set(ids))} ids in the README table")
    return list_diff("the README's '## Supported watches' table", ids, manifest_products())


@check("Supported watches agree between the manifest and the store listing")
def _store_listing():
    text = (ROOT / "docs/store-listing.md").read_text(encoding="utf-8")
    sec = section(text, "## Requirements")
    if sec is None:
        return ["docs/store-listing.md has no '## Requirements' heading"]
    m = re.search(r"<!--\s*products:(.*?)-->", sec, re.S)
    if not m:
        return ["docs/store-listing.md '## Requirements' has no "
                "<!-- products: id=\"Store name\"; ... --> marker"]
    pairs = re.findall(r'([a-z0-9]+)\s*=\s*"([^"]+)"', m.group(1))
    bad = list_diff("the store listing's products marker", [i for i, _ in pairs], manifest_products())
    prose = " ".join((sec[:m.start()] + " " + sec[m.end():]).split())
    for pid, name in pairs:
        if " ".join(name.split()) not in prose:
            bad.append(f'{pid}: "{name}" is in the marker but not in the Requirements text')
    print(f"   {len(pairs)} products named in the marker")
    return bad


def _is_int(v) -> bool:
    return isinstance(v, int) and not isinstance(v, bool)


DEV_FIELDS = {
    # field: (test, description)
    "id": (lambda v: isinstance(v, str), "a string"),
    "name": (lambda v: isinstance(v, str) and v, "a non-empty string"),
    "family": (lambda v: isinstance(v, str), "a string"),
    "displayType": (lambda v: isinstance(v, str), "a string"),
    "bpp": (_is_int, "an integer"),
    "w": (_is_int, "an integer"),
    "h": (_is_int, "an integer"),
    "shape": (lambda v: v in ("round", "rectangle", "semi-round", "semi-octagon"), "a display shape"),
    "ppi": (lambda v: v is None or _is_int(v), "an integer or null"),
    "touch": (lambda v: isinstance(v, bool), "a boolean"),
    "keys": (lambda v: isinstance(v, list), "a list"),
    "profile": (lambda v: v in PROFILES, "one of " + "/".join(sorted(PROFILES))),
    "api": (lambda v: isinstance(v, dict) and all(_is_int(v.get(k)) for k in API_KEYS),
            "an object with integer " + ", ".join(API_KEYS)),
    "mapView": (lambda v: isinstance(v, bool), "a boolean"),
    "budget": (lambda v: isinstance(v, dict) and _is_int(v.get("watchApp")) and _is_int(v.get("glance")),
               "an object with integer watchApp and glance"),
    "ciq": (lambda v: isinstance(v, str) and re.fullmatch(r"\d+(\.\d+)*", v), "a version string"),
    "glance": (lambda v: v is None or isinstance(v, list), "a list or null"),
    "actionMenuHint": (lambda v: v is None or isinstance(v, list), "a list or null"),
    "launcher": (_is_int, "an integer"),
    "fonts": (lambda v: isinstance(v, dict) and v, "a non-empty object"),
}


@check("Device facts cover every product")
def _devdata():
    bad = []
    first = DEVDATA_JS.read_text(encoding="utf-8").lstrip().splitlines()[0]
    if not first.startswith("// GENERATED"):
        bad.append(f"{DEVDATA_JS.relative_to(ROOT)} does not start with a // GENERATED header")
    data, products = dev_data(), manifest_products()
    if list(data) != products:
        bad.append(f"DEV_DATA keys are not the manifest's products in manifest order: "
                   f"{list(data)} vs {products}")
    for pid, d in data.items():
        for field, (ok, desc) in DEV_FIELDS.items():
            if field not in d:
                bad.append(f"DEV_DATA.{pid} has no {field}")
            elif not ok(d[field]):
                bad.append(f"DEV_DATA.{pid}.{field} is not {desc}: {d[field]!r}"[:200])
        if d.get("id") != pid:
            bad.append(f"DEV_DATA.{pid}.id is {d.get('id')!r}")
        if (d.get("api") or {}).get("MapView") == 0 and d.get("mapView") is True:
            bad.append(f"DEV_DATA.{pid} has mapView true but no MapView entries at all")
    meta = dev_meta()
    if not (isinstance(meta, dict) and isinstance(meta.get("sdk"), str) and meta["sdk"]):
        bad.append("DEV_META.sdk is not set (which SDK the facts were read from)")
    print(f"   {len(data)} devices, SDK {meta.get('sdk') if isinstance(meta, dict) else '?'}")
    return bad


@check("Every product meets the minimum")
def _minimums():
    m = re.search(r'minApiLevel="([^"]+)"', (ROOT / "app/manifest.xml").read_text(encoding="utf-8"))
    min_api = m.group(1) if m else "0"
    bad = []
    # A missing field is the device facts check's to report; here it is skipped.
    for pid, d in dev_data().items():
        if "ciq" in d and version(str(d["ciq"])) < version(min_api):
            bad.append(f"{pid}: Connect IQ {d['ciq']} is below the manifest's minApiLevel {min_api}")
        budget = d.get("budget")
        if isinstance(budget, dict):
            if (budget.get("glance") or 0) < MIN_GLANCE:
                bad.append(f"{pid}: glance budget {budget.get('glance')} B is below {MIN_GLANCE}")
            if (budget.get("watchApp") or 0) < MIN_WATCH_APP:
                bad.append(f"{pid}: watch-app budget {budget.get('watchApp')} B is below {MIN_WATCH_APP}")
        api = d.get("api")
        if isinstance(api, dict):
            for need in ("Complications", "PersistedContent", "GlanceView"):
                if not (api.get(need) or 0) > 0:
                    bad.append(f"{pid}: has no {need} implementation (api.{need} = {api.get(need)})")
        if "family" in d and d["family"] not in KNOWN_FAMILIES:
            bad.append(f"{pid}: family {d['family']} has had no layout pass "
                       f"(KNOWN_FAMILIES in tools/checks.py, docs/adding-a-watch.md)")
    print(f"   minApiLevel {min_api}, watch app >= {MIN_WATCH_APP} B, glance >= {MIN_GLANCE} B")
    return bad


def annotations(code: str) -> set[str]:
    """Every name used in an annotation group like (:map) or (:glance, :background)."""
    names = set()
    for group in re.findall(r"\((\s*:\w+(?:[\s,]+:\w+)*)\s*\)", code):
        names |= set(re.findall(r":(\w+)", group))
    return names


@check("The map is left out exactly where MapView is missing")
def _map_exclusion():
    bad = []
    products, data, jg = manifest_products(), dev_data(), jungle()
    for key in jg:
        prefix = key.split(".", 1)[0]
        if prefix not in ("base", "project") and prefix not in products:
            bad.append(f"app/monkey.jungle sets {key}, but {prefix} is not a product in app/manifest.xml")
    split = lambda v: {a.strip() for a in v.split(";") if a.strip()}
    base = split(jg.get("base.excludeAnnotations", ""))
    if "nomap" not in base:
        bad.append("app/monkey.jungle: base.excludeAnnotations does not exclude nomap")
    # mapView, not the api.MapView count: devdata.py counts "MapView"
    # substrings in api.debug.xml, and a watch without the class still has a
    # few (2 on the FR255 and Venu 3). mapView is whether
    # Toybox_WatchUi_MapView itself is there.
    for pid in products:
        has_map = (data.get(pid) or {}).get("mapView")
        if not isinstance(has_map, bool):
            bad.append(f"{pid}: no mapView in DEV_DATA, so its map exclusion cannot be checked")
            continue
        own = jg.get(f"{pid}.excludeAnnotations")
        effective = split(own) if own is not None else base
        if not has_map and "map" not in effective:
            bad.append(f"{pid} has no MapView, but app/monkey.jungle does not exclude map for it "
                       f"(add {pid}.excludeAnnotations = map)")
        if has_map and "map" in effective:
            bad.append(f"{pid} has MapView, but app/monkey.jungle excludes map for it")
        if "map" in effective and "nomap" in effective:
            bad.append(f"{pid}: app/monkey.jungle excludes both map and nomap")
        if not has_map and "nomap" in effective:
            bad.append(f"{pid}: app/monkey.jungle excludes nomap, so the no-map code is missing too")
    used = set()
    sources = {f: strip_comments(f.read_text(encoding="utf-8")) for f in monkey_c_sources()}
    for code in sources.values():
        used |= annotations(code)
    excluded = set()
    for key, v in jg.items():
        if key.endswith(".excludeAnnotations"):
            excluded |= split(v)
    for name in sorted(excluded - used):
        bad.append(f"app/monkey.jungle excludes :{name}, which no (:{name}) in app/source uses")
    for f, code in sources.items():
        for m in re.finditer(r"\bclass\s+(\w+)\s+extends\s+(?:Toybox\.)?(?:WatchUi\.)?MapView\b", code):
            line_start = code.rfind("\n", 0, m.start()) + 1
            before = code[line_start:m.start()]
            lines = code[:line_start].splitlines()
            while lines and not lines[-1].strip():
                lines.pop()
            above = []
            while lines and re.fullmatch(r"\s*\(\s*:\w+(?:[\s,]+:\w+)*\s*\)\s*", lines[-1]):
                above.append(lines.pop())
            if not any("map" in annotations(s) for s in above + [before]):
                lineno = code.count("\n", 0, m.start()) + 1
                bad.append(f"{f.relative_to(ROOT)}:{lineno} {m.group(1)} extends MapView without a "
                           f"(:map) annotation, so it links on watches that have no MapView")
    no_map = [p for p in products if (data.get(p) or {}).get("mapView") is False]
    print(f"   {len(no_map)} products without MapView: {', '.join(no_map) or 'none'}")
    return bad


@check("Every product has a column on the devices page")
def _columns():
    # The columns are generated with the device facts (devdata.py columns()), so a product
    # without one means 11-devdata.js is stale; the rest guards the generator.
    bad, data, covered = [], dev_data(), []
    cols = js_const(DEVDATA_JS, "DEV_COLUMNS")
    for c in cols:
        covered += c.get("covers") or []
        if c.get("dev") not in (c.get("covers") or []):
            bad.append(f"column {c.get('id')} is drawn as {c.get('dev')}, which is not in its covers")
        for pid in c.get("covers") or []:
            prof = (data.get(pid) or {}).get("profile")
            if prof is not None and c.get("input") != prof:
                bad.append(f"column {c.get('id')} has input {c.get('input')}, but {pid} is profile {prof} in DEV_DATA")
    bad += list_diff("the devices page columns (DEV_COLUMNS in tools/ui/devices/11-devdata.js; "
                     "run tools/ui/devices/devdata.py)", covered, manifest_products())
    print(f"   {len(cols)} columns cover {len(set(covered))} products")
    return bad


def verify_devices() -> list[str]:
    m = re.search(r"^VERIFY_DEVICES=\(([^)]*)\)", CIQ.read_text(encoding="utf-8"), re.M)
    if not m:
        raise ValueError("tools/ciq has no VERIFY_DEVICES=(...) line")
    return m.group(1).split()


@check("Generated device lists are current")
def _devicelists():
    # README, guide, store listing, manifest comment and jungle lines, written by
    # tools/devicelists.py from the manifest and the device facts.
    sys.path.insert(0, str(ROOT / "tools"))
    import devicelists
    return devicelists.stale()


@check("tools/ciq verify covers every family and input profile")
def _verify_devices():
    bad, data, products = [], dev_data(), manifest_products()
    devs = verify_devices()
    for d in devs:
        if d not in products:
            bad.append(f"VERIFY_DEVICES has {d}, which is not in app/manifest.xml")
    if devs and products and devs[0] != products[0]:
        bad.append(f"VERIFY_DEVICES starts with {devs[0]}, not the primary product {products[0]}")
    have_fam = {(data.get(d) or {}).get("family") for d in devs}
    have_pair = {((data.get(d) or {}).get("profile"), (data.get(d) or {}).get("mapView")) for d in devs}
    for fam in sorted({d.get("family") for d in data.values()} - have_fam, key=str):
        who = [p for p, d in data.items() if d.get("family") == fam]
        bad.append(f"no verify device has family {fam} (any of {', '.join(who)})")
    for pair in sorted({(d.get("profile"), d.get("mapView")) for d in data.values()} - have_pair, key=str):
        who = [p for p, d in data.items() if (d.get("profile"), d.get("mapView")) == pair]
        bad.append(f"no verify device is profile {pair[0]} with mapView {pair[1]} "
                   f"(any of {', '.join(who)})")
    ciqs = {p: str(d.get("ciq")) for p, d in data.items() if d.get("ciq")}
    if ciqs:
        lowest = min(ciqs.values(), key=version)
        if not any(ciqs.get(d) == lowest for d in devs):
            who = [p for p, v in ciqs.items() if v == lowest]
            bad.append(f"no verify device runs the lowest Connect IQ version, {lowest} "
                       f"(any of {', '.join(who)})")
    print(f"   {len(devs)} verify devices: {' '.join(devs)}")
    return bad


@check("The manifest comment names every product")
def _manifest_comment():
    text = (ROOT / "app/manifest.xml").read_text(encoding="utf-8")
    products = manifest_products()
    bad = []
    if not products or products[0] != "fenix7pro":
        bad.append(f"the first product is {products[:1]}, not fenix7pro (the primary, the watch we test on)")
    m = re.search(r"<!--(.*?)-->", text, re.S)
    if not m:
        return bad + ["app/manifest.xml has no header comment"]
    comment = m.group(1)
    ex = re.search(r"deliberately\s+excluded", comment, re.I)
    if not ex:
        return bad + ["the manifest comment has no 'DELIBERATELY EXCLUDED' section"]
    shipped, excluded = comment[:ex.start()], comment[ex.end():]
    word = lambda pid, s: re.search(r"(?<![\w])" + re.escape(pid) + r"(?![\w])", s)
    for pid in products:
        if not word(pid, shipped):
            bad.append(f"{pid} ships but the manifest comment does not describe it")
        if word(pid, excluded):
            bad.append(f"{pid} ships but is named under DELIBERATELY EXCLUDED in the manifest comment")
    return bad


@check("Decisions cited elsewhere exist")
def _decisions_cited():
    def norm(s: str) -> str:
        return " ".join(s.replace("`", "").split()).lower()
    decisions = norm((ROOT / "docs/decisions.md").read_text(encoding="utf-8"))
    bad, seen = [], 0
    for f in tracked_files():
        rel = str(f.relative_to(ROOT))
        if f.suffix not in (".mc", ".md", ".py", ".js", ".sh", ".xml", ".yml") or rel in SELF_REFERENTIAL:
            continue
        try:
            text = f.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        # A citation may run over a line break, in a comment that continues
        # on the next line (// or # or *) or in wrapped prose.
        joined = re.sub(r"[ \t]*\n[ \t]*(?:(?://+|#+|\*)(?![/*])[ \t]*)?", " ", text)
        for m in re.finditer(r'decisions\.md[^"\n]{0,20}"([^"]{6,80})"', joined):
            seen += 1
            if norm(m.group(1)) not in decisions:
                bad.append(f'{rel} cites decisions.md "{m.group(1)}", which docs/decisions.md does not contain')
    print(f"   {seen} citations")
    return bad


STALE_CI = [r"CI matrix", r"matrix\.device", r"restores them from a cache",
            r"in CI for each", r"warnings are errors in CI"]


@check("No stale claims about what CI does")
def _stale_ci():
    # CI has not built the app since 1.0 (see .github/workflows/build.yml);
    # these are phrases from when it tried. The changelog is history.
    skip = {"CHANGELOG.md", ".github/workflows/build.yml"} | SELF_REFERENTIAL
    bad = []
    for f in tracked_files():
        rel = str(f.relative_to(ROOT))
        if rel in skip:
            continue
        try:
            text = f.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            for pat in STALE_CI:
                if re.search(pat, line):
                    bad.append(f"{rel}:{lineno} says '{re.search(pat, line).group(0)}', "
                               f"but CI builds nothing (tools/ciq verify does, locally)")
    return bad


@check("Shell scripts parse")
def _bash_n():
    import subprocess
    scripts = [CIQ] + sorted((ROOT / "tools/ui").glob("*.sh")) + sorted((ROOT / "tools/ui/devices").glob("*.sh"))
    bad = []
    for s in scripts:
        rel = str(s.relative_to(ROOT))
        r = subprocess.run(["bash", "-n", rel], cwd=ROOT, capture_output=True, text=True)
        if r.returncode:
            bad.append(f"{rel}: {r.stderr.strip()}")
    print(f"   {len(scripts)} scripts")
    return bad


if __name__ == "__main__":
    print(f"\n{len(failures)} problem(s)" if failures else "\nAll checks passed")
    for f in failures:
        print(f"  {f}")
    sys.exit(1 if failures else 0)
