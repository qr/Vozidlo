"""Derives the mock's route table from the vendored OpenAPI document.

US-047 requires routes, methods, required bodies and response shapes to come
*from* mock/openapi.json rather than being hand-written a second time in
Python. This module is the single place that reads the spec; server.py only
ever consults the `Route` objects it produces. Refreshing openapi.json (see
README.md) changes routing and validation automatically, and a `git diff`
against openapi.json is the visible record of what changed.
"""
from __future__ import annotations

import json
import os
import re
from dataclasses import dataclass, field
from typing import Any

SPEC_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "openapi.json")

# Commands (POST/PUT that mutate the vehicle) answer 202 with an empty body.
# The spec marks these by *not* declaring a 200 response for them at all -
# their only success code is 202 - so "is this a command" is derived, not
# hand-listed.


@dataclass
class Route:
    method: str
    template: str                    # e.g. /api/v1/vehicles/{vin}/charging/mode
    regex: "re.Pattern[str]"
    operation_id: str
    path_params: list[str]
    success_status: int              # 200 for the read, 202 for every command
    request_body_schema: dict | None  # resolved (still may contain $ref inside)
    request_body_required: bool
    responses: dict[str, Any]        # status code (as string) -> response object
    query_params: dict[str, Any]     # name -> parameter object (schema etc.)


def _compile(template: str) -> "re.Pattern[str]":
    # Turn "/api/v1/vehicles/{vin}/charging/mode" into a regex with named
    # groups, each matching one path segment (no slashes) - exact match only,
    # anchored on both ends so a trailing slash or extra segment never matches.
    parts = []
    for literal, param in re.findall(r"([^{}]*)(\{[^{}]*\})?", template):
        if literal:
            parts.append(re.escape(literal))
        if param:
            name = param[1:-1]
            parts.append(f"(?P<{name}>[^/]+)")
    pattern = "^" + "".join(parts) + "$"
    return re.compile(pattern)


def load_spec() -> dict:
    with open(SPEC_PATH, "r", encoding="utf-8") as fh:
        return json.load(fh)


def build_routes(spec: dict) -> list[Route]:
    routes: list[Route] = []
    for template, methods in spec["paths"].items():
        for method, op in methods.items():
            if method not in ("get", "post", "put", "delete", "patch"):
                continue  # skip 'parameters' and other non-method keys
            responses = op.get("responses", {})
            success_codes = [c for c in responses if c.startswith("2")]
            # Exactly one 2xx per operation in this API: 200 for the read,
            # 202 for every command.
            success_status = int(success_codes[0]) if success_codes else 200

            body = op.get("requestBody")
            body_schema = None
            body_required = False
            if body:
                body_required = bool(body.get("required", False))
                content = body.get("content", {})
                json_content = content.get("application/json")
                if json_content:
                    body_schema = json_content.get("schema")

            path_params = [
                p["name"] for p in op.get("parameters", []) if p.get("in") == "path"
            ]
            query_params = {
                p["name"]: p for p in op.get("parameters", []) if p.get("in") == "query"
            }

            routes.append(
                Route(
                    method=method.upper(),
                    template=template,
                    regex=_compile(template),
                    operation_id=op.get("operationId", f"{method}:{template}"),
                    path_params=path_params,
                    success_status=success_status,
                    request_body_schema=body_schema,
                    request_body_required=body_required,
                    responses=responses,
                    query_params=query_params,
                )
            )
    return routes


def is_command(route: Route) -> bool:
    """A command endpoint is any non-GET route: it answers 202, empty body."""
    return route.method != "GET"
