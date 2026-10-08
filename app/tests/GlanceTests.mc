import Toybox.Lang;
import Toybox.Test;

// Unit tests for ui/GlanceView.mc's GlanceFormat module (US-034, C6): the
// "no cached data at all" detection, text formatting, the short age, the SoC
// bar and the lock word the glance draws. GlanceFormat is pure and
// side-effect-free (no Storage/Cache access of its own) specifically so it
// can be exercised here without constructing a live WatchUi.GlanceView or a
// Graphics.Dc.
module GlanceTests {

    (:test)
    function noDataAtAllIsDetected(logger as Logger) as Boolean {
        if (GlanceFormat.hasAnyData(null, null, null)) {
            logger.error("all three inputs null must mean 'no data'");
            return false;
        }
        return true;
    }

    // US-034: "given no cached data exists, the glance invites me to open
    // the app": any ONE of the three sections being present is enough to
    // show the summary line instead, matching home's hero (HomeHero.mc),
    // which never insists on all three being present together.
    (:test)
    function anySingleFieldCountsAsData(logger as Logger) as Boolean {
        if (!GlanceFormat.hasAnyData(72, null, null)) {
            logger.error("state of charge alone must count as data");
            return false;
        }
        if (!GlanceFormat.hasAnyData(null, "CONNECT_CABLE", null)) {
            logger.error("charging state alone must count as data");
            return false;
        }
        if (!GlanceFormat.hasAnyData(null, null, "YES")) {
            logger.error("lock state alone must count as data");
            return false;
        }
        return true;
    }

    (:test)
    function socTextFormatsWholeAndFloatValues(logger as Logger) as Boolean {
        if (!GlanceFormat.socText(72).equals("72%")) {
            logger.error("expected '72%%' for a whole-number SoC");
            return false;
        }
        if (!GlanceFormat.socText(72.0).equals("72%")) {
            logger.error("expected '72%%' for a Float SoC, truncated not rounded-with-decimals");
            return false;
        }
        if (!GlanceFormat.socText(null).equals(Labels.DASH)) {
            logger.error("expected the dash for a missing SoC, never '0%%'");
            return false;
        }
        return true;
    }

    // C6 row 2: the glance shows the same sentence-case words as the app
    // (Labels.lock), not the old "LOCKED"/"UNLOCKED" or a raw enum.
    (:test)
    function lockWordIsSentenceCaseAndUnknownValuesAreHumanised(logger as Logger) as Boolean {
        if (!Labels.lock("YES").equals("Locked")) {
            logger.error("YES must read 'Locked', got: " + Labels.lock("YES"));
            return false;
        }
        if (!Labels.lock("NO").equals("Unlocked")) {
            logger.error("NO must read 'Unlocked'");
            return false;
        }
        // openapi.json: clients "must tolerate values they do not recognize";
        // tolerated means humanised, never drawn raw (A16).
        if (!Labels.lock("PARTIALLY_LOCKED").equals("Partially locked")) {
            logger.error("an unrecognised value must be humanised, got: " + Labels.lock("PARTIALLY_LOCKED"));
            return false;
        }
        if (!Labels.lock(null).equals(Labels.DASH)) {
            logger.error("expected the dash for a missing lock reading");
            return false;
        }
        return true;
    }

    (:test)
    function newerAgeTakesTheLargerTimestampAndToleratesEitherMissing(logger as Logger) as Boolean {
        if (GlanceFormat.newerAge(100, 200) != 200) {
            logger.error("expected the larger (more recent) of two ages");
            return false;
        }
        if (GlanceFormat.newerAge(null, 200) != 200) {
            logger.error("one age missing must fall back to the other");
            return false;
        }
        if (GlanceFormat.newerAge(100, null) != 100) {
            logger.error("one age missing must fall back to the other (reversed)");
            return false;
        }
        if (GlanceFormat.newerAge(null, null) != null) {
            logger.error("both ages missing must stay null, never invent a value");
            return false;
        }
        return true;
    }

    // C6 row 1: the short age form shared with the app (Age.short), no "ago";
    // stale (US-009, over an hour) gets "! " so it survives monochrome.
    (:test)
    function ageTextUsesTheShortSharedFormat(logger as Logger) as Boolean {
        var now = 1000000;
        var cases = [
            [10, "Just now"],
            [300, "5 min"],
            [3600, "1 h"],
            [7200, "! 2 h"],
            [172800, "! 2 d"]
        ] as Array<[Number, String]>;
        for (var i = 0; i < cases.size(); i += 1) {
            var c = cases[i];
            var got = GlanceFormat.ageText(now - c[0], now);
            if (!got.equals(c[1])) {
                logger.error(c[0].toString() + " s must read '" + c[1] + "', got: '" + got + "'");
                return false;
            }
        }
        if (!GlanceFormat.ageText(null, now).equals("")) {
            logger.error("no captured-at time must produce an empty age, not a bogus one");
            return false;
        }
        if (!GlanceFormat.ageText(now + 60, now).equals("Just now")) {
            logger.error("a capture time in the future (clock skew) must read 'Just now'");
            return false;
        }
        return true;
    }

    // C6 row 3: the bar fill is proportional, clamped, and empty without a
    // numeric reading.
    (:test)
    function barFillIsProportionalAndClamped(logger as Logger) as Boolean {
        if (GlanceFormat.barFill(50, 160) != 80) {
            logger.error("50% of 160 px must fill 80, got " + GlanceFormat.barFill(50, 160));
            return false;
        }
        if (GlanceFormat.barFill(100.0, 159) != 159) {
            logger.error("a full Float SoC must fill the whole bar");
            return false;
        }
        if (GlanceFormat.barFill(140, 159) != 159 || GlanceFormat.barFill(-5, 159) != 0) {
            logger.error("out-of-range SoC must clamp to the bar");
            return false;
        }
        if (GlanceFormat.barFill(null, 159) != 0 || GlanceFormat.barFill("80", 159) != 0) {
            logger.error("no numeric SoC must leave the bar empty");
            return false;
        }
        return true;
    }

    // A glance is a narrow band, and the lock word is built from whatever the
    // API returned: an unrecognised value, humanised, can be far longer than
    // anything anticipated. It used to be drawn straight and run off the right
    // edge, which is what "ANOTHER_FUTURE_VALUE" did.
    class FixedWidthFont {
        function initialize() {}
        function width(s as String) as Number {
            return s.length() * 6;
        }
    }

    function measurer() as Method(s as String) as Number {
        return (new FixedWidthFont()).method(:width);
    }

    (:test)
    function shortTextIsLeftAlone(logger as Logger) as Boolean {
        var text = "72%";
        if (!GlanceFormat.truncated(text, 600, measurer()).equals(text)) {
            logger.error("text that fits must not be altered");
            return false;
        }
        return true;
    }

    (:test)
    function overlongTextIsTruncatedWithinTheWidth(logger as Logger) as Boolean {
        var text = "Another future value from the API";
        var out = GlanceFormat.truncated(text, 120, measurer());
        if (out.length() * 6 > 120) {
            logger.error("still too wide: " + out.length() * 6 + "px for a 120px band");
            return false;
        }
        if (out.length() >= text.length()) {
            logger.error("nothing was trimmed");
            return false;
        }
        return true;
    }

    (:test)
    function truncationIsMarked(logger as Logger) as Boolean {
        var out = GlanceFormat.truncated("Another future value", 60, measurer());
        if (out.find("…") == null) {
            logger.error("a cut must be visible, got '" + out + "'");
            return false;
        }
        return true;
    }

    (:test)
    function aBandWithNoRoomProducesNothing(logger as Logger) as Boolean {
        if (!GlanceFormat.truncated("anything", 0, measurer()).equals("")) {
            logger.error("zero width should produce an empty string, not a crash");
            return false;
        }
        return true;
    }

}
