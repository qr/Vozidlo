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

import re
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
failures: list[str] = []

# Files that necessarily contain the very strings the checks look for, and so
# would report themselves. This file holds every pattern; test_privacy.py holds
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
    """Files git would commit. Falls back to everything outside .git."""
    import subprocess
    try:
        out = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True,
                             text=True, check=True).stdout.split()
        return [ROOT / f for f in out]
    except Exception:
        return [p for p in ROOT.rglob("*") if p.is_file() and ".git" not in p.parts]


@check("Internal documentation links resolve")
def _links():
    bad = []
    for md in ROOT.rglob("*.md"):
        if ".git" in md.parts:
            continue
        for label, target in re.findall(r"\[([^\]]+)\]\(([^)]+)\)", md.read_text(encoding="utf-8")):
            if target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            path = target.split("#")[0]
            if path and not (md.parent / path).resolve().exists():
                bad.append(f"{md.relative_to(ROOT)} -> {target} (from [{label}])")
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
    manifest = set(re.findall(r'<iq:product\s+id="([^"]+)"',
                              (ROOT / "app/manifest.xml").read_text(encoding="utf-8")))

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


if __name__ == "__main__":
    print(f"\n{len(failures)} problem(s)" if failures else "\nAll checks passed")
    for f in failures:
        print(f"  {f}")
    sys.exit(1 if failures else 0)
