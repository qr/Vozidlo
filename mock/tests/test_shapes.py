"""US-049: the mock's response shapes must be byte-faithful to what was
actually measured against the real API - not merely "plausible".
"""
from __future__ import annotations

import json


def test_command_202_has_empty_body_and_no_content_type_header(live_mock, vin):
    """The measured shape (feasibility study §A.2): a real
    air-conditioning/stop returned 202, content-length: 0, and NO
    content-type header at all. That exact combination is what makes
    Connect IQ return -400 when :responseType is set - see task 4. A mock
    that adds a Content-Type "to be helpful" would make that bug
    untestable.
    """
    status, headers, body = live_mock.request(
        "POST", f"/api/v1/vehicles/{vin}/air-conditioning/stop"
    )
    assert status == 202
    assert body == b""
    assert "Content-Type" not in headers
    assert headers["Content-Length"] == "0"


def test_every_command_endpoint_has_the_202_shape(live_mock, vin):
    no_body_commands = [
        f"/api/v1/vehicles/{vin}/air-conditioning/stop",
        f"/api/v1/vehicles/{vin}/charging/start",
        f"/api/v1/vehicles/{vin}/charging/stop",
        f"/api/v1/vehicles/{vin}/active-ventilation/start",
        f"/api/v1/vehicles/{vin}/active-ventilation/stop",
        f"/api/v1/vehicles/{vin}/auxiliary-heating/stop",
    ]
    for path in no_body_commands:
        status, headers, body = live_mock.request("POST", path)
        assert status == 202, path
        assert body == b"", path
        assert "Content-Type" not in headers, path


def test_bodiless_commands_accept_an_empty_json_object(live_mock, vin):
    """The app sends `{}` where Škoda defines no body: Garmin Connect on
    Android does not send a JSON POST with a null body (the watch gets
    responseCode 0 and nothing goes out, measured 2026-10-08). The real API
    answers `{}` on air-conditioning/stop with the same 202; the mock must
    too, or the app's own requests would fail against it.
    """
    for op in ("air-conditioning/stop", "charging/start", "charging/stop",
               "active-ventilation/start", "active-ventilation/stop",
               "auxiliary-heating/stop"):
        path = f"/api/v1/vehicles/{vin}/{op}"
        status, headers, body = live_mock.request("POST", path, body={})
        assert status == 202, path
        assert body == b"", path


def test_errors_are_problem_json_with_required_fields(live_mock):
    status, headers, body = live_mock.request("GET", "/api/v1/nonsense")
    assert status == 404
    assert headers["Content-Type"] == "application/problem+json"
    payload = json.loads(body)
    for field in ("type", "title", "status", "detail", "instance"):
        assert field in payload, field


def test_successful_read_is_application_json(live_mock, vin):
    status, headers, body = live_mock.request("GET", f"/api/v1/vehicles/{vin}")
    assert status == 200
    assert headers["Content-Type"] == "application/json"
    json.loads(body)  # parses cleanly


def test_successful_read_carries_key_expiry_and_rate_limit_headers(live_mock, vin):
    status, headers, _body = live_mock.request("GET", f"/api/v1/vehicles/{vin}")
    assert status == 200
    assert "X-API-Key-Expires-At" in headers
    # ISO 8601 with milliseconds and a literal Z, as measured.
    import re
    assert re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$", headers["X-API-Key-Expires-At"])
    assert headers["RateLimit-Limit"] == "20"
    assert "RateLimit-Remaining" in headers
    assert "RateLimit-Reset" in headers


def test_include_of_an_unsupported_section_reports_unsupported_error(live_mock, vin):
    """auxiliaryHeating is genuinely absent for the default plug-in hybrid.
    Explicitly requesting it via `include` must report it in errors[]
    (silent omission is only for when `include` is not given at all).
    """
    status, _headers, body = live_mock.request(
        "GET", f"/api/v1/vehicles/{vin}?include=auxiliaryHeating,status"
    )
    assert status == 200
    payload = json.loads(body)
    assert "auxiliaryHeating" not in payload["vehicle"]
    assert any(e["type"] == "AUXILIARY_HEATING_UNSUPPORTED" for e in payload["errors"])
    assert "status" in payload["vehicle"]


def test_successful_command_carries_key_expiry_and_rate_limit_headers(live_mock, vin):
    status, headers, _body = live_mock.request(
        "POST", f"/api/v1/vehicles/{vin}/charging/start"
    )
    assert status == 202
    assert "X-API-Key-Expires-At" in headers
    assert headers["RateLimit-Limit"] == "20"
    assert "RateLimit-Remaining" in headers
    assert "RateLimit-Reset" in headers
