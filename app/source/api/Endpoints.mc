import Toybox.Application;
import Toybox.Lang;

// Pure URL construction for the MyŠkoda Public API: no I/O, so every function
// here is trivially unit tested (see tests/EndpointTests.mc). This file exists
// on its own because we shipped two bugs building these strings by hand during
// the feasibility spike: a missing "/vehicles/" path segment, and a trailing
// slash before "?include=". "Append a path segment" and "append a query
// string" are kept as two distinct operations below, never merged into one
// general-purpose "append" helper, so the two shapes can never be confused
// with each other again, see withSegment()/withQuery().
module Endpoints {

    const PRODUCTION_BASE = "https://public.api.connect.skoda-auto.cz/api/v1";

    // Every URL below is built from baseUrl(), never from a constant, so the
    // app can be pointed at mock/ without anyone editing this file and
    // remembering to revert it. An instruction to remember something is not a
    // mechanism; the (:debug)/(:release) split is.
    //
    // The debug build honours the MockBaseUrl property, which is declared but
    // deliberately not exposed as a setting, so it never reaches the phone UI.
    // Set it once per simulator session under
    // File > Edit Persistent Storage > Application.Properties.
    (:debug)
    function baseUrl() as String {
        var override = Application.Properties.getValue("MockBaseUrl") as String?;
        if (override != null && !override.equals("")) {
            return override;
        }
        return PRODUCTION_BASE;
    }

    // The release build has no override at all: this function is the only one
    // compiled in, so a shipped app cannot be aimed anywhere but the real API.
    (:release)
    function baseUrl() as String {
        return PRODUCTION_BASE;
    }

    // A path segment always gets a "/" separator. This is the operation the
    // first shipped bug got wrong (a missing "/vehicles/" segment).
    function withSegment(base as String, segment as String) as String {
        return base + "/" + segment;
    }

    // A query string is appended with "?" and NEVER a preceding "/". This is
    // the operation the second shipped bug got wrong (a trailing slash before
    // "?include=").
    function withQuery(base as String, query as String) as String {
        return base + "?" + query;
    }

    // Shared by every endpoint below: the one place "/vehicles/{vin}" is
    // spelled out, so the missing-segment bug has exactly one place it could
    // recur, and a test on any single endpoint that calls this catches it for
    // all of them.
    function vehiclesBase(vin as String) as String {
        return withSegment(withSegment(baseUrl(), "vehicles"), vin);
    }

    // GET /vehicles/{vin}: every section the vehicle supports.
    function vehicle(vin as String) as String {
        return vehiclesBase(vin);
    }

    // GET /vehicles/{vin}?include=...: a specific subset of sections.
    // `include` is already the comma-joined value (e.g. "status,charging");
    // building that list is the caller's job, this function only appends it
    // as a query string, never as a path segment.
    function vehicleWithInclude(vin as String, include as String) as String {
        return withQuery(vehiclesBase(vin), "include=" + include);
    }

    // POST /vehicles/{vin}/air-conditioning/start
    function startAirConditioning(vin as String) as String {
        return withSegment(withSegment(vehiclesBase(vin), "air-conditioning"), "start");
    }

    // POST /vehicles/{vin}/air-conditioning/stop
    function stopAirConditioning(vin as String) as String {
        return withSegment(withSegment(vehiclesBase(vin), "air-conditioning"), "stop");
    }

    // POST /vehicles/{vin}/active-ventilation/start
    function startActiveVentilation(vin as String) as String {
        return withSegment(withSegment(vehiclesBase(vin), "active-ventilation"), "start");
    }

    // POST /vehicles/{vin}/active-ventilation/stop
    function stopActiveVentilation(vin as String) as String {
        return withSegment(withSegment(vehiclesBase(vin), "active-ventilation"), "stop");
    }

    // POST /vehicles/{vin}/auxiliary-heating/start
    function startAuxiliaryHeating(vin as String) as String {
        return withSegment(withSegment(vehiclesBase(vin), "auxiliary-heating"), "start");
    }

    // POST /vehicles/{vin}/auxiliary-heating/stop
    function stopAuxiliaryHeating(vin as String) as String {
        return withSegment(withSegment(vehiclesBase(vin), "auxiliary-heating"), "stop");
    }

    // POST /vehicles/{vin}/charging/start
    function startCharging(vin as String) as String {
        return withSegment(withSegment(vehiclesBase(vin), "charging"), "start");
    }

    // POST /vehicles/{vin}/charging/stop
    function stopCharging(vin as String) as String {
        return withSegment(withSegment(vehiclesBase(vin), "charging"), "stop");
    }

    // PUT /vehicles/{vin}/charging/mode
    function chargingMode(vin as String) as String {
        return withSegment(withSegment(vehiclesBase(vin), "charging"), "mode");
    }

    // PUT /vehicles/{vin}/charging/limit
    function chargingLimit(vin as String) as String {
        return withSegment(withSegment(vehiclesBase(vin), "charging"), "limit");
    }

    // PUT /vehicles/{vin}/charging-profiles/{id}
    function chargingProfile(vin as String, id as String) as String {
        return withSegment(withSegment(vehiclesBase(vin), "charging-profiles"), id);
    }

}
