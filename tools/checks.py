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
    skip = {"mock/openapi.json",           # Škoda's own document, with their examples
            "tools/checks.py",             # this file, which contains the patterns
            "mock/tests/test_privacy.py"}  # likewise

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
            for what, pattern in patterns.items():
                for hit in re.findall(pattern, line):
                    if what.endswith("coordinate") and hit.lstrip("-") in allowed_coords:
                        continue
                    if what.endswith("address") and hit in allowed_addresses:
                        continue
                    bad.append(f"{rel}:{lineno} looks like {what}: {hit}")
    return bad


if __name__ == "__main__":
    print(f"\n{len(failures)} problem(s)" if failures else "\nAll checks passed")
    for f in failures:
        print(f"  {f}")
    sys.exit(1 if failures else 0)
