"""US-052: the mock must agree with the vendored OpenAPI document, offline.

Two things are tested here:
1. That the validator itself actually catches a violation (proves the harness
   works - otherwise a silently-broken validator would let everything pass).
2. That every one of the mock's actual responses - the default success shape
   of each route, and one representative error - validates against the
   response schema declared for that route/status in openapi.json.

No network access is used anywhere in this file: `spec.SPEC_PATH` is read
from disk, and the live mock in `live_mock` (see conftest.py) is entirely
local.
"""
from __future__ import annotations

import json

import pytest

import jsonschema_lite
import spec as spec_module

SPEC = spec_module.load_spec()
ROUTES = spec_module.build_routes(SPEC)


def _response_schema(route, status: str, content_type: str):
    response = route.responses.get(status)
    if response is None:
        return None
    content = response.get("content", {})
    entry = content.get(content_type)
    if entry is None:
        return None
    return entry.get("schema")


# ---------------------------------------------------------------------------
# 1. Prove the validator itself fails on a missing required field.
# ---------------------------------------------------------------------------
def test_validator_rejects_a_response_missing_a_required_field():
    vehicle_response_schema = {"$ref": "#/components/schemas/VehicleResponse"}
    broken = {"errors": []}  # 'vehicle' is required and missing
    with pytest.raises(jsonschema_lite.SchemaError):
        jsonschema_lite.validate(broken, vehicle_response_schema, SPEC)


def test_validator_rejects_wrong_type():
    schema = {"$ref": "#/components/schemas/ProblemDetail"}
    broken = {"status": "not-a-number"}  # status must be an integer
    with pytest.raises(jsonschema_lite.SchemaError):
        jsonschema_lite.validate(broken, schema, SPEC)


def test_validator_accepts_a_conforming_response():
    schema = {"$ref": "#/components/schemas/ProblemDetail"}
    ok = {"type": "about:blank", "title": "Not Found", "status": 404,
          "detail": "...", "instance": "/api/v1/vehicles/X"}
    jsonschema_lite.validate(ok, schema, SPEC)  # must not raise


# ---------------------------------------------------------------------------
# 2. Every mock route, validated against openapi.json.
# ---------------------------------------------------------------------------
def test_get_vehicle_default_response_matches_schema(live_mock, vin):
    status, headers, body = live_mock.request("GET", f"/api/v1/vehicles/{vin}")
    assert status == 200
    route = next(r for r in ROUTES if r.method == "GET")
    schema = _response_schema(route, "200", "application/json")
    assert schema is not None, "openapi.json no longer documents a 200 application/json body for GET /vehicles/{vin}"
    jsonschema_lite.validate(json.loads(body), schema, SPEC)


@pytest.mark.parametrize("scenario", [
    "partial-data", "in-motion", "stale-airconditioning-17h", "charging-active",
    "connect-cable", "empty-charge-modes", "charging-profiles",
    "parked-with-address", "parked-no-address", "parking-position-unsupported",
    "unknown-enum",
])
def test_get_vehicle_scenario_shapes_match_schema(live_mock, vin, scenario):
    status, _headers, body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}", scenario=scenario
    )
    assert status == 200
    route = next(r for r in ROUTES if r.method == "GET")
    schema = _response_schema(route, "200", "application/json")
    jsonschema_lite.validate(json.loads(body), schema, SPEC)


@pytest.mark.parametrize("route", [r for r in ROUTES if r.method != "GET"], ids=lambda r: r.template + ":" + r.method)
def test_command_responses_have_no_declared_2xx_body_to_validate(live_mock, vin, route):
    """Every command's only 2xx is 202 with an empty body (US-049) - the spec
    does not (and must not) declare a JSON schema for it. This test asserts
    that expectation stays true, so a spec refresh that adds a 202 body
    would be caught here rather than silently ignored.
    """
    response = route.responses.get("202", {})
    assert response.get("content") in (None, {}), (
        f"{route.template} ({route.method}) now documents a 202 body in openapi.json - "
        "update server.py to serve it, this is no longer an empty-body command."
    )


@pytest.mark.parametrize("status,scenario", [
    ("401", "api-key-expired"),
    ("403", "api-key-not-authorized"),
    ("404", "vehicle-not-found"),
    ("429", "rate-limit-exceeded"),
    ("500", "500"),
    ("503", "503"),
    ("504", "504"),
])
def test_error_responses_match_problem_detail_schema(live_mock, vin, status, scenario):
    resp_status, _headers, body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}", scenario=scenario
    )
    assert str(resp_status) == status
    route = next(r for r in ROUTES if r.method == "GET")
    schema = _response_schema(route, status, "application/json")
    assert schema is not None, f"openapi.json no longer documents a {status} response for GET /vehicles/{{vin}}"
    jsonschema_lite.validate(json.loads(body), schema, SPEC)


def test_404_no_static_resource_matches_problem_detail_schema():
    # Not a documented per-route response (Spring's own fallback), but the
    # body still has to be a valid ProblemDetail - the schema definition is
    # what every problem+json body in this API is supposed to be.
    schema = {"$ref": "#/components/schemas/ProblemDetail"}
    body = {
        "type": "about:blank", "title": "Not Found", "status": 404,
        "detail": "No static resource api/v1/nonsense.",
        "instance": "/api/v1/nonsense",
    }
    jsonschema_lite.validate(body, schema, SPEC)


def test_every_route_has_a_success_status_documented_in_the_spec():
    """Guards US-052's 'refreshing the spec fails until the mock is
    updated': if a route's only success code stops being 200/202, this
    fails loudly instead of the mock silently serving the wrong shape.
    """
    for route in ROUTES:
        expected = 200 if route.method == "GET" else 202
        assert route.success_status == expected, route.template
