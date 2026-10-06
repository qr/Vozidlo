"""US-050: every failure and edge case the scenario switch promises.

Each test sets its scenario via the per-request `X-Mock-Scenario` header
(see LiveMock.request), so tests never depend on each other's global state -
the autouse `reset_scenario` fixture in conftest.py also resets the global
default between tests as a second safety net.
"""
from __future__ import annotations

import json

import pytest


# ---------------------------------------------------------------------------
# Error scenarios: exact status + distinguishing 'type'
# ---------------------------------------------------------------------------
@pytest.mark.parametrize(
    "scenario,expected_status,expected_type_suffix",
    [
        ("api-key-expired", 401, "api-key-expired"),
        ("api-key-not-authorized", 403, "api-key-not-authorized"),
        ("rate-limit-exceeded", 429, "rate-limit-exceeded"),
        ("vehicle-not-accepting-requests", 429, "vehicle-not-accepting-requests"),
        ("500", 500, None),
        ("503", 503, None),
        ("504", 504, None),
        ("vehicle-not-found", 404, None),
    ],
)
def test_error_scenario_on_read(live_mock, vin, scenario, expected_status, expected_type_suffix):
    status, headers, body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}", scenario=scenario
    )
    assert status == expected_status
    assert headers["Content-Type"] == "application/problem+json"
    payload = json.loads(body)
    assert payload["status"] == expected_status
    if expected_type_suffix:
        assert payload["type"].endswith(expected_type_suffix)


def test_rate_limit_exceeded_has_retry_after(live_mock, vin):
    status, headers, _body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}", scenario="rate-limit-exceeded"
    )
    assert status == 429
    assert "Retry-After" in headers


def test_rate_limit_exceeded_and_vehicle_not_accepting_are_distinguished_by_type(live_mock, vin):
    _s1, _h1, b1 = live_mock.request("GET", f"/api/v1/vehicles/{vin}", scenario="rate-limit-exceeded")
    _s2, _h2, b2 = live_mock.request("GET", f"/api/v1/vehicles/{vin}", scenario="vehicle-not-accepting-requests")
    type1 = json.loads(b1)["type"]
    type2 = json.loads(b2)["type"]
    assert type1 != type2
    assert type1.endswith("rate-limit-exceeded")
    assert type2.endswith("vehicle-not-accepting-requests")


@pytest.mark.parametrize("scenario,expected_type_suffix", [
    ("operation-not-supported", "operation-not-supported"),
    ("operation-disabled", "operation-disabled"),
])
def test_command_only_error_scenarios(live_mock, vin, scenario, expected_type_suffix):
    status, _headers, body = live_mock.request(
        "POST", f"/api/v1/vehicles/{vin}/charging/start", scenario=scenario
    )
    assert status == 422
    payload = json.loads(body)
    assert payload["type"].endswith(expected_type_suffix)


# ---------------------------------------------------------------------------
# Shape scenarios: a 200 that looks different, not an error
# ---------------------------------------------------------------------------
def test_partial_data_is_200_with_populated_errors(live_mock, vin):
    status, _headers, body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}", scenario="partial-data"
    )
    assert status == 200
    payload = json.loads(body)
    assert payload["errors"]  # non-empty
    assert "charging" not in payload["vehicle"]


def test_in_motion_has_no_coordinates(live_mock, vin):
    status, _headers, body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}", scenario="in-motion"
    )
    assert status == 200
    pos = json.loads(body)["vehicle"]["parkingPosition"]
    assert pos["state"] == "IN_MOTION"
    assert "gpsCoordinates" not in pos
    assert "formattedAddress" not in pos


def test_stale_airconditioning_is_17_hours_old(live_mock, vin):
    import datetime

    status, _headers, body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}", scenario="stale-airconditioning-17h"
    )
    assert status == 200
    vehicle = json.loads(body)["vehicle"]
    ts = vehicle["airConditioning"]["carCapturedTimestamp"]
    captured = datetime.datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc)
    age_hours = (datetime.datetime.now(datetime.timezone.utc) - captured).total_seconds() / 3600
    assert 16.9 < age_hours < 17.1

    # Other sections stay fresh - the age divergence is per-section, not global.
    status_ts = vehicle["status"]["carCapturedTimestamp"]
    status_captured = datetime.datetime.strptime(status_ts, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc)
    status_age_minutes = (datetime.datetime.now(datetime.timezone.utc) - status_captured).total_seconds() / 60
    assert status_age_minutes < 60


def test_quota_nearly_spent_reports_low_remaining(live_mock, vin):
    status, headers, _body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}", scenario="quota-nearly-spent"
    )
    assert status == 200
    assert int(headers["RateLimit-Remaining"]) <= 1


def test_charging_active(live_mock, vin):
    status, _headers, body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}", scenario="charging-active"
    )
    assert status == 200
    charging = json.loads(body)["vehicle"]["charging"]["status"]
    assert charging["state"] == "CHARGING"
    assert charging["chargeType"] in ("AC", "DC")


def test_connect_cable(live_mock, vin):
    status, _headers, body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}", scenario="connect-cable"
    )
    assert status == 200
    assert json.loads(body)["vehicle"]["charging"]["status"]["state"] == "CONNECT_CABLE"


def test_empty_charge_modes(live_mock, vin):
    status, _headers, body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}", scenario="empty-charge-modes"
    )
    assert status == 200
    assert json.loads(body)["vehicle"]["charging"]["settings"]["availableChargeModes"] == []


def test_charging_profiles_present_when_requested(live_mock, vin):
    status, _headers, body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}", scenario="charging-profiles"
    )
    assert status == 200
    profiles = json.loads(body)["vehicle"]["chargingProfiles"]["profiles"]
    assert len(profiles) >= 1
    assert profiles[0]["id"]
    assert profiles[0]["name"]


def test_parked_with_address(live_mock, vin):
    status, _headers, body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}", scenario="parked-with-address"
    )
    assert status == 200
    pos = json.loads(body)["vehicle"]["parkingPosition"]
    assert pos["state"] == "PARKED"
    assert "formattedAddress" in pos
    assert "gpsCoordinates" in pos


def test_parked_no_address(live_mock, vin):
    status, _headers, body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}", scenario="parked-no-address"
    )
    assert status == 200
    pos = json.loads(body)["vehicle"]["parkingPosition"]
    assert pos["state"] == "PARKED"
    assert "gpsCoordinates" in pos
    assert "formattedAddress" not in pos


def test_parking_position_unsupported(live_mock, vin):
    status, _headers, body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}", scenario="parking-position-unsupported"
    )
    assert status == 200
    payload = json.loads(body)
    assert "parkingPosition" not in payload["vehicle"]
    assert any(e["type"] == "PARKING_POSITION_UNSUPPORTED" for e in payload["errors"])


def test_expires_in_20_days(live_mock, vin):
    import datetime

    status, headers, _body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}", scenario="expires-in-20-days"
    )
    assert status == 200
    expires = datetime.datetime.strptime(
        headers["X-API-Key-Expires-At"], "%Y-%m-%dT%H:%M:%S.%fZ"
    ).replace(tzinfo=datetime.timezone.utc)
    days_left = (expires - datetime.datetime.now(datetime.timezone.utc)).total_seconds() / 86400
    assert 19 < days_left < 21


def test_unknown_enum_values_are_still_valid_json(live_mock, vin):
    """The API is explicitly forward-compatible ('clients must tolerate
    values they do not recognize'); this scenario exercises that a
    not-yet-documented enum value still comes back as an ordinary string,
    not something that breaks the response.
    """
    status, _headers, body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}", scenario="unknown-enum"
    )
    assert status == 200
    vehicle = json.loads(body)["vehicle"]
    assert isinstance(vehicle["status"]["overall"]["doorsLocked"], str)
    assert vehicle["status"]["overall"]["doorsLocked"] not in ("YES", "NO", "OPENED", "TRUNK_OPENED", "UNKNOWN")


# ---------------------------------------------------------------------------
# Switching without a restart, and the control endpoint itself
# ---------------------------------------------------------------------------
def test_scenario_switches_without_restart_via_control_endpoint(live_mock, vin):
    status, _h, body = live_mock.request(
        "POST", "/_mock/scenario", body={"scenario": "api-key-expired"}
    )
    assert status == 200
    assert json.loads(body)["scenario"] == "api-key-expired"

    status, _h, body = live_mock.request("GET", f"/api/v1/vehicles/{vin}")
    assert status == 401
    assert json.loads(body)["type"].endswith("api-key-expired")

    # restore
    status, _h, _body = live_mock.request("POST", "/_mock/scenario", body={"scenario": "default"})
    assert status == 200
    status, _h, _body = live_mock.request("GET", f"/api/v1/vehicles/{vin}")
    assert status == 200


def test_per_request_scenario_override_does_not_change_global_state(live_mock, vin):
    status, _h, body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}", scenario="api-key-expired"
    )
    assert status == 401

    # No global switch happened - the very next request without an override
    # is back to default.
    status, _h, _body = live_mock.request("GET", f"/api/v1/vehicles/{vin}")
    assert status == 200


def test_unknown_scenario_name_is_rejected_by_control_endpoint(live_mock):
    status, _h, body = live_mock.request(
        "POST", "/_mock/scenario", body={"scenario": "not-a-real-scenario"}
    )
    assert status == 400
    assert "not-a-real-scenario" in json.loads(body)["error"]
