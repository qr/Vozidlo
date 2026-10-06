"""A tiny, offline, dependency-free JSON Schema validator.

We deliberately do not pull in a `jsonschema` package: the task calls for the
standard library plus pytest, and the subset of JSON Schema this OpenAPI
document actually uses (object/array/string/integer/number/boolean, $ref,
required, enum, minimum/maximum, minLength/maxLength) is small enough to
implement directly. This keeps the contract test (US-052) runnable fully
offline with no extra dependency to vendor or trust.

Not a general-purpose validator: it supports exactly what
mock/openapi.json needs and nothing more.
"""
from __future__ import annotations

import re
from typing import Any


class SchemaError(Exception):
    """Raised with a human-readable path to the first violation found."""

    def __init__(self, message: str, path: str = "$"):
        super().__init__(message)
        self.path = path
        self.message = message


def resolve(schema: dict, spec: dict) -> dict:
    """Follow a single '$ref' pointer into components/schemas."""
    if "$ref" in schema:
        ref = schema["$ref"]
        assert ref.startswith("#/"), f"only local refs are supported, got {ref}"
        node: Any = spec
        for part in ref[2:].split("/"):
            node = node[part]
        return node
    return schema


_JSON_TYPES = {
    "object": dict,
    "array": list,
    "string": str,
    "boolean": bool,
    "integer": int,
    "number": (int, float),
    "null": type(None),
}


def validate(instance: Any, schema: dict, spec: dict, path: str = "$") -> None:
    """Raise SchemaError if `instance` does not conform to `schema`.

    `spec` is the full OpenAPI document, used to resolve $ref.
    """
    schema = resolve(schema, spec)

    declared = schema.get("type")
    if declared is not None:
        types = declared if isinstance(declared, list) else [declared]
        # bool is a subclass of int in Python; only accept it for "boolean".
        ok = False
        for t in types:
            py = _JSON_TYPES.get(t)
            if py is None:
                continue
            if t == "integer" and isinstance(instance, bool):
                continue
            if t != "boolean" and isinstance(instance, bool):
                continue
            if isinstance(instance, py):
                ok = True
                break
        if not ok:
            raise SchemaError(f"{path}: expected type {types}, got {type(instance).__name__} ({instance!r})", path)

    if "enum" in schema and instance not in schema["enum"]:
        raise SchemaError(f"{path}: {instance!r} is not one of {schema['enum']}", path)

    if isinstance(instance, str):
        if "minLength" in schema and len(instance) < schema["minLength"]:
            raise SchemaError(f"{path}: string shorter than minLength {schema['minLength']}", path)
        if "maxLength" in schema and len(instance) > schema["maxLength"]:
            raise SchemaError(f"{path}: string longer than maxLength {schema['maxLength']}", path)
        if "pattern" in schema and not re.search(schema["pattern"], instance):
            raise SchemaError(f"{path}: {instance!r} does not match pattern {schema['pattern']!r}", path)

    if isinstance(instance, (int, float)) and not isinstance(instance, bool):
        if "minimum" in schema and instance < schema["minimum"]:
            raise SchemaError(f"{path}: {instance} < minimum {schema['minimum']}", path)
        if "maximum" in schema and instance > schema["maximum"]:
            raise SchemaError(f"{path}: {instance} > maximum {schema['maximum']}", path)

    if isinstance(instance, dict):
        for req in schema.get("required", []):
            if req not in instance:
                raise SchemaError(f"{path}: missing required property {req!r}", f"{path}.{req}")
        properties = schema.get("properties", {})
        for key, value in instance.items():
            if key in properties:
                validate(value, properties[key], spec, f"{path}.{key}")
            # additionalProperties: not constrained here - the real API's own
            # schema does not set additionalProperties: false anywhere, and
            # forward-compatible clients must tolerate unknown fields too.

    if isinstance(instance, list):
        items_schema = schema.get("items")
        if items_schema is not None:
            for i, item in enumerate(instance):
                validate(item, items_schema, spec, f"{path}[{i}]")


def enum_values_from_description(description: str) -> list[str]:
    """Extract a bullet-point enum list from an OpenAPI description string.

    Škoda's spec documents allowed values as prose bullets inside
    `description`, e.g. "Possible values are: * MANUAL * TIMER ...", rather
    than a formal `enum:` array (the API is explicitly forward-compatible:
    "clients must tolerate values they do not recognize"). The mock derives
    its allowed-value lists for request validation from this same text, so
    it never hand-duplicates a list that could drift from the spec.
    """
    return re.findall(r"\*\s+([A-Z][A-Z0-9_]*)", description or "")
