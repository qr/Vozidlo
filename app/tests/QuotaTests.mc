import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;
import Toybox.Time;

// Unit tests for source/api/Quota.mc (US-040, US-053): exhaustion, the
// "nearly spent" warning, Retry-After, telling rate-limit-exceeded apart from
// vehicle-not-accepting-requests, and that state survives being reloaded from
// Storage rather than kept in memory (a restart, in effect: Quota never
// caches in a module variable, so every call already reads Storage fresh).
module QuotaTests {

    (:test)
    function freshQuotaAllowsSpending(logger as Logger) as Boolean {
        Quota.clear();
        if (!Quota.canSpend()) {
            logger.error("quota with no history yet must allow a request");
            return false;
        }
        if (Quota.isLow()) {
            logger.error("quota with no history yet is not 'low'");
            return false;
        }
        return true;
    }

    (:test)
    function headersAreStoredAndSurviveAReload(logger as Logger) as Boolean {
        Quota.clear();
        Quota.recordHeaders(20, 17, 3600);

        if (Quota.limit() != 20) {
            logger.error("limit not stored");
            return false;
        }
        if (Quota.remaining() != 17) {
            logger.error("remaining not stored");
            return false;
        }
        var resetAt = Quota.resetAt();
        if (resetAt == null) {
            logger.error("resetAt not stored");
            return false;
        }
        // Quota never caches in memory: every accessor above already re-read
        // Application.Storage, which is exactly what "survives a restart"
        // requires: there is no in-process state to lose.
        var secondsLeft = Quota.secondsUntilReset();
        if (secondsLeft == null || secondsLeft > 3600 || secondsLeft < 3595) {
            logger.error("secondsUntilReset not derived from the stored resetAt");
            return false;
        }
        return true;
    }

    // US-040: "given fewer than three requests remain, then the app warns
    // before spending one."
    (:test)
    function fewerThanThreeRemainingIsLow(logger as Logger) as Boolean {
        Quota.clear();
        Quota.recordHeaders(20, 2, 3600);
        if (!Quota.isLow()) {
            logger.error("2 remaining must be reported as low");
            return false;
        }
        if (!Quota.canSpend()) {
            logger.error("2 remaining can still be spent, just with a warning");
            return false;
        }

        Quota.recordHeaders(20, 3, 3600);
        if (Quota.isLow()) {
            logger.error("3 remaining is the boundary, not low yet");
            return false;
        }
        return true;
    }

    // US-040: "given zero remain, then request-making actions are disabled
    // and the app shows when the window resets."
    (:test)
    function zeroRemainingBlocksSpending(logger as Logger) as Boolean {
        Quota.clear();
        Quota.recordHeaders(20, 0, 415);

        if (Quota.canSpend()) {
            logger.error("zero remaining must block further requests");
            return false;
        }
        // Exhaustion is a harder state than "low": it gets its own message,
        // not a second warning.
        if (Quota.isLow()) {
            logger.error("zero remaining is 'exhausted', not merely 'low'");
            return false;
        }
        var secondsLeft = Quota.secondsUntilReset();
        if (secondsLeft == null || secondsLeft > 415 || secondsLeft < 410) {
            logger.error("the app must be able to show when the window resets");
            return false;
        }
        return true;
    }

    // US-040: a 429 with type "rate-limit-exceeded" means OUR quota is spent.
    // force remaining to 0 even if the error response carried no
    // RateLimit-Remaining header of its own, and Retry-After blocks
    // spending until it elapses.
    (:test)
    function rateLimitExceededForcesRemainingToZeroAndHonoursRetryAfter(logger as Logger) as Boolean {
        Quota.clear();
        Quota.recordHeaders(20, 5, 3600);
        Quota.recordRateLimited("https://public.api.connect.skoda-auto.cz/problems/rate-limit-exceeded", 60);

        if (Quota.remaining() != 0) {
            logger.error("rate-limit-exceeded must force remaining to 0");
            return false;
        }
        if (Quota.canSpend()) {
            logger.error("must not be able to spend while Retry-After has not elapsed");
            return false;
        }
        return true;
    }

    // US-040: vehicle-not-accepting-requests is a DIFFERENT throttle. Our
    // own remaining count is left alone, but Retry-After still gates
    // spending either way.
    (:test)
    function vehicleNotAcceptingRequestsLeavesRemainingAlone(logger as Logger) as Boolean {
        Quota.clear();
        Quota.recordHeaders(20, 5, 3600);
        Quota.recordRateLimited("vehicle-not-accepting-requests", 30);

        if (Quota.remaining() != 5) {
            logger.error("vehicle-not-accepting-requests must not touch our own remaining count");
            return false;
        }
        if (Quota.canSpend()) {
            logger.error("Retry-After still applies regardless of which 429 type it was");
            return false;
        }
        return true;
    }

    // The calls the app really makes (Connect IQ reads no headers): after a
    // rate-limit-exceeded with no Retry-After, requests stay blocked for one
    // hour from the 429, with the reset shown, and then the app may ask again.
    // Before 1.3.0 this zero never lifted.
    (:test)
    function aRateLimitWithoutHeadersLiftsAfterAnHour(logger as Logger) as Boolean {
        Quota.clear();
        var t = 1700000000;
        Quota.nowOverride = t;
        Quota.recordHeaders(null, null, null);
        Quota.recordRateLimited("https://public.api.connect.skoda-auto.cz/problems/rate-limit-exceeded", null);
        var ok = _blocked(logger, "right after the 429", true)
            && _eqN(logger, "seconds until the reset", Quota.secondsUntilReset(), 3600);
        Quota.nowOverride = t + 3599;
        ok = ok && _blocked(logger, "a second before the hour is up", true);
        Quota.nowOverride = t + 3600;
        ok = ok && _blocked(logger, "once the hour is up", false)
            && _eqN(logger, "remaining once the hour is up", Quota.remaining(), null);
        if (ok && Quota.isLow()) {
            logger.error("an expired zero is unknown, not low");
            ok = false;
        }
        Quota.nowOverride = null;
        return ok;
    }

    // A second 429 after the hour starts a new hour from that 429.
    (:test)
    function aSecondRateLimitStartsANewHour(logger as Logger) as Boolean {
        Quota.clear();
        var t = 1700000000;
        Quota.nowOverride = t;
        Quota.recordRateLimited("rate-limit-exceeded", null);
        Quota.nowOverride = t + 3700;
        Quota.recordRateLimited("rate-limit-exceeded", null);
        var ok = _blocked(logger, "right after the second 429", true);
        Quota.nowOverride = t + 3700 + 3600;
        ok = ok && _blocked(logger, "an hour after the second 429", false);
        Quota.nowOverride = null;
        return ok;
    }

    // What 1.2.0 stored after a rate-limit-exceeded: remaining 0 and no reset
    // time. A watch updated from 1.2.0 in that state may ask again at once.
    (:test)
    function aZeroLeftBy120NoLongerBlocks(logger as Logger) as Boolean {
        Quota.clear();
        Storage.setValue(Quota.STORAGE_KEY, { "remaining" => 0, "retryAfterUntil" => null });
        return _blocked(logger, "the stuck state of 1.2.0", false);
    }

    // A Retry-After shorter than the hour, if one is ever readable, sets the
    // reset; a known reset still ahead is kept.
    (:test)
    function aKnownResetOrRetryAfterSetsTheEnd(logger as Logger) as Boolean {
        Quota.clear();
        var t = 1700000000;
        Quota.nowOverride = t;
        Quota.recordRateLimited("rate-limit-exceeded", 600);
        var ok = _eqN(logger, "reset from Retry-After", Quota.secondsUntilReset(), 600);
        Quota.clear();
        Quota.recordHeaders(20, 1, 900);
        Quota.recordRateLimited("rate-limit-exceeded", null);
        ok = ok && _eqN(logger, "a known reset still ahead", Quota.secondsUntilReset(), 900);
        Quota.nowOverride = null;
        return ok;
    }

    function _blocked(logger as Logger, when as String, want as Boolean) as Boolean {
        if (Quota.canSpend() == want) {
            logger.error(when + ": expected " + (want ? "blocked" : "allowed"));
            return false;
        }
        return true;
    }

    function _eqN(logger as Logger, what as String, got as Number?, want as Number?) as Boolean {
        if (got != want) {
            logger.error(what + ": expected " + (want == null ? "null" : want.toString())
                + ", got " + (got == null ? "null" : got.toString()));
            return false;
        }
        return true;
    }

    // A later successful response is proof the app was not actually blocked
    // any more, so it clears a stale Retry-After gate rather than leaving the
    // app stuck until some remembered deadline.
    (:test)
    function aLaterSuccessClearsTheRetryAfterGate(logger as Logger) as Boolean {
        Quota.clear();
        Quota.recordRateLimited("rate-limit-exceeded", 3600);
        if (Quota.canSpend()) {
            logger.error("setup: should be gated immediately after a 429");
            return false;
        }

        Quota.recordHeaders(20, 19, 3600);
        if (!Quota.canSpend()) {
            logger.error("a later successful response must clear the Retry-After gate");
            return false;
        }
        return true;
    }

}
