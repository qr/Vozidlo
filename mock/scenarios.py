"""US-050: on-demand failure and edge-case scenarios, switchable at runtime.

Every name here is one the task/user stories call for by name. Two kinds:

- "error" scenarios short-circuit a request with a specific error response
  (an outage, a rejected key, a declined command, ...).
- "shape" scenarios let the request succeed normally but reshape the vehicle
  body (partial data, a stale section, an unusual enum value, ...) or the
  success headers (quota nearly spent, a key expiring soon).

Only one scenario is active at a time, chosen either globally (via the
control endpoint, or --scenario at startup) or per-request (an
`X-Mock-Scenario` header or `?_scenario=` query parameter, both of which
override the global setting for that one request only, without changing it
for anyone else). See README.md for the exact switching mechanism.
"""
from __future__ import annotations

import copy
import datetime as _dt
import threading
from dataclasses import dataclass, field
from typing import Callable

from vehicle_data import build_default_vehicle, iso, now

PROBLEM_BASE = "https://public.api.connect.skoda-auto.cz/problems/"


@dataclass
class ErrorSpec:
    status: int
    problem_type: str          # short name; "about:blank" stays as-is
    title: str
    detail: Callable[["ScenarioContext"], str]
    applies_to: str = "all"    # "all", "GET", or "COMMAND"
    retry_after: bool = False


@dataclass
class ScenarioContext:
    vin: str
    method: str                 # "GET" or a command verb
    is_command: bool


@dataclass
class ScenarioState:
    name: str = "default"
    # Per-section carCapturedTimestamp age overrides, in minutes. Lets any
    # scenario - or a control-endpoint call - push a section's data older,
    # generalising the specific 17-hour airConditioning case that was
    # actually measured.
    ages_minutes: dict = field(default_factory=dict)


_lock = threading.Lock()
_state = ScenarioState()


def set_global(name: str, ages_minutes: dict | None = None) -> None:
    with _lock:
        _state.name = name
        _state.ages_minutes = dict(ages_minutes) if ages_minutes else {}


def get_global() -> ScenarioState:
    with _lock:
        return ScenarioState(_state.name, dict(_state.ages_minutes))


def _expired_detail(ctx: ScenarioContext) -> str:
    expired_at = now() - _dt.timedelta(days=6)
    return f"The API key expired on {expired_at.strftime('%Y-%m-%dT%H:%M:%SZ')}."


ERROR_SCENARIOS: dict[str, ErrorSpec] = {
    "api-key-expired": ErrorSpec(
        401, "api-key-expired", "Unauthorized", _expired_detail, applies_to="all",
    ),
    "api-key-not-authorized": ErrorSpec(
        403, "api-key-not-authorized", "Forbidden",
        lambda ctx: f"The API key is not authorized for vehicle {ctx.vin}.",
        applies_to="all",
    ),
    "operation-not-supported": ErrorSpec(
        422, "operation-not-supported", "Unprocessable Entity",
        lambda ctx: "The vehicle does not support this operation.",
        applies_to="COMMAND",
    ),
    "operation-disabled": ErrorSpec(
        422, "operation-disabled", "Unprocessable Entity",
        lambda ctx: "This operation is currently disabled for the vehicle.",
        applies_to="COMMAND",
    ),
    "rate-limit-exceeded": ErrorSpec(
        429, "rate-limit-exceeded", "Too Many Requests",
        lambda ctx: "The rate limit for this API key has been exceeded.",
        applies_to="all", retry_after=True,
    ),
    "vehicle-not-accepting-requests": ErrorSpec(
        429, "vehicle-not-accepting-requests", "Too Many Requests",
        lambda ctx: "The vehicle declined the request. Retry later.",
        applies_to="all", retry_after=True,
    ),
    "500": ErrorSpec(500, "about:blank", "Internal Server Error",
                      lambda ctx: "An unexpected error occurred.", applies_to="all"),
    "503": ErrorSpec(503, "about:blank", "Service Unavailable",
                      lambda ctx: "The service is temporarily unavailable.", applies_to="all"),
    "504": ErrorSpec(504, "about:blank", "Gateway Timeout",
                      lambda ctx: "The upstream vehicle service timed out.", applies_to="all"),
    "vehicle-not-found": ErrorSpec(
        404, "about:blank", "Not Found",
        lambda ctx: f"No vehicle found for VIN {ctx.vin}.",
        applies_to="all",
    ),
}

# Names that reshape a successful response instead of failing it.
SHAPE_SCENARIOS = {
    "partial-data",
    "in-motion",
    "stale-airconditioning-17h",
    "quota-nearly-spent",
    "charging-active",
    "connect-cable",
    "empty-charge-modes",
    "charging-profiles",
    "parked-with-address",
    "parked-no-address",
    "parking-position-unsupported",
    "expires-in-20-days",
    "unknown-enum",
}

ALL_SCENARIOS = ["default"] + sorted(ERROR_SCENARIOS) + sorted(SHAPE_SCENARIOS)


def error_for(scenario_name: str, ctx: ScenarioContext) -> dict | None:
    """Returns a ProblemDetail dict (plus 'status'/'retryAfter') or None."""
    spec = ERROR_SCENARIOS.get(scenario_name)
    if spec is None:
        return None
    if spec.applies_to == "COMMAND" and not ctx.is_command:
        return None
    if spec.applies_to == "GET" and ctx.is_command:
        return None
    ptype = "about:blank" if spec.problem_type == "about:blank" else PROBLEM_BASE + spec.problem_type
    return {
        "type": ptype,
        "title": spec.title,
        "status": spec.status,
        "detail": spec.detail(ctx),
        "instance": f"/api/v1/vehicles/{ctx.vin}",
        "_retryAfter": spec.retry_after,
    }


def build_vehicle(vin: str, scenario_name: str, ages_minutes: dict) -> tuple[dict, list]:
    """Returns (vehicle_dict, errors_list) for a successful GET, shaped
    according to `scenario_name`."""
    vehicle = build_default_vehicle(vin, ages_minutes)
    errors: list = []

    if scenario_name == "stale-airconditioning-17h" and "airConditioning" not in ages_minutes:
        vehicle = build_default_vehicle(vin, {**ages_minutes, "airConditioning": 17 * 60})

    elif scenario_name == "partial-data":
        # Sections unsupported/disabled/unavailable right now: dropped from
        # the body, each explained in errors[], per US-050.
        del vehicle["charging"]
        del vehicle["parkingPosition"]
        errors.extend([
            {"type": "CHARGING_UNAVAILABLE", "description": "Charging status could not be retrieved from the vehicle."},
            {"type": "PARKING_POSITION_DISABLED", "description": "Parking position is supported, but currently disabled."},
        ])

    elif scenario_name == "in-motion":
        vehicle["parkingPosition"] = {"state": "IN_MOTION"}

    elif scenario_name == "charging-active":
        vehicle["charging"]["status"] = {
            "state": "CHARGING",
            "chargeType": "AC",
            "chargingRateInKilometersPerHour": 18.4,
            "chargePowerInKw": 7.4,
            "remainingTimeToFullyChargedInMinutes": 95,
            "fullyChargedAt": iso(now() + _dt.timedelta(minutes=95)),
            "battery": {"stateOfChargeInPercent": 55, "remainingCruisingRangeInMeters": 19800},
        }

    elif scenario_name == "connect-cable":
        vehicle["charging"]["status"]["state"] = "CONNECT_CABLE"

    elif scenario_name == "empty-charge-modes":
        vehicle["charging"]["settings"]["availableChargeModes"] = []  # explicit, matches default

    elif scenario_name == "charging-profiles":
        vehicle["chargingProfiles"] = {
            "profiles": [{
                "id": 123456,
                "name": "Home",
                "settings": {
                    "maxChargingCurrent": "MAXIMUM",
                    "minBatteryStateOfCharge": {"enabled": True, "minimumBatteryStateOfChargeInPercent": 50},
                    "targetStateOfChargeInPercent": 80,
                    "autoUnlockPlugWhenCharged": "PERMANENT",
                },
                "preferredChargingTimes": [
                    {"id": 1, "enabled": True, "startTime": "23:00", "endTime": "06:00"},
                ],
                "timers": [
                    {"id": 1, "enabled": True, "time": "23:00", "type": "RECURRING",
                     "recurringOn": ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"]},
                ],
            }],
            "currentVehiclePositionProfile": {"id": 123456, "name": "Home", "targetStateOfChargeInPercent": 80},
        }

    elif scenario_name == "parked-with-address":
        pass  # this is the default shape already; kept as an explicit, documented name

    elif scenario_name == "parked-no-address":
        vehicle["parkingPosition"].pop("formattedAddress", None)

    elif scenario_name == "parking-position-unsupported":
        del vehicle["parkingPosition"]
        errors.append({"type": "PARKING_POSITION_UNSUPPORTED", "description": "Parking position is not supported."})

    elif scenario_name == "unknown-enum":
        # Forward-compatibility check: the API documents "clients must
        # tolerate values they do not recognize" - these are deliberately
        # not in any bullet list in openapi.json.
        vehicle["status"]["overall"]["doorsLocked"] = "PARTIALLY_SECURED"
        vehicle["charging"]["status"]["state"] = "PRECONDITIONING_BATTERY"
        vehicle["airConditioning"]["state"] = "DEFROSTING"

    return vehicle, errors
