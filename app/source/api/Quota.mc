import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;

// Tracks the hourly request quota the Škoda API enforces per VIN (US-040):
// shared with anything else the user runs against the same car, so the app
// has to behave like a guest in someone else's budget.
//
// This module owns the STATE MACHINE, not header parsing: Connect IQ does not
// expose HTTP response headers to Monkey C at all: Communications.
// makeWebRequest()'s callback is always exactly (responseCode, data), see
// ApiClient.mc. Whatever future code does manage to read RateLimit-Limit,
// RateLimit-Remaining, RateLimit-Reset and Retry-After calls the functions
// below with the already-extracted values; that keeps this module correct
// and independently testable regardless of how those values were obtained.
//
// State survives a restart (US-040) because every mutation is written
// straight to Application.Storage rather than cached in memory: there is no
// module-level variable here to go stale or reset.
module Quota {

    const STORAGE_KEY = "quota";
    const LOW_WATERMARK = 3; // "fewer than three remain": US-040

    function _load() as Dictionary {
        var stored = Storage.getValue(STORAGE_KEY);
        if (stored instanceof Dictionary) {
            return stored as Dictionary;
        }
        return {};
    }

    function _save(state as Dictionary) as Void {
        Storage.setValue(STORAGE_KEY, state as Storage.ValueType);
    }

    // Call after any response that carried RateLimit-* headers. Pass null for
    // a value that wasn't present rather than skipping the call: a
    // successful call, even with nothing new to record, proves the app was
    // not actually being held back, so it always clears a stale Retry-After
    // gate (a fresh RateLimit-Remaining, when given, is authoritative and
    // supersedes any remaining we forced to 0 in recordRateLimited() below).
    function recordHeaders(limit as Number?, remaining as Number?, resetSeconds as Number?) as Void {
        var state = _load();
        if (limit != null) {
            state.put("limit", limit);
        }
        if (remaining != null) {
            state.put("remaining", remaining);
        }
        if (resetSeconds != null) {
            state.put("resetAt", Time.now().value() + resetSeconds);
        }
        state.put("retryAfterUntil", null);
        _save(state);
    }

    // Call on a 429. `problemType` is the RFC 9457 "type" from the body:
    // US-040 requires telling rate-limit-exceeded apart from
    // vehicle-not-accepting-requests here, because they mean different
    // things for OUR quota tracking even though both are 429s:
    //   - rate-limit-exceeded means our own hourly budget is spent, so
    //     `remaining` is forced to 0 even if this particular error response
    //     carried no RateLimit-Remaining header of its own.
    //   - vehicle-not-accepting-requests is a DIFFERENT, vehicle-side
    //     throttle; our own remaining count is untouched.
    // Either way, Retry-After is honoured identically: no request before it.
    function recordRateLimited(problemType as String?, retryAfterSeconds as Number?) as Void {
        var state = _load();
        if (retryAfterSeconds != null) {
            state.put("retryAfterUntil", Time.now().value() + retryAfterSeconds);
        }
        if (ProblemDetail.typeIs(problemType, "rate-limit-exceeded")) {
            state.put("remaining", 0);
        }
        _save(state);
    }

    function limit() as Number? {
        return _load().get("limit") as Number?;
    }

    function remaining() as Number? {
        return _load().get("remaining") as Number?;
    }

    // Seconds-since-epoch the current hourly window resets, or null when
    // never observed.
    function resetAt() as Number? {
        return _load().get("resetAt") as Number?;
    }

    // Seconds-since-epoch a 429's Retry-After next allows a request, or null.
    function retryAfterUntil() as Number? {
        return _load().get("retryAfterUntil") as Number?;
    }

    // US-040: "given zero remain, then request-making actions are disabled",
    // and a live Retry-After gate blocks a request regardless of `remaining`.
    function canSpend() as Boolean {
        var state = _load();
        var remainingValue = state.get("remaining") as Number?;
        if (remainingValue != null && remainingValue <= 0) {
            return false;
        }
        var retryUntil = state.get("retryAfterUntil") as Number?;
        if (retryUntil != null && Time.now().value() < retryUntil) {
            return false;
        }
        return true;
    }

    // US-040: "given fewer than three requests remain, then the app warns
    // before spending one." Zero remaining is a harder, different state
    // (canSpend() == false already covers it) so it's deliberately excluded
    // here rather than double-warned.
    function isLow() as Boolean {
        var remainingValue = remaining();
        return remainingValue != null && remainingValue > 0 && remainingValue < LOW_WATERMARK;
    }

    // Whole seconds until the window resets, or null when never observed.
    // Never negative: a resetAt in the past just means the window already
    // turned over and a fresh RateLimit-Reset simply hasn't arrived yet.
    function secondsUntilReset() as Number? {
        var reset = resetAt();
        if (reset == null) {
            return null;
        }
        var remainingSeconds = reset - Time.now().value();
        if (remainingSeconds > 0) {
            return remainingSeconds;
        }
        return 0;
    }

    // Clears all quota state. Used by QuotaTests.mc between tests; also a
    // legitimate building block if a future "clear stored data" action wants
    // to reset quota tracking along with everything else.
    function clear() as Void {
        Storage.deleteValue(STORAGE_KEY);
    }

}
