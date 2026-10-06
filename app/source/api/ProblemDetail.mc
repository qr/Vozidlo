import Toybox.Communications;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Parses RFC 9457 (application/problem+json) error bodies and Connect IQ's own
// transport error codes into one user-facing message (US-044). Every screen
// that shows an error routes through describe() so a new problem type only
// has to be taught once, here.
module ProblemDetail {

    // What the UI needs to show, and to decide with.
    class Message {
        // What to show the user. Never a bare number.
        public var text as String;
        // The RFC 9457 "type" this came from, or null when there wasn't one.
        // Quota.mc uses this to tell rate-limit-exceeded apart from
        // vehicle-not-accepting-requests (US-040).
        public var problemType as String?;
        // US-045: when true, the phone itself is unreachable. Cached data
        // stays visible and every request-making control is disabled, because
        // this is not "the API failed", it is "we could not even ask".
        public var isPhoneUnreachable as Boolean;

        function initialize(messageText as String, type as String?, phoneUnreachable as Boolean) {
            text = messageText;
            problemType = type;
            isPhoneUnreachable = phoneUnreachable;
        }
    }

    // status: Communications' responseCode. Either an HTTP status (200..599)
    // or one of its own negative transport codes (-104, -400, -1001, -1002,
    // ...). body: the decoded problem+json object for an HTTP-level error, or
    // null: there is never one for a transport-level failure, and never one
    // for a command response even on success (ApiClient loses it on purpose,
    // see US-042). retryAtEpoch: seconds-since-epoch a 429's Retry-After next
    // allows a request, or null; Quota.mc computes this, describe() only
    // formats it.
    function describe(status as Number, body as Dictionary?, retryAtEpoch as Number?) as Message {
        var transport = _describeTransportCode(status);
        if (transport != null) {
            return transport;
        }

        if (body != null) {
            var type = body.get("type") as String?;
            var detail = body.get("detail") as String?;
            var mapped = _describeProblemType(type, detail, retryAtEpoch);
            if (mapped != null) {
                return mapped;
            }
            return new Message(_fallbackMessage(status), type, false);
        }

        return new Message(_fallbackMessage(status), null, false);
    }

    // The four Connect IQ codes US-044 and US-045 name explicitly. Every
    // other negative responseCode falls through to the generic fallback
    // message below rather than getting its own case: the four here are the
    // ones we have evidence for and a specific, honest thing to say about.
    function _describeTransportCode(status as Number) as Message? {
        if (status == Communications.BLE_CONNECTION_UNAVAILABLE) {
            // US-045: every request is proxied over BLE through Garmin Connect
            // Mobile; there is no Wi-Fi fallback on a watch, and the user has
            // no way to know that unless we say so here.
            return new Message(
                "Your phone is not reachable. Every request to your car goes " +
                "through Garmin Connect Mobile on your phone: check that " +
                "it's nearby and connected.",
                null, true
            );
        }
        if (status == Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE) {
            // This is the exact code a mis-set :responseType produces on a
            // real 202 or a problem+json body (see ApiClient.mc): if it
            // still occurs with the split respected, the response body
            // itself was unreadable for some other reason, so there is
            // nothing more specific to say.
            return new Message("The car's answer could not be read. Try again.", null, false);
        }
        if (status == Communications.SECURE_CONNECTION_REQUIRED) {
            return new Message(
                "A secure connection is required and wasn't used: this is a " +
                "configuration problem, not something you did.",
                null, false
            );
        }
        if (status == Communications.UNSUPPORTED_CONTENT_TYPE_IN_RESPONSE) {
            return new Message("The car's answer wasn't in a format this app understands.", null, false);
        }
        return null;
    }

    // The US-044 table, plus the two-kinds-of-404 distinction. Returns null
    // for a type this table doesn't recognise, so describe() can fall back to
    // the neutral, HTTP-status message rather than inventing one.
    function _describeProblemType(type as String?, detail as String?, retryAtEpoch as Number?) as Message? {
        if (type == null) {
            return null;
        }
        if (typeIs(type, "api-key-expired")) {
            return new Message("This API key has expired. Create a new one in the MyŠkoda app.", type, false);
        }
        if (typeIs(type, "api-key-not-authorized")) {
            return new Message("This API key doesn't cover this vehicle.", type, false);
        }
        if (typeIs(type, "operation-not-authorized")) {
            return new Message("The car refused this for your account.", type, false);
        }
        if (typeIs(type, "operation-not-supported")) {
            return new Message("Your car can't do this.", type, false);
        }
        if (typeIs(type, "operation-disabled")) {
            return new Message("This service is switched off for your car.", type, false);
        }
        if (typeIs(type, "rate-limit-exceeded")) {
            return new Message(_rateLimitMessage(retryAtEpoch), type, false);
        }
        if (typeIs(type, "vehicle-not-accepting-requests")) {
            return new Message("The car declined the request. Try again shortly.", type, false);
        }
        if (typeIs(type, "about:blank") && detail != null) {
            // The real API (and the mock, deliberately) uses "about:blank"
            // for both a routing miss and a business-logic 404, so `detail`
            // is the only thing that tells them apart. This is the second of
            // the two URL bugs this whole project exists to keep from
            // recurring: a malformed URL must never read as "your VIN is
            // wrong" (see docs/decisions.md, "The mock is strict on purpose").
            if (detail.find("No static resource") == 0) {
                return new Message(
                    "The app sent a malformed request: this is a bug in the app, not your car.",
                    type, false
                );
            }
            if (detail.find("No vehicle found") == 0) {
                return new Message("No vehicle was found for the VIN in your settings. Check it on the phone.", type, false);
            }
        }
        return null;
    }

    function _rateLimitMessage(retryAtEpoch as Number?) as String {
        if (retryAtEpoch == null) {
            return "Quota spent for this hour. Try again once the window resets.";
        }
        return "Quota spent, try again at " + _formatClock(retryAtEpoch) + ".";
    }

    function _formatClock(epoch as Number) as String {
        var info = Gregorian.info(new Time.Moment(epoch), Time.FORMAT_SHORT);
        return _pad2(info.hour) + ":" + _pad2(info.min);
    }

    function _pad2(n as Number) as String {
        if (n < 10) {
            return "0" + n.toString();
        }
        return n.toString();
    }

    function _fallbackMessage(status as Number) as String {
        return "Something went wrong (status " + status.toString() + ").";
    }

    // Whether an RFC 9457 "type" is the given short name: matched either
    // exactly or as the last path segment of a full type URI. Both the mock
    // and the real API send the full
    // "https://public.api.connect.skoda-auto.cz/problems/<name>" form; this
    // matches on the segment rather than hardcoding that whole URI so a
    // future change to the domain doesn't silently break every message.
    // Public (not the file's usual `_` convention) because Quota.mc needs the
    // exact same distinction to tell rate-limit-exceeded apart from
    // vehicle-not-accepting-requests (US-040) and must not duplicate it.
    function typeIs(type as String?, shortName as String) as Boolean {
        if (type == null) {
            return false;
        }
        if (type.equals(shortName)) {
            return true;
        }
        var suffix = "/" + shortName;
        var suffixStart = type.length() - suffix.length();
        if (suffixStart < 0) {
            return false;
        }
        var candidate = type.substring(suffixStart, type.length());
        return candidate != null && candidate.equals(suffix);
    }

}
