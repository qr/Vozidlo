import Toybox.Lang;
import Toybox.Test;

// Unit tests for ui/Age.mc: the one age format (A17, B4) and the stale rule
// (US-009: older than an hour). Boundaries are where the format switches
// unit, which is where an off-by-one would show.
module AgeTests {

    function _expect(logger as Logger, seconds as Number, expected as String) as Boolean {
        var actual = Age.short(seconds);
        if (!actual.equals(expected)) {
            logger.error(seconds.toString() + " s: expected '" + expected + "', got '" + actual + "'");
            return false;
        }
        return true;
    }

    (:test)
    function shortSwitchesUnitAtTheBoundaries(logger as Logger) as Boolean {
        return _expect(logger, 0, "Just now")
            && _expect(logger, 59, "Just now")
            && _expect(logger, 60, "1 min")
            && _expect(logger, 3599, "59 min")
            && _expect(logger, 3600, "1 h")
            && _expect(logger, 3601, "1 h")
            && _expect(logger, 86399, "23 h")
            && _expect(logger, 86400, "1 d");
    }

    // "ago" only on age lines, and never "Just now ago".
    (:test)
    function textAddsAgoExceptForJustNow(logger as Logger) as Boolean {
        if (!Age.text(59).equals("Just now")) {
            logger.error("expected 'Just now', got '" + Age.text(59) + "'");
            return false;
        }
        if (!Age.text(300).equals("5 min ago")) {
            logger.error("expected '5 min ago', got '" + Age.text(300) + "'");
            return false;
        }
        if (!Age.text(3 * 86400).equals("3 d ago")) {
            logger.error("expected '3 d ago', got '" + Age.text(3 * 86400) + "'");
            return false;
        }
        return true;
    }

    // US-009: exactly an hour is still fresh; one second more is stale.
    (:test)
    function staleStartsAfterOneHour(logger as Logger) as Boolean {
        if (Age.isStale(3599) || Age.isStale(3600)) {
            logger.error("up to and including 3600 s must not be stale");
            return false;
        }
        if (!Age.isStale(3601)) {
            logger.error("3601 s must be stale");
            return false;
        }
        return true;
    }

    (:test)
    function lineMarksStaleAndMissingData(logger as Logger) as Boolean {
        if (!Age.line(null).equals("No data")) {
            logger.error("null must read 'No data', got '" + Age.line(null) + "'");
            return false;
        }
        if (!Age.line(3600).equals("1 h ago")) {
            logger.error("3600 s must read '1 h ago', got '" + Age.line(3600) + "'");
            return false;
        }
        if (!Age.line(3601).equals("! 1 h ago")) {
            logger.error("3601 s must read '! 1 h ago', got '" + Age.line(3601) + "'");
            return false;
        }
        return true;
    }

    // Phone and car clocks disagree: a capture time in the future is "now".
    (:test)
    function elapsedClampsNegativeSkewAndPassesNull(logger as Logger) as Boolean {
        if (Age.elapsed(null, 1000) != null) {
            logger.error("no capture time must stay null");
            return false;
        }
        var skew = Age.elapsed(1100, 1000);
        if (skew == null || skew != 0) {
            logger.error("a capture time in the future must clamp to 0");
            return false;
        }
        var normal = Age.elapsed(400, 1000);
        if (normal == null || normal != 600) {
            logger.error("expected 600 s elapsed");
            return false;
        }
        return true;
    }

}
