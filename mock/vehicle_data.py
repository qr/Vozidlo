"""The default vehicle: a plug-in hybrid Škoda.

Every field here reproduces the SHAPE of what was measured against a real
plug-in hybrid, on hardware, in September 2026 - including the surprising bits
a mock written from the OpenAPI document alone would get wrong.
`chargingProfiles`, `auxiliaryHeating` and `activeVentilation` are genuinely
absent for this car, and
`charging.settings.availableChargeModes` is genuinely an empty array even
though `setChargeMode` is advertised in `operations[]`. A mock that "fixes"
these to look more complete would stop being useful for testing the app
against reality.

NOTHING PERSONAL BELONGS IN THIS FILE. The VIN, the parking position and the
odometer are deliberate placeholders, and tests/test_privacy.py fails if they
are changed to anything that looks like real data. An earlier version of this
file carried the actual coordinates, street address and mileage from the
capture, which is exactly the mistake that guard exists to prevent: this repo
is public, and a parking position is somebody's home address.

Copy a real response for its SHAPE, never for its VALUES.
"""
from __future__ import annotations

import datetime as _dt

MOCK_VIN = "TMBMOCKVIN0000017"  # 17 characters, obviously not a real VIN

# Placeholders, asserted by tests/test_privacy.py. Somewhere in a field in the
# middle of the Netherlands, with the round decimals that make it read as
# invented; the address is a made-up street in a made-up town.
MOCK_LATITUDE = 52.100000
MOCK_LONGITUDE = 5.100000
MOCK_ADDRESS = "Testlaan 1, 1000 AA Teststad, Netherlands"
MOCK_ODOMETER_KM = 123456
MOCK_VEHICLE_NAME = "Test Vehicle"

OPERATIONS = [
    "startCharging",
    "stopCharging",
    "setChargingLimit",
    "setChargeMode",
    "startAirConditioning",
    "stopAirConditioning",
]

# Default age (in minutes) of each section's carCapturedTimestamp, matching
# the spread actually measured: everything a few minutes old. The
# 'stale-airconditioning-17h' scenario (and the generic 'ages' override on
# the control endpoint) push individual sections older.
DEFAULT_AGES_MINUTES = {
    "status": 13,
    "charging": 12,
    "fuelStatus": 12,
    "odometer": 12,
    "airConditioning": 12,
    "parkingPosition": 12,
}


def now() -> _dt.datetime:
    return _dt.datetime.now(_dt.timezone.utc)


def iso(dt: _dt.datetime) -> str:
    """ISO 8601 with milliseconds and a literal 'Z', as Škoda sends it."""
    return dt.strftime("%Y-%m-%dT%H:%M:%S.") + f"{dt.microsecond // 1000:03d}Z"


def iso_seconds(dt: _dt.datetime) -> str:
    """Same format the vehicle's own carCapturedTimestamp uses (no millis)."""
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def timestamp_minutes_ago(minutes: float) -> str:
    return iso_seconds(now() - _dt.timedelta(minutes=minutes))


def build_default_vehicle(vin: str, ages_minutes: dict | None = None) -> dict:
    """Returns a fresh copy of the default `vehicle` object."""
    ages = dict(DEFAULT_AGES_MINUTES)
    if ages_minutes:
        ages.update(ages_minutes)

    return {
        "vin": vin,
        "name": MOCK_VEHICLE_NAME,
        # licensePlate: deliberately absent, as measured.
        "renderUrl": (
            "https://iprenders.blob.core.windows.net/base3v5s20100916/"
            "mock-render-not-a-real-asset_side1080.png"
        ),
        "status": {
            "overall": {
                "doorsLocked": "YES",
                "locked": "YES",
                "doors": "CLOSED",
                "windows": "CLOSED",
                "lights": "OFF",
                "reliableLockStatus": "LOCKED",
            },
            "detail": {
                "sunroof": "UNSUPPORTED",
                "trunk": "CLOSED",
                "bonnet": "CLOSED",
            },
            "carCapturedTimestamp": timestamp_minutes_ago(ages["status"]),
        },
        "fuelStatus": {
            "carType": "HYBRID",
            "totalRangeInKm": 436,
            "primaryEngineRange": {
                "engineType": "GASOLINE",
                "currentFuelLevelInPercent": 62,
                "currentSoCInPercent": 62,
                "remainingRangeInKm": 400,
            },
            "secondaryEngineRange": {
                "engineType": "ELECTRIC",
                "currentFuelLevelInPercent": 100,
                "currentSoCInPercent": 100,
                "remainingRangeInKm": 36,
            },
            "carCapturedTimestamp": timestamp_minutes_ago(ages["fuelStatus"]),
        },
        "odometer": {
            "mileageInKm": MOCK_ODOMETER_KM,
            "carCapturedTimestamp": timestamp_minutes_ago(ages["odometer"]),
        },
        "parkingPosition": {
            "state": "PARKED",
            "gpsCoordinates": {"latitude": MOCK_LATITUDE, "longitude": MOCK_LONGITUDE},
            "formattedAddress": MOCK_ADDRESS,
        },
        "airConditioning": {
            "state": "OFF",
            "airConditioningWithoutExternalPower": True,
            "targetTemperature": {"value": 21.0, "unit": "CELSIUS"},
            "windowHeating": {"front": "OFF", "rear": "OFF"},
            "carCapturedTimestamp": timestamp_minutes_ago(ages["airConditioning"]),
        },
        # auxiliaryHeating, activeVentilation, chargingProfiles, licensePlate:
        # deliberately absent - this vehicle does not support them.
        "charging": {
            "isVehicleInSavedLocation": False,
            "status": {
                "state": "READY_FOR_CHARGING",
                "chargeType": "OFF",
                "battery": {
                    "stateOfChargeInPercent": 100,
                    "remainingCruisingRangeInMeters": 36000,
                },
            },
            "settings": {
                "availableChargeModes": [],  # empty despite setChargeMode above - measured
                "maxChargeCurrentAc": "MAXIMUM",
            },
            "carCapturedTimestamp": timestamp_minutes_ago(ages["charging"]),
        },
        "operations": [{"name": n} for n in OPERATIONS],
    }
