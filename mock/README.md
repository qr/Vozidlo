# Mock server (task 2)

A strict stand-in for `https://public.api.connect.skoda-auto.cz/api/v1`,
derived from the vendored OpenAPI document (`openapi.json`). It exists
because a permissive mock let two URL bugs reach the real API during the
feasibility spike, each costing a request from a budget of twenty per hour:
a missing `/vehicles/` path segment, and a trailing slash before a query
string. **A mock that accepts more than the real server is worse than no
mock**, because it converts a fast local failure into a slow, expensive
remote one. Every design decision below follows from that.

## Run it

```bash
mock/run.sh                    # HTTPS on :8792, HTTP on :8793, scenario "default"
mock/run.sh --scenario rate-limit-exceeded
mock/run.sh --log-requests
mock/run.sh --scenario stale-airconditioning-17h --http-port 9000
```

It prints the URLs it is listening on. On first run it generates a local CA and
server certificate into `mock/tls/`, which takes a second longer. That directory
is gitignored: certificates and keys are made on the machine that needs them and
are never committed.

```bash
curl -sk https://127.0.0.1:8792/api/v1/vehicles/AAAAAAAAAAAAAAAAA          # 401: no key, no routing
curl -sk -H 'X-API-Key: test' https://127.0.0.1:8792/api/v1/vehicles/TMBMOCKVIN0000017
```

`-k` skips certificate verification, which is fine for `curl`. The Connect IQ
simulator has no such flag: it refuses plain `http://` with
`-1001 SECURE_CONNECTION_REQUIRED` and will not talk to a certificate it does not
trust. The Dockerfile already copies `tools/tls/ca.crt` into the container trust store,
so after a first run of the mock (or any time you wipe `mock/tls/`) refresh it
and rebuild the image:

```bash
cp mock/tls/ca.crt tools/tls/ca.crt
cd tools && docker build --build-arg UID=$(id -u) --build-arg GID=$(id -g) \
    --build-arg HOME_DIR="$HOME" -t ciq:22.04 .
```

`tools/tls/ca.crt` is a public certificate, not a key, so committing it is
harmless, but it must match whatever is in `mock/tls/`, or the simulator gets
`-402 UNABLE_TO_PROCESS_MEDIA` style TLS failures with no useful detail.

The default vehicle identifies itself with VIN `TMBMOCKVIN0000017` - an
obvious placeholder, never a real VIN - and answers on that VIN or any other
syntactically valid (17-character) one.

## Pointing the app at this mock

`Endpoints.baseUrl()` reads a `MockBaseUrl` property in **debug builds only**:
the release build compiles a different function that cannot be overridden at all,
so a shipped app can never be aimed anywhere but the real API.

In the simulator: `File > Edit Persistent Storage > Application.Properties`, set
`MockBaseUrl` to `https://127.0.0.1:8792/api/v1`, then restart the app. Leave it
empty to go back to the real API.

For a throwaway run where clicking through that dialog is a nuisance (taking
screenshots, say) you can instead put the values straight into the `<property>`
defaults in `app/resources/settings/properties.xml`, build, and revert the file
afterwards. Revert it before you package: `ciq package` compiles those defaults
into the shipped settings, so a forgotten mock URL or placeholder key would go
out with the app.

**Restart the simulator afterwards as well.** Reverting the file is not enough:
the simulator has already persisted those values as app settings, and a debug
build keeps reading `MockBaseUrl` from them. The symptom is `ciq test` failing
13 `EndpointTests` that expect the production host and get `127.0.0.1:8792`,
which reads as a code regression and is not one. Killing the simulator clears
the persisted settings.

The simulator refuses a certificate it does not trust, so the toolchain container
needs our CA, see the TLS note above.

## Run the tests

```bash
python3 -m venv mock/.venv && mock/.venv/bin/pip install -r mock/requirements-dev.txt
mock/.venv/bin/python -m pytest mock/tests
```

(or `apt install python3-pytest` / however pytest is provided in your
environment, then plain `pytest mock/tests`). The server itself
(`server.py` and friends) has no dependency beyond the standard library;
pytest is only needed to run the test suite.

## Why it is strict

The mock authenticates and routes in the same order the real API does, and
rejects the same things:

- **Exact path matching.** No route match at all -> `404` with Škoda's own
  `"No static resource <path>."` wording (`application/problem+json`).
- **A trailing slash before a query string 404s.**
  `/api/v1/vehicles/{vin}/?include=x` is not the same path as
  `/api/v1/vehicles/{vin}?include=x` - this falls out naturally from exact
  regex matching, it is not special-cased.
- **A VIN that is not exactly 17 characters 404s**, the same as an unmatched
  route.
- **A wrong HTTP method on a valid path -> `405`.**
- **`401` happens before any routing decision**, when `X-API-Key` is missing
  or blank. This ordering is precisely what let the first shipped bug
  survive testing with a dummy key: the request never reached path matching,
  so a reassuring `401` told you nothing about whether the URL was right.
- **A schema-violating request body -> `400`** with extension members
  `parameter`, `rejectedValue` and `allowedValues`, derived from
  `openapi.json`'s own property descriptions rather than a second
  hand-written list (see "How validation is derived" below).

Two regression tests are named for the exact bugs that motivated this task:
`test_regression_missing_vehicles_path_segment_returns_404` and
`test_regression_trailing_slash_before_query_string_returns_404`, both in
`tests/test_strictness.py`.

## Response shapes, measured not assumed

- **Commands answer `202` with an empty body and NO `Content-Type` header at
  all.** This exact combination - `202`, `content-length: 0`, no
  `content-type` - is what makes Connect IQ return `-400` when
  `:responseType` is set on the request (see task 4). A mock that adds a
  `Content-Type` "to be helpful" would make that bug untestable.
- **Errors are `application/problem+json`** with `type`, `title`, `status`,
  `detail`, `instance`.
- **Successful reads are `application/json`.**
- **Every successful response carries `X-API-Key-Expires-At`** (ISO 8601
  with milliseconds and `Z`, e.g. `2027-03-06T07:22:01.812Z`) **plus
  `RateLimit-Limit`, `RateLimit-Remaining` and `RateLimit-Reset`.**

## The default vehicle

A plug-in hybrid. Every field reproduces the **shape** of
what was measured against a real one: never its values, see
`tests/test_privacy.py`:

- `operations[]`: `startCharging`, `stopCharging`, `setChargingLimit`,
  `setChargeMode`, `startAirConditioning`, `stopAirConditioning`.
- Present: `status`, `fuelStatus`, `odometer`, `parkingPosition`,
  `airConditioning`, `charging`, `operations`.
- Absent: `chargingProfiles`, `auxiliaryHeating`, `activeVentilation`,
  `licensePlate` - this vehicle genuinely does not support them.
- `charging.settings.availableChargeModes` is an empty array, despite
  `setChargeMode` being advertised in `operations[]` - a real, slightly
  inconsistent, measured behaviour. A mock that "fixes" this would stop
  being useful for testing the app against reality.
- `fuelStatus.primaryEngineRange`: `GASOLINE`, 62 %, 400 km.
  `fuelStatus.secondaryEngineRange`: `ELECTRIC`, 100 %, 36 km.
  `fuelStatus.totalRangeInKm`: 436.

## Scenarios (US-050)

Only one scenario is active at a time. Three ways to switch it, all
documented here because the task left the mechanism open:

1. **At startup:** `mock/run.sh --scenario <name>`.
2. **At runtime, globally, without restarting:** the control endpoint.
   ```bash
   curl -sk -X POST https://127.0.0.1:8792/_mock/scenario \
       -H 'Content-Type: application/json' \
       -d '{"scenario": "partial-data"}'
   curl -sk https://127.0.0.1:8792/_mock/scenario     # current scenario + full list
   ```
   `stale-airconditioning-17h` generalises to any section/age via an `ages`
   field (minutes), e.g. `{"scenario": "default", "ages": {"charging": 600}}`.
3. **Per request, without touching global state:** an `X-Mock-Scenario`
   header, or a `?_scenario=<name>` query parameter. Handy for tests running
   concurrently against one server (this is what `mock/tests/` uses).

`/_mock/*` is mock-only tooling, not part of the emulated Škoda contract -
it does not require `X-API-Key` and is not derived from `openapi.json`.

| Scenario | Effect |
|---|---|
| `default` | The plug-in hybrid above, all sections fresh. |
| `api-key-expired` | `401`, problem type `api-key-expired`. |
| `api-key-not-authorized` | `403`, problem type `api-key-not-authorized`. |
| `operation-not-supported` | `422` on a command, problem type `operation-not-supported`. |
| `operation-disabled` | `422` on a command, problem type `operation-disabled`. |
| `rate-limit-exceeded` | `429` + `Retry-After`, problem type `rate-limit-exceeded`. |
| `vehicle-not-accepting-requests` | `429` + `Retry-After`, problem type `vehicle-not-accepting-requests` - distinguished from the above only by `type`, as the real API does. |
| `500` / `503` / `504` | That status, generic `about:blank` problem. |
| `vehicle-not-found` | `404`, `"No vehicle found for VIN ..."` - the *other* kind of 404, as opposed to a routing miss. |
| `partial-data` | `200` with `charging` and `parkingPosition` omitted and `errors[]` populated. |
| `in-motion` | `parkingPosition.state = IN_MOTION`, no coordinates. |
| `stale-airconditioning-17h` | `airConditioning.carCapturedTimestamp` 17 hours old; other sections stay fresh - the measured per-section divergence. |
| `quota-nearly-spent` | `RateLimit-Remaining` forced to `1`. |
| `charging-active` | `charging.status.state = CHARGING`, plausible rate/power/ETA. |
| `connect-cable` | `charging.status.state = CONNECT_CABLE`. |
| `empty-charge-modes` | `availableChargeModes = []` (explicit; matches the default already). |
| `charging-profiles` | Adds a populated `chargingProfiles` section (absent by default). |
| `parked-with-address` | `PARKED` with coordinates and a formatted address (matches the default). |
| `parked-no-address` | `PARKED` with coordinates but no resolvable address. |
| `parking-position-unsupported` | `parkingPosition` omitted, `errors[]` has `PARKING_POSITION_UNSUPPORTED`. |
| `expires-in-20-days` | `X-API-Key-Expires-At` ~20 days out, to test the "key expiring soon" warning. |
| `unknown-enum` | Several enum-ish fields get a value not documented anywhere in `openapi.json`, to test forward-compatible parsing. |

## How routing and validation are derived from the spec (US-047, US-052)

`spec.py` reads `openapi.json` at import time and builds the route table
(method, path, required body, response codes) from it - `server.py` never
hand-lists an endpoint a second time. Concretely:

- Each OpenAPI path template becomes an anchored regex
  (`^/api/v1/vehicles/(?P<vin>[^/]+)$`, etc.), so a trailing slash or an
  extra segment can never match - this is *why* the trailing-slash rule
  needs no special case.
- A route's only 2xx response code is either `200` (the read) or `202`
  (every command) - `spec.is_command()` derives "is this a command" from
  that rather than a hand-maintained list.
- Request-body validation (`400` with `parameter`/`rejectedValue`/
  `allowedValues`) is driven by the schema's own `properties`,
  `required`, and - for the enum-like fields Škoda documents as prose
  bullets rather than a formal `enum:` (`* MANUAL   * TIMER   ...` inside
  `description`) - a regex extraction of that same bullet list
  (`jsonschema_lite.enum_values_from_description`). The one numeric rule
  (`charging/limit`'s "between 50 and 100 in steps of 10") is extracted the
  same way from its description text. Nothing here is a second copy of
  Škoda's enum lists that could quietly drift from the spec.
- The contract test (`tests/test_contract.py`) validates the mock's actual
  responses against the response schema documented for that route/status in
  `openapi.json`, using `jsonschema_lite.py` - a small, dependency-free
  validator (see its docstring for why no `jsonschema` package is used).
  It also asserts the validator itself catches a missing required field and
  a wrong type, and that every command's only 2xx is still a bodyless
  `202` - so a spec refresh that changes any of this fails the suite until
  the mock is updated.

## Refreshing the vendored spec

```bash
curl -s https://public.api.connect.skoda-auto.cz/v3/api-docs -o mock/openapi.json
```

Then update `mock/openapi.meta.json`'s `retrievedAt` (and `contractVersion`
if Škoda's changelog says it changed), and run the test suite. `git diff
mock/openapi.json` is the readable record of what changed; if a route,
required field or response shape moved, `pytest mock/tests` fails until
`server.py` / `scenarios.py` are updated to match.

## Known gaps

- `charging-profiles/{id}` validates its (large, nested) request body only
  generically (required top-level fields, types) - Škoda's spec does not
  document per-field business rules for it the way it does for
  `charging/limit` and `charging/mode`, so there is nothing more specific to
  derive.
- The quota counter (`RateLimit-Remaining`) is a real decrementing
  approximation of the one-hour window, but purely cosmetic - it never
  organically produces a `429` on its own; use the `rate-limit-exceeded`
  scenario for that. Real quota *tracking* logic belongs to task 4's
  `api/Quota.mc`, which is what actually needs testing against this.
