"""This repository is public. Nobody's real vehicle data may be committed to it.

The rule is easy to break by accident and hard to undo: the natural way to
build a realistic mock is to paste a captured response and edit it down, and
the natural way to write a test for parking position is to paste the
coordinates you happen to have. An earlier version of this repository did
exactly that and carried a real street address, its GPS coordinates and a real
odometer reading through thirty-odd commits.

A parking position is somebody's home address. Copy a real response for its
SHAPE, never for its VALUES.

These tests are the tripwire. They are deliberately dumb and deliberately
strict: they pin the placeholders, and they scan the mock and the Monkey C
tests for anything that looks like a real address or an unexplained
coordinate.
"""
from __future__ import annotations

import pathlib
import re

import vehicle_data

REPO = pathlib.Path(__file__).resolve().parents[2]

# The sanctioned placeholders. Changing these is fine; changing them to real
# data is what this file exists to stop, so change them here as well and the
# reviewer will see it in the diff.
PLACEHOLDER_LATITUDE = 52.100000
PLACEHOLDER_LONGITUDE = 5.100000
PLACEHOLDER_ADDRESS = "Testlaan 1, 1000 AA Teststad, Netherlands"
PLACEHOLDER_ODOMETER_KM = 123456
PLACEHOLDER_VIN = "TMBMOCKVIN0000017"

# Files that legitimately contain vehicle-shaped fixtures.
FIXTURE_FILES = [
    REPO / "mock" / "vehicle_data.py",
    REPO / "app" / "tests" / "LocationTests.mc",
    REPO / "app" / "tests" / "VehicleStateTests.mc",
]


def test_mock_uses_the_sanctioned_placeholders():
    assert vehicle_data.MOCK_LATITUDE == PLACEHOLDER_LATITUDE
    assert vehicle_data.MOCK_LONGITUDE == PLACEHOLDER_LONGITUDE
    assert vehicle_data.MOCK_ADDRESS == PLACEHOLDER_ADDRESS
    assert vehicle_data.MOCK_ODOMETER_KM == PLACEHOLDER_ODOMETER_KM
    assert vehicle_data.MOCK_VIN == PLACEHOLDER_VIN


def test_the_placeholder_vin_is_not_a_valid_vin():
    """A real VIN never contains I, O or Q - they are excluded to avoid
    confusion with 1 and 0. The placeholder contains O twice, so it cannot
    collide with a real vehicle no matter who runs this.
    """
    assert set("IOQ") & set(PLACEHOLDER_VIN), (
        "the placeholder VIN must contain I, O or Q so it can never be a real VIN"
    )


def test_no_coordinates_outside_the_placeholder_appear_in_fixtures():
    """Any decimal that looks like a latitude or longitude, in a file that
    carries vehicle fixtures, must be one of the placeholders.

    Six or more decimal places is roughly ten centimetres of precision. That
    is a captured position, not a number anybody types by hand.
    """
    precise = re.compile(r"\b\d{1,3}\.\d{6,}\b")
    allowed = {f"{PLACEHOLDER_LATITUDE:.6f}", f"{PLACEHOLDER_LONGITUDE:.6f}"}
    offenders = []
    for path in FIXTURE_FILES:
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for match in precise.findall(line):
                if match.rstrip("0").rstrip(".") in {a.rstrip("0").rstrip(".") for a in allowed}:
                    continue
                offenders.append(f"{path.relative_to(REPO)}:{lineno}: {match}")
    assert not offenders, (
        "high-precision coordinates that are not the placeholder:\n  "
        + "\n  ".join(offenders)
        + "\n\nIf this is real captured data, remove it. See this file's docstring."
    )


def test_no_street_addresses_other_than_the_placeholder():
    """Dutch and German street-address shapes, which is what this API returns.

    A house number followed by a postcode is the giveaway; it is not a
    pattern that appears in code by accident.
    """
    address_like = re.compile(
        r"[A-Z][a-zà-ÿ]+(?:straat|laan|weg|plein|dijk|kade|steeg|str\.|strasse)\s+\d+",
        re.IGNORECASE,
    )
    offenders = []
    for path in FIXTURE_FILES:
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for match in address_like.findall(line):
                if PLACEHOLDER_ADDRESS.split(",")[0] in line:
                    continue
                offenders.append(f"{path.relative_to(REPO)}:{lineno}: {match}")
    assert not offenders, (
        "street addresses that are not the placeholder:\n  "
        + "\n  ".join(offenders)
        + "\n\nA parking position is somebody's home address. See this file's docstring."
    )


def test_no_api_keys_anywhere_in_the_repository():
    """Škoda keys are prefixed msk_. One in a commit is one too many; the key
    would have to be revoked and every fork would still have it.
    """
    key_like = re.compile(r"\bmsk_[A-Za-z0-9]{6,}")
    skip_dirs = {".git", "__pycache__", "bin", ".pytest_cache", "node_modules"}
    offenders = []
    for path in REPO.rglob("*"):
        if not path.is_file() or any(part in skip_dirs for part in path.parts):
            continue
        if path.suffix in {".png", ".der", ".iq", ".prg", ".svg"}:
            continue
        if path.name == "test_privacy.py":
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            if key_like.search(line):
                offenders.append(f"{path.relative_to(REPO)}:{lineno}")
    assert not offenders, "API keys found:\n  " + "\n  ".join(offenders)
