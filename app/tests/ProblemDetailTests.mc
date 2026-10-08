import Toybox.Communications;
import Toybox.Lang;
import Toybox.Test;

// Unit tests for ProblemDetail.describe(): what the user reads when a
// request fails. Commands never get a body (ApiClient.mc loses the
// problem+json answer on purpose), so their text comes from the status
// alone; reads keep the type-based text.
module ProblemDetailTests {

    function text(status as Number, body as Dictionary?) as String {
        return ProblemDetail.describe(status, body, null).text;
    }

    function problem(name as String) as Dictionary {
        return { "type" => "https://public.api.connect.skoda-auto.cz/problems/" + name };
    }

    // The statuses Škoda answers a command with, measured on 2026-10-08
    // (422 for ventilation on a car without it), each with its own reason.
    (:test)
    function aCommandWithoutABodyIsExplainedByItsStatus(logger as Logger) as Boolean {
        var cases = [
            [401, "The API key was not accepted. Check it in the settings."],
            [403, "This API key doesn't cover this vehicle."],
            [409, "The car is busy. Try again shortly."],
            [422, "Your car can't do this."],
            [500, "Škoda's server had a problem. Try again later."],
            [503, "Škoda's server had a problem. Try again later."]
        ] as Array<[Number, String]>;
        for (var i = 0; i < cases.size(); i += 1) {
            var got = text(cases[i][0], null);
            if (!got.equals(cases[i][1])) {
                logger.error(cases[i][0].toString() + ": expected '" + cases[i][1] + "', got '" + got + "'");
                return false;
            }
        }
        return true;
    }

    // A 429 without a body still reads as the quota.
    (:test)
    function aBareRateLimitReadsAsTheQuota(logger as Logger) as Boolean {
        var got = text(429, null);
        if (got.find("Quota") != 0) {
            logger.error("expected the quota message, got '" + got + "'");
            return false;
        }
        return true;
    }

    // A 404 without `detail` cannot be told apart from a malformed URL, so
    // it never says "your VIN is wrong"; the status is in the text.
    (:test)
    function aBare404StaysGeneric(logger as Logger) as Boolean {
        var got = text(404, null);
        if (got.find("VIN") != null || got.find("404") == null) {
            logger.error("expected the generic text with the status, got '" + got + "'");
            return false;
        }
        return true;
    }

    // A status nothing is known about keeps the generic text with its number.
    (:test)
    function anUnknownStatusShowsItsNumber(logger as Logger) as Boolean {
        var got = text(418, null);
        if (!got.equals("Something went wrong (status 418).")) {
            logger.error("got '" + got + "'");
            return false;
        }
        return true;
    }

    // A readable problem type wins over the status (reads keep their body).
    (:test)
    function aKnownTypeWinsOverTheStatus(logger as Logger) as Boolean {
        var got = text(403, problem("api-key-expired"));
        if (got.find("expired") == null) {
            logger.error("api-key-expired must say so, got '" + got + "'");
            return false;
        }
        got = text(422, problem("operation-not-supported"));
        if (!got.equals("Your car can't do this.")) {
            logger.error("operation-not-supported, got '" + got + "'");
            return false;
        }
        return true;
    }

    // An unknown type falls back to the status text, not the bare generic.
    (:test)
    function anUnknownTypeFallsBackToTheStatus(logger as Logger) as Boolean {
        var got = text(422, problem("something-new"));
        if (!got.equals("Your car can't do this.")) {
            logger.error("got '" + got + "'");
            return false;
        }
        return true;
    }

    // Connect IQ's own codes keep their texts, and the phone flag.
    (:test)
    function transportCodesAreUnchanged(logger as Logger) as Boolean {
        var phone = ProblemDetail.describe(Communications.BLE_CONNECTION_UNAVAILABLE, null, null);
        if (!phone.isPhoneUnreachable || phone.text.find("phone") == null) {
            logger.error("BLE_CONNECTION_UNAVAILABLE must say the phone is unreachable");
            return false;
        }
        if (text(Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE, null).find("could not be read") == null) {
            logger.error("-400 keeps its text");
            return false;
        }
        return true;
    }

}
