import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;

// The one place a request's options dictionary gets built (US-042). Every
// caller (task 7's commands included) goes through the functions below
// rather than building `{ :method => ..., :headers => ... }` at the call
// site, so the :responseType rule cannot be got wrong by a future edit.
//
// Read vs. command is not a style choice, it is measured behaviour (see
// docs/best-practices, section 5, and the feasibility study it cites):
//   - Škoda answers a command with 202, an empty body and NO Content-Type
//     header. With :responseType set, Connect IQ cannot match that against
//     "application/json" and reports -400: every successful command would
//     look like a failure.
//   - An error body comes back as application/problem+json. Without
//     :responseType, Connect IQ's automatic content-type detection only
//     recognises an exact "application/json" match, so a problem+json body
//     also becomes an unreadable -400 and the reason is lost.
// Reads want the second failure avoided; commands want the first.
//
// Note for whoever wires these into a live response handler: Connect IQ does
// NOT expose response headers to Monkey C: makeWebRequest()'s callback is
// always exactly (responseCode, data). RateLimit-*, Retry-After and
// X-API-Key-Expires-At are real HTTP response headers the mock and the real
// API both send, but nothing in Toybox.Communications hands them to this
// code. Quota.mc (task 4) is written to accept already-extracted values for
// exactly this reason: this module cannot solve that gap, and no
// task-4 file claims to.
module ApiClient {

    const API_KEY_HEADER = "X-API-Key";

    // The response callback shape Communications.makeWebRequest() requires.
    typedef ResponseHandler as Method(responseCode as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void;

    // Built as ONE dictionary literal: assembling this with put() infers a
    // narrower structural type that the compiler then rejects at -l 3 once it
    // is passed to makeWebRequest(). We hit exactly that during the spike.
    // Exposed (not called from within this module) so US-042's unit test can
    // assert the exact shape without a live request, see EndpointTests.mc.
    function readOptions(apiKey as String) as Dictionary {
        return {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => { API_KEY_HEADER => apiKey },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
    }

    // Same rule, the other direction: :responseType is OMITTED, not set to
    // null: omitting the key entirely is what changes Connect IQ's response
    // parsing path (see the module comment above).
    function commandOptions(method as Communications.HttpRequestMethod, apiKey as String) as Dictionary {
        return {
            :method => method,
            :headers => {
                API_KEY_HEADER => apiKey,
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
            }
        };
    }

    // The body of a command Škoda defines without one (stop climate, both
    // charging commands, ventilation, stop auxiliary heating): an empty JSON
    // object, never null. Garmin Connect on Android does not send a POST
    // whose Content-Type is JSON and whose body is null: the watch gets
    // responseCode 0 and nothing reaches Škoda (measured 2026-10-08 with
    // adb and the rate-limit counter: start climate, which has a body, went
    // out; stop climate did not). Škoda answers `{}` with the same 202.
    function noBody() as Dictionary<Object, Object> {
        return {} as Dictionary<Object, Object>;
    }

    // The single read endpoint. `include`, when given, is already the
    // comma-joined list of section names, see Endpoints.vehicleWithInclude.
    // Wrapped in its own function, per docs/best-practices "Wrap each request
    // in its own function or class", so no call site ever inlines url,
    // params and options itself.
    function getVehicle(vin as String, include as String?, apiKey as String, callback as ResponseHandler) as Void {
        var url = (include != null) ? Endpoints.vehicleWithInclude(vin, include) : Endpoints.vehicle(vin);
        Communications.makeWebRequest(url, null, {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => { API_KEY_HEADER => apiKey },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        }, callback);
    }

    function startAirConditioning(vin as String, body as Dictionary<Object, Object>?, apiKey as String, callback as ResponseHandler) as Void {
        Communications.makeWebRequest(Endpoints.startAirConditioning(vin), body, {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => { API_KEY_HEADER => apiKey, "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON }
        }, callback);
    }

    function stopAirConditioning(vin as String, apiKey as String, callback as ResponseHandler) as Void {
        Communications.makeWebRequest(Endpoints.stopAirConditioning(vin), noBody(), {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => { API_KEY_HEADER => apiKey, "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON }
        }, callback);
    }

    function startActiveVentilation(vin as String, apiKey as String, callback as ResponseHandler) as Void {
        Communications.makeWebRequest(Endpoints.startActiveVentilation(vin), noBody(), {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => { API_KEY_HEADER => apiKey, "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON }
        }, callback);
    }

    function stopActiveVentilation(vin as String, apiKey as String, callback as ResponseHandler) as Void {
        Communications.makeWebRequest(Endpoints.stopActiveVentilation(vin), noBody(), {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => { API_KEY_HEADER => apiKey, "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON }
        }, callback);
    }

    function startAuxiliaryHeating(vin as String, body as Dictionary<Object, Object>?, apiKey as String, callback as ResponseHandler) as Void {
        Communications.makeWebRequest(Endpoints.startAuxiliaryHeating(vin), body, {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => { API_KEY_HEADER => apiKey, "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON }
        }, callback);
    }

    function stopAuxiliaryHeating(vin as String, apiKey as String, callback as ResponseHandler) as Void {
        Communications.makeWebRequest(Endpoints.stopAuxiliaryHeating(vin), noBody(), {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => { API_KEY_HEADER => apiKey, "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON }
        }, callback);
    }

    function startCharging(vin as String, apiKey as String, callback as ResponseHandler) as Void {
        Communications.makeWebRequest(Endpoints.startCharging(vin), noBody(), {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => { API_KEY_HEADER => apiKey, "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON }
        }, callback);
    }

    function stopCharging(vin as String, apiKey as String, callback as ResponseHandler) as Void {
        Communications.makeWebRequest(Endpoints.stopCharging(vin), noBody(), {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => { API_KEY_HEADER => apiKey, "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON }
        }, callback);
    }

    // PUT /charging/mode. `body` is the ChargeMode request Škoda documents:
    // constructing it is task 7's concern (it needs a chosen mode from the UI).
    function setChargeMode(vin as String, body as Dictionary<Object, Object>, apiKey as String, callback as ResponseHandler) as Void {
        Communications.makeWebRequest(Endpoints.chargingMode(vin), body, {
            :method => Communications.HTTP_REQUEST_METHOD_PUT,
            :headers => { API_KEY_HEADER => apiKey, "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON }
        }, callback);
    }

    // PUT /charging/limit.
    function setChargingLimit(vin as String, body as Dictionary<Object, Object>, apiKey as String, callback as ResponseHandler) as Void {
        Communications.makeWebRequest(Endpoints.chargingLimit(vin), body, {
            :method => Communications.HTTP_REQUEST_METHOD_PUT,
            :headers => { API_KEY_HEADER => apiKey, "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON }
        }, callback);
    }

    // PUT /charging-profiles/{id}. Editing charging profiles is Won't for
    // this release (see docs/requirements.md, US-027): this exists only so
    // Endpoints.chargingProfile() has a matching sender, consistent with the
    // other eleven endpoints.
    function updateChargingProfile(vin as String, id as String, body as Dictionary<Object, Object>, apiKey as String, callback as ResponseHandler) as Void {
        Communications.makeWebRequest(Endpoints.chargingProfile(vin, id), body, {
            :method => Communications.HTTP_REQUEST_METHOD_PUT,
            :headers => { API_KEY_HEADER => apiKey, "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON }
        }, callback);
    }

}
