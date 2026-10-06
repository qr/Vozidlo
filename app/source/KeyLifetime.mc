import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;

// US-004: Connect IQ cannot read HTTP response headers at all, not even
// X-API-Key-Expires-At, which the real API sends on every success (see
// docs/best-practices/garmin-connect-iq.md, "Talking to a third-party web
// API"). Two independent, locally-observable signals stand in for it, and
// neither one is a substitute for the other:
//
//   1. How long ago the current key first worked. We cannot know when a key
//      expires, but we CAN know when it started, and the measured lifetime
//      (180 days on one key) turns "started" into an estimate of "expiring
//      soon", see isEstimatedNearExpiry().
//   2. The exact date the 401 body states verbatim once it actually
//      matters ("The API key expired on 2026-09-01T00:00:00Z."), see
//      parseExpiredDetailDate(). This is precise but arrives with no
//      advance warning, which is exactly why (1) exists.
//
// State survives a restart because, like Quota.mc and Cache.mc, every
// mutation is written straight to Application.Storage rather than cached in
// a module variable.
module KeyLifetime {

    const STORAGE_KEY = "keyLifetime";

    // Measured on one key (see the module comment); the 159-day warning
    // threshold leaves 21 days of runway before the estimate's own margin
    // of error could plausibly eat into it.
    const WARNING_AFTER_DAYS = 159;

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

    // Call after ANY successful (2xx) response made with `apiKey`. Only the
    // FIRST success for a given key sets the start date: recording again
    // on every later success would keep sliding the estimate's baseline
    // forward and it would never fire. A DIFFERENT key (including the very
    // first one ever entered) always resets it: US-004, "given I enter a
    // new key, then the estimated start date resets."
    function recordSuccessAt(apiKey as String, nowEpoch as Number) as Void {
        var state = _load();
        var trackedKey = state.get("apiKey") as String?;
        if (trackedKey == null || !trackedKey.equals(apiKey)) {
            state.put("apiKey", apiKey);
            state.put("startedAt", nowEpoch);
        }
        _save(state);
    }

    function recordSuccess(apiKey as String) as Void {
        recordSuccessAt(apiKey, Time.now().value());
    }

    // Seconds-since-epoch `apiKey`'s tracked start date, or null when no
    // success has ever been recorded for THIS key: a start date tracked
    // for a since-replaced key must never leak through as if it belonged to
    // the current one.
    function startedAt(apiKey as String) as Number? {
        var state = _load();
        var trackedKey = state.get("apiKey") as String?;
        if (trackedKey == null || !trackedKey.equals(apiKey)) {
            return null;
        }
        return state.get("startedAt") as Number?;
    }

    // US-002's "on first request" validation is gated by this: a key with
    // no recorded start has never had a successful request, so it still
    // needs to be checked. See ui/OnboardingGate.mc.
    function hasValidated(apiKey as String) as Boolean {
        return startedAt(apiKey) != null;
    }

    // `nowEpoch` is a parameter, not `Time.now()` read internally, so
    // OnboardingTests.mc can ask "what would this say 160 days from now"
    // without a way to fast-forward the simulator's clock. daysSinceStart()
    // below is the real-clock convenience wrapper every non-test caller
    // uses. Integer division truncates toward the last full day, so a
    // partial 159th day is deliberately not yet "past" 159.
    function daysSinceStartAt(apiKey as String, nowEpoch as Number) as Number? {
        var started = startedAt(apiKey);
        if (started == null) {
            return null;
        }
        var elapsedSeconds = nowEpoch - started;
        if (elapsedSeconds < 0) {
            return 0; // clock skew or a restored backup: never negative.
        }
        return elapsedSeconds / 86400;
    }

    function daysSinceStart(apiKey as String) as Number? {
        return daysSinceStartAt(apiKey, Time.now().value());
    }

    // US-004: "given more than 159 days have passed... a non-blocking
    // notice says probably close to expiring." Never true for a key that
    // has not even validated yet: there is nothing to estimate from, and
    // showing a guess with no basis would be worse than showing nothing.
    function isEstimatedNearExpiryAt(apiKey as String, nowEpoch as Number) as Boolean {
        var days = daysSinceStartAt(apiKey, nowEpoch);
        return days != null && days > WARNING_AFTER_DAYS;
    }

    function isEstimatedNearExpiry(apiKey as String) as Boolean {
        return isEstimatedNearExpiryAt(apiKey, Time.now().value());
    }

    // US-007's "clear stored data": also a legitimate way to force
    // re-validation of the current key without actually changing it.
    function clear() as Void {
        Storage.deleteValue(STORAGE_KEY);
    }

    // Parses the exact expiry date out of a 401 api-key-expired problem
    // body's `detail`, e.g. "The API key expired on 2026-09-01T00:00:00Z."
    //: the one piece of the real expiry moment Connect IQ can ever read,
    // since response headers are unreachable (see the module comment).
    // Returns a display date ("2026-09-01") or null if the sentence shape
    // ever changes and the date can no longer be found: callers must fall
    // back to a dateless message rather than show a mangled string.
    function parseExpiredDetailDate(detail as String?) as String? {
        if (detail == null) {
            return null;
        }
        var marker = "on ";
        var markerIndex = detail.find(marker);
        if (markerIndex == null) {
            return null;
        }
        var start = markerIndex + marker.length();
        if (detail.length() < start + 10) {
            return null;
        }
        var candidate = detail.substring(start, start + 10);
        if (candidate == null) {
            return null;
        }
        if (!_looksLikeIsoDate(candidate)) {
            return null;
        }
        return candidate;
    }

    // A shape check ("YYYY-MM-DD", numeric year/month/day either side of
    // two dashes), not a calendar validator: the point is refusing to
    // display garbage if the API's wording ever changes, not verifying the
    // date it sends is real. Written as separate stepped checks rather than
    // one chained boolean expression: a long &&/|| chain over several
    // nullable substring()/toNumber() calls made the SDK's type checker
    // (FunctionTypeChecker.combineSubstitutions) run out of heap during a
    // -l 3 build: this shape avoids that entirely, not just works around
    // it for this one function.
    function _looksLikeIsoDate(value as String) as Boolean {
        if (value.length() != 10) {
            return false;
        }
        if (!_isDash(value, 4)) {
            return false;
        }
        if (!_isDash(value, 7)) {
            return false;
        }
        if (!_isNumericPart(value, 0, 4)) {
            return false;
        }
        if (!_isNumericPart(value, 5, 7)) {
            return false;
        }
        if (!_isNumericPart(value, 8, 10)) {
            return false;
        }
        return true;
    }

    function _isDash(value as String, at as Number) as Boolean {
        var c = value.substring(at, at + 1);
        if (c == null) {
            return false;
        }
        return c.equals("-");
    }

    function _isNumericPart(value as String, start as Number, end as Number) as Boolean {
        var part = value.substring(start, end);
        if (part == null) {
            return false;
        }
        var number = part.toNumber();
        return number != null;
    }

}
