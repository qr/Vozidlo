"""US-048: the mock must reject everything the real server rejects.

One test per strictness rule in mock/README.md, plus two named
regression tests for the exact two bugs task 2 exists because of.
"""
from __future__ import annotations

import json


# ---------------------------------------------------------------------------
# 401 before routing
# ---------------------------------------------------------------------------
def test_missing_api_key_returns_401(live_mock, vin):
    status, headers, body = live_mock.request("GET", f"/api/v1/vehicles/{vin}", api_key=None)
    assert status == 401
    assert headers["Content-Type"] == "application/problem+json"
    payload = json.loads(body)
    assert payload["status"] == 401
    assert payload["detail"] == "Missing or invalid API key."


def test_blank_api_key_returns_401(live_mock, vin):
    status, _headers, _body = live_mock.request("GET", f"/api/v1/vehicles/{vin}", api_key="   ")
    assert status == 401


def test_401_happens_before_the_path_is_even_checked(live_mock):
    """The defining rule (US-048): a missing key returns 401 even for a path
    that would otherwise 404. This is exactly why the first shipped URL bug
    survived testing with a dummy key - the request never reached routing.
    """
    status, _headers, body = live_mock.request(
        "GET", "/this/path/matches/no/route/at/all", api_key=None
    )
    assert status == 401
    payload = json.loads(body)
    assert payload["detail"] == "Missing or invalid API key."
    # Not the 404 "No static resource" body - proves auth ran first.
    assert "static resource" not in payload["detail"]


# ---------------------------------------------------------------------------
# Exact path matching -> 404 "No static resource ..."
# ---------------------------------------------------------------------------
def test_unknown_path_returns_404_with_skoda_wording(live_mock):
    status, headers, body = live_mock.request("GET", "/api/v1/nonsense")
    assert status == 404
    assert headers["Content-Type"] == "application/problem+json"
    payload = json.loads(body)
    assert payload["type"] == "about:blank"
    assert payload["title"] == "Not Found"
    assert payload["status"] == 404
    assert payload["detail"] == "No static resource api/v1/nonsense."


def test_wrong_vin_length_returns_404(live_mock):
    status, _headers, _body = live_mock.request("GET", "/api/v1/vehicles/TOOSHORT")
    assert status == 404


def test_vin_one_character_too_long_returns_404(live_mock, vin):
    status, _headers, _body = live_mock.request("GET", f"/api/v1/vehicles/{vin}X")
    assert status == 404


# ---------------------------------------------------------------------------
# Wrong method -> 405
# ---------------------------------------------------------------------------
def test_wrong_method_returns_405(live_mock, vin):
    status, _headers, _body = live_mock.request("DELETE", f"/api/v1/vehicles/{vin}")
    assert status == 405


def test_get_on_a_command_endpoint_returns_405(live_mock, vin):
    status, _headers, _body = live_mock.request("GET", f"/api/v1/vehicles/{vin}/charging/start")
    assert status == 405


# ---------------------------------------------------------------------------
# 400 on a schema-violating request
# ---------------------------------------------------------------------------
def test_400_on_unknown_charge_mode_has_extension_members(live_mock, vin):
    status, headers, body = live_mock.request(
        "PUT", f"/api/v1/vehicles/{vin}/charging/mode",
        body={"chargeMode": "WARP_SPEED"},
    )
    assert status == 400
    assert headers["Content-Type"] == "application/problem+json"
    payload = json.loads(body)
    assert payload["parameter"] == "chargeMode"
    assert payload["rejectedValue"] == "WARP_SPEED"
    assert "MANUAL" in payload["allowedValues"]


def test_400_on_charging_limit_not_a_multiple_of_ten(live_mock, vin):
    status, _headers, body = live_mock.request(
        "PUT", f"/api/v1/vehicles/{vin}/charging/limit",
        body={"targetStateOfChargeInPercent": 55},
    )
    assert status == 400
    payload = json.loads(body)
    assert payload["parameter"] == "targetStateOfChargeInPercent"
    assert payload["rejectedValue"] == 55
    assert payload["allowedValues"] == [50, 60, 70, 80, 90, 100]


def test_400_on_missing_required_body(live_mock, vin):
    status, _headers, body = live_mock.request(
        "POST", f"/api/v1/vehicles/{vin}/air-conditioning/start",
    )
    assert status == 400
    payload = json.loads(body)
    assert payload["parameter"] == "body"


def test_400_on_unknown_include_value(live_mock, vin):
    status, _headers, body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}?include=warpDrive",
    )
    assert status == 400
    payload = json.loads(body)
    assert payload["parameter"] == "include"
    assert payload["rejectedValue"] == "warpDrive"
    assert "status" in payload["allowedValues"]


def test_400_on_malformed_json_body(live_mock, vin):
    # no body at all is "missing required body", covered separately above;
    # this checks a body that IS present but is not valid JSON.
    status, _headers, body = live_mock.request(
        "PUT", f"/api/v1/vehicles/{vin}/charging/mode",
        raw_body=b"{not json",
        headers={"Content-Type": "application/json"},
    )
    assert status == 400
    payload = json.loads(body)
    assert payload["parameter"] == "body"


# ---------------------------------------------------------------------------
# Named regression tests for the two bugs task 2 exists because of
# ---------------------------------------------------------------------------
def test_regression_missing_vehicles_path_segment_returns_404(live_mock, vin):
    """Regression test for the first shipped bug: the base URL ends at
    /api/v1 and the VIN was appended directly, skipping the required
    /vehicles/ segment. The mock must 404 this exactly as the real API does.
    """
    status, headers, body = live_mock.request("GET", f"/api/v1/{vin}")
    assert status == 404
    assert headers["Content-Type"] == "application/problem+json"
    payload = json.loads(body)
    assert payload["detail"] == f"No static resource api/v1/{vin}."

    # Positive control: the correct URL (with /vehicles/) succeeds, proving
    # this test would actually have caught the bug rather than passing for
    # an unrelated reason.
    ok_status, _h, _b = live_mock.request("GET", f"/api/v1/vehicles/{vin}")
    assert ok_status == 200


def test_regression_trailing_slash_before_query_string_returns_404(live_mock, vin):
    """Regression test for the second shipped bug: a trailing slash was
    inserted before the '?' when a query string was appended
    (.../vehicles/{vin}/?include=...  instead of  .../vehicles/{vin}?include=...).
    The real API 404s this; a mock that normalises it away is worse than no
    mock, because it hides exactly this bug.
    """
    status, headers, body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}/?include=status"
    )
    assert status == 404
    payload = json.loads(body)
    assert payload["detail"] == f"No static resource api/v1/vehicles/{vin}/."

    # Positive control: no slash before '?' succeeds.
    ok_status, _h, _b = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}?include=status"
    )
    assert ok_status == 200
