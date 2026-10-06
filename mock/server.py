#!/usr/bin/env python3
"""Mock server for the MyŠkoda Public API.

A strict stand-in for https://public.api.connect.skoda-auto.cz/api/v1,
derived from the vendored OpenAPI document (mock/openapi.json). Strict on
purpose: US-048 exists because a permissive mock let two URL bugs through to
the real API. See README.md for the full design and the scenario switch.

Usage: normally started via ./run.sh, not invoked directly. Run directly for
development:

    python3 server.py --scenario default --log-requests
"""
from __future__ import annotations

import argparse
import datetime as _dt
import http.server
import json
import os
import re
import ssl
import sys
import threading
import urllib.parse
from typing import Any

import jsonschema_lite
import scenarios
import spec as spec_module
import tls_setup
from vehicle_data import MOCK_VIN, iso, now

DEFAULT_HTTPS_PORT = 8792  # matches tools/ciq's MOCK_PORT
DEFAULT_HTTP_PORT = 8793

SPEC = spec_module.load_spec()
ROUTES = spec_module.build_routes(SPEC)

_GET_ROUTE = next(r for r in ROUTES if r.method == "GET")
_INCLUDE_PARAM = _GET_ROUTE.query_params.get("include", {})
INCLUDE_ENUM: list[str] = (
    _INCLUDE_PARAM.get("schema", {}).get("items", {}).get("enum", [])
)
_INFO_FIELDS = {"name", "licensePlate", "renderUrl"}

# `include` value -> VehicleError.type prefix, taken from the bullet list in
# that schema's description in openapi.json (component schemas -> VehicleError).
_INCLUDE_TO_ERROR_PREFIX = {
    "status": "VEHICLE_STATUS",
    "fuelStatus": "FUEL_STATUS",
    "odometer": "ODOMETER",
    "parkingPosition": "PARKING_POSITION",
    "airConditioning": "AIR_CONDITIONING",
    "auxiliaryHeating": "AUXILIARY_HEATING",
    "activeVentilation": "ACTIVE_VENTILATION",
    "charging": "CHARGING",
    "chargingProfiles": "CHARGING_PROFILES",
}

_STEP_RANGE_RE = re.compile(r"between (\d+) and (\d+) in steps of (\d+)")


# ---------------------------------------------------------------------------
# Quota: a per-process approximation of the real one-hour rolling window
# ("RateLimit-Limit: 20" on the first request of the hour, counting down).
# Purely cosmetic for the mock - it never blocks a request on its own; the
# 'rate-limit-exceeded' scenario is the deliberate way to see a 429.
# ---------------------------------------------------------------------------
class Quota:
    def __init__(self, limit: int = 20):
        self.limit = limit
        self._remaining = limit
        self._window_start: _dt.datetime | None = None
        self._lock = threading.Lock()

    def consume(self) -> tuple[int, int, int]:
        with self._lock:
            n = now()
            if self._window_start is None or (n - self._window_start).total_seconds() >= 3600:
                self._window_start = n
                self._remaining = self.limit
            self._remaining = max(0, self._remaining - 1)
            reset = int(3600 - (n - self._window_start).total_seconds())
            return self.limit, self._remaining, max(reset, 0)


QUOTA = Quota()


# ---------------------------------------------------------------------------
# Request body validation, derived from openapi.json rather than
# hand-written per endpoint: any property whose schema description
# documents an allowed-values bullet list, or a "between X and Y in steps of
# Z" numeric rule, is checked against that same text.
# ---------------------------------------------------------------------------
def _semantic_violation(instance: dict, schema: dict, path_prefix: str = ""):
    """Returns (parameter, rejectedValue, allowedValues) for the first
    documented-but-violated value found, walking one level of nesting deep
    (enough for this API's request bodies), or None if none found."""
    schema = jsonschema_lite.resolve(schema, SPEC)
    properties = schema.get("properties", {})
    for key, value in instance.items():
        prop_schema = properties.get(key)
        if prop_schema is None:
            continue
        prop_schema = jsonschema_lite.resolve(prop_schema, SPEC)
        full_path = f"{path_prefix}{key}"
        description = prop_schema.get("description", "")

        if isinstance(value, str):
            allowed = jsonschema_lite.enum_values_from_description(description)
            if allowed and value not in allowed:
                return full_path, value, allowed

        if isinstance(value, (int, float)) and not isinstance(value, bool):
            m = _STEP_RANGE_RE.search(description)
            if m:
                lo, hi, step = (int(m.group(i)) for i in (1, 2, 3))
                allowed = list(range(lo, hi + 1, step))
                if value not in allowed:
                    return full_path, value, allowed

        if isinstance(value, dict):
            nested = _semantic_violation(value, prop_schema, f"{full_path}.")
            if nested:
                return nested

    return None


# ---------------------------------------------------------------------------
# HTTP handler
# ---------------------------------------------------------------------------
class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "SkodaConnectMock/1.0"

    # -- dispatch --------------------------------------------------------
    def do_GET(self):
        self._handle("GET")

    def do_POST(self):
        self._handle("POST")

    def do_PUT(self):
        self._handle("PUT")

    def do_DELETE(self):
        self._handle("DELETE")

    def do_PATCH(self):
        self._handle("PATCH")

    def log_message(self, fmt, *args):
        if getattr(self.server, "log_requests", False):
            sys.stderr.write("[mock] %s %s\n" % (self.address_string(), fmt % args))

    # -- top-level flow ----------------------------------------------------
    def _handle(self, method: str):
        try:
            self._handle_inner(method)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def _handle_inner(self, method: str):
        parsed = urllib.parse.urlsplit(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query, keep_blank_values=True)

        if path.startswith("/_mock/"):
            self._handle_control(method, path, query)
            return

        # --- 1. Authenticate before any routing decision (US-048). ---
        # A missing/blank key never reveals whether the URL is right - this
        # ordering is exactly what let the first shipped URL bug through
        # testing with a dummy key.
        api_key = self.headers.get("X-API-Key")
        if api_key is None or not api_key.strip():
            self._send_problem(
                401, "about:blank", "Unauthorized",
                "Missing or invalid API key.", path,
            )
            return

        # --- 2. Exact route matching. ---
        matched_any_method = [r for r in ROUTES if r.regex.match(path)]
        if not matched_any_method:
            self._not_static_resource(path)
            return

        # VIN strictness: every route here has {vin} as its first path
        # segment. A VIN that isn't exactly 17 characters is treated the
        # same as an unmatched route - it is not a well-formed request URL.
        m0 = matched_any_method[0].regex.match(path)
        if "vin" in m0.groupdict() and len(m0.group("vin")) != 17:
            self._not_static_resource(path)
            return

        matched_route = next((r for r in matched_any_method if r.method == method), None)
        if matched_route is None:
            allowed = sorted({r.method for r in matched_any_method})
            self._method_not_allowed(path, allowed)
            return

        route = matched_route
        path_params = route.regex.match(path).groupdict()
        vin = path_params.get("vin", MOCK_VIN)

        length = int(self.headers.get("Content-Length") or 0)
        raw_body = self.rfile.read(length) if length else b""

        scenario_name, ages = self._resolve_scenario(query)
        is_command = spec_module.is_command(route)
        ctx = scenarios.ScenarioContext(vin=vin, method=method, is_command=is_command)

        # --- 3. Scenario-driven error, if any (business layer). ---
        err = scenarios.error_for(scenario_name, ctx)
        if err is not None:
            self._scenario_error(err)
            return

        # --- 4. Normal handling. ---
        if route.method == "GET":
            self._handle_get(vin, query, scenario_name, ages)
        else:
            self._handle_command(route, vin, raw_body, scenario_name)

    # -- GET -----------------------------------------------------------
    def _handle_get(self, vin: str, query: dict, scenario_name: str, ages: dict):
        include_values = None
        if "include" in query:
            raw = query["include"][0]
            include_values = [v for v in raw.split(",") if v]
            bad = [v for v in include_values if v not in INCLUDE_ENUM]
            if bad:
                self._bad_request(
                    parameter="include", rejected_value=raw,
                    allowed_values=INCLUDE_ENUM, instance=f"/api/v1/vehicles/{vin}",
                )
                return

        vehicle, errors = scenarios.build_vehicle(vin, scenario_name, ages)
        if include_values is not None:
            vehicle, unsupported_errors = self._apply_include(vehicle, include_values)
            errors = errors + unsupported_errors

        headers = self._success_headers(scenario_name)
        self._send_json(200, {"vehicle": vehicle, "errors": errors}, "application/json", headers)

    @staticmethod
    def _apply_include(vehicle: dict, include_values: list[str]) -> tuple[dict, list]:
        keep = {"vin"}
        # Per the spec: a part explicitly requested via `include` that this
        # vehicle does not support is reported as a *_UNSUPPORTED error
        # rather than just silently missing (that silent-omission behaviour
        # is reserved for when `include` is omitted entirely).
        errors = []
        for v in include_values:
            keep |= _INFO_FIELDS if v == "info" else {v}
            if v not in ("info",) and v not in vehicle and v in _INCLUDE_TO_ERROR_PREFIX:
                errors.append({
                    "type": f"{_INCLUDE_TO_ERROR_PREFIX[v]}_UNSUPPORTED",
                    "description": f"{v} is not supported by this vehicle.",
                })
        filtered = {k: val for k, val in vehicle.items() if k in keep}
        return filtered, errors

    # -- commands (POST/PUT) --------------------------------------------
    def _handle_command(self, route, vin: str, raw_body: bytes, scenario_name: str):
        instance = f"/api/v1/vehicles/{vin}"
        body_json: Any = None
        if raw_body:
            try:
                body_json = json.loads(raw_body.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError):
                self._bad_request(
                    parameter="body", rejected_value=None,
                    allowed_values=["a well-formed JSON object"], instance=instance,
                )
                return

        if route.request_body_required and body_json is None:
            self._bad_request(
                parameter="body", rejected_value=None,
                allowed_values=["a JSON request body is required"], instance=instance,
            )
            return

        if body_json is not None and not isinstance(body_json, dict) and route.request_body_schema is not None:
            self._bad_request(
                parameter="body", rejected_value=body_json,
                allowed_values=["a JSON object"], instance=instance,
            )
            return

        if isinstance(body_json, dict) and route.request_body_schema is not None:
            try:
                jsonschema_lite.validate(body_json, route.request_body_schema, SPEC)
            except jsonschema_lite.SchemaError as exc:
                self._bad_request(
                    parameter=exc.path.lstrip("$.") or "body",
                    rejected_value=None, allowed_values=[exc.message], instance=instance,
                )
                return

            violation = _semantic_violation(body_json, route.request_body_schema)
            if violation:
                parameter, rejected_value, allowed_values = violation
                self._bad_request(parameter, rejected_value, allowed_values, instance)
                return

        # The measured shape: 202, empty body, NO Content-Type header at
        # all. This exact combination is what makes Connect IQ return -400
        # when :responseType is set (see task 4) - reproduce it exactly.
        headers = self._success_headers(scenario_name)
        self._send_raw(202, b"", None, headers)

    # -- mock control endpoints ------------------------------------------
    def _handle_control(self, method: str, path: str, query: dict):
        if path == "/_mock/health":
            self._send_json(200, {"status": "ok"}, "application/json")
            return

        if path == "/_mock/scenario":
            if method == "GET":
                state = scenarios.get_global()
                self._send_json(200, {
                    "scenario": state.name, "ages": state.ages_minutes,
                    "available": scenarios.ALL_SCENARIOS,
                }, "application/json")
                return
            if method == "POST":
                length = int(self.headers.get("Content-Length") or 0)
                raw = self.rfile.read(length) if length else b""
                try:
                    payload = json.loads(raw.decode("utf-8")) if raw else {}
                except (UnicodeDecodeError, json.JSONDecodeError):
                    payload = {}
                name = payload.get("scenario") or (query.get("scenario") or [None])[0] or "default"
                if name not in scenarios.ALL_SCENARIOS:
                    self._send_json(400, {
                        "error": f"unknown scenario {name!r}",
                        "available": scenarios.ALL_SCENARIOS,
                    }, "application/json")
                    return
                ages = payload.get("ages") or {}
                scenarios.set_global(name, ages)
                self._send_json(200, {"scenario": name, "ages": ages}, "application/json")
                return
            self._method_not_allowed(path, ["GET", "POST"])
            return

        self._not_static_resource(path)

    # -- scenario resolution ----------------------------------------------
    def _resolve_scenario(self, query: dict) -> tuple[str, dict]:
        header_override = self.headers.get("X-Mock-Scenario")
        query_override = (query.get("_scenario") or [None])[0]
        if header_override:
            return header_override, {}
        if query_override:
            return query_override, {}
        state = scenarios.get_global()
        return state.name, state.ages_minutes

    def _scenario_error(self, err: dict):
        retry_after = err.pop("_retryAfter", False)
        status = err["status"]
        extra_headers = {}
        if status == 429:
            extra_headers["RateLimit-Limit"] = str(QUOTA.limit)
            extra_headers["RateLimit-Remaining"] = "0"
            extra_headers["RateLimit-Reset"] = "3600"
            if retry_after:
                extra_headers["Retry-After"] = "3600"
        self._send_json(status, err, "application/problem+json", extra_headers)

    # -- header helpers ------------------------------------------------
    def _success_headers(self, scenario_name: str) -> dict:
        expires = now() + _dt.timedelta(days=180)
        if scenario_name == "expires-in-20-days":
            expires = now() + _dt.timedelta(days=20)
        limit, remaining, reset = QUOTA.consume()
        if scenario_name == "quota-nearly-spent":
            remaining = 1
        return {
            "X-API-Key-Expires-At": iso(expires),
            "RateLimit-Limit": str(limit),
            "RateLimit-Remaining": str(remaining),
            "RateLimit-Reset": str(reset),
        }

    # -- response helpers ------------------------------------------------
    def _not_static_resource(self, path: str):
        self._send_problem(404, "about:blank", "Not Found",
                            f"No static resource {path.lstrip('/')}.", path)

    def _method_not_allowed(self, path: str, allowed: list[str]):
        self._send_problem(405, "about:blank", "Method Not Allowed",
                            f"Request method '{self.command}' is not supported.", path,
                            extra_headers={"Allow": ", ".join(allowed)})

    def _bad_request(self, parameter, rejected_value, allowed_values, instance):
        body = {
            "type": "about:blank", "title": "Bad Request", "status": 400,
            "detail": f"Value for '{parameter}' was rejected.",
            "instance": instance,
            "parameter": parameter,
            "rejectedValue": rejected_value,
            "allowedValues": allowed_values,
        }
        self._send_json(400, body, "application/problem+json")

    def _send_problem(self, status, type_, title, detail, instance, extra_headers=None):
        body = {"type": type_, "title": title, "status": status, "detail": detail, "instance": instance}
        self._send_json(status, body, "application/problem+json", extra_headers)

    def _send_json(self, status, body, content_type, extra_headers=None):
        payload = json.dumps(body).encode("utf-8")
        self._send_raw(status, payload, content_type, extra_headers)

    def _send_raw(self, status, body: bytes, content_type, extra_headers=None):
        self.send_response(status)
        if content_type is not None:
            self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        for k, v in (extra_headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if body:
            self.wfile.write(body)


class MockServer(http.server.ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, *args, log_requests: bool = False, **kwargs):
        self.log_requests = log_requests
        super().__init__(*args, **kwargs)


def _serve(host: str, port: int, https: bool, tls_dir: str, log_requests: bool):
    httpd = MockServer((host, port), Handler, log_requests=log_requests)
    if https:
        cert, key, _ca = tls_setup.ensure_certs(tls_dir)
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(cert, key)
        httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
    scheme = "https" if https else "http"
    print(f"mock: listening on {scheme}://{host}:{port}", file=sys.stderr)
    httpd.serve_forever()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--https-port", type=int, default=DEFAULT_HTTPS_PORT)
    parser.add_argument("--http-port", type=int, default=DEFAULT_HTTP_PORT)
    parser.add_argument("--no-http", action="store_true", help="HTTPS only")
    parser.add_argument("--no-https", action="store_true", help="HTTP only (no TLS bootstrap)")
    parser.add_argument("--scenario", default=os.environ.get("MOCK_SCENARIO", "default"))
    parser.add_argument("--log-requests", action="store_true")
    parser.add_argument("--tls-dir", default=tls_setup.TLS_DIR)
    args = parser.parse_args(argv)

    if args.scenario not in scenarios.ALL_SCENARIOS:
        parser.error(f"unknown scenario {args.scenario!r}. Available: {', '.join(scenarios.ALL_SCENARIOS)}")
    scenarios.set_global(args.scenario)

    print(f"mock: scenario = {args.scenario}", file=sys.stderr)
    print(f"mock: default VIN = {MOCK_VIN}  (control: /_mock/scenario, /_mock/health)", file=sys.stderr)

    threads = []
    if not args.no_https:
        t = threading.Thread(
            target=_serve, args=(args.host, args.https_port, True, args.tls_dir, args.log_requests),
            daemon=True,
        )
        t.start()
        threads.append(t)
    if not args.no_http:
        t = threading.Thread(
            target=_serve, args=(args.host, args.http_port, False, args.tls_dir, args.log_requests),
            daemon=True,
        )
        t.start()
        threads.append(t)

    if not threads:
        parser.error("both --no-http and --no-https given: nothing to serve")

    try:
        while any(t.is_alive() for t in threads):
            for t in threads:
                t.join(timeout=0.5)
    except KeyboardInterrupt:
        print("\nmock: stopped", file=sys.stderr)


if __name__ == "__main__":
    main()
