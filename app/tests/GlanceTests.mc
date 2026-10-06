import Toybox.Lang;
import Toybox.Test;

// Unit tests for ui/GlanceView.mc's GlanceFormat module (US-034): the "no
// cached data at all" detection, text formatting, and the age-bucket text
// that stands in for the exact age StatusView shows. GlanceFormat is pure
// and side-effect-free (no Storage/Cache access of its own, see that
// module's own comment) specifically so it can be exercised here without
// constructing a live WatchUi.GlanceView or a Graphics.Dc, matching this
// project's existing convention (tests/ControlTilesTests.mc for
// ui/ControlsView.mc's own ControlTiles module).
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
    // show the summary line instead, matching ControlsView's own top strip
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
        if (!GlanceFormat.socText(null).equals(GlanceFormat.EM_DASH)) {
            logger.error("expected the em dash for a missing SoC, never '0%%'");
            return false;
        }
        return true;
    }

    (:test)
    function lockTextMapsYesNoAndPassesThroughUnknownValues(logger as Logger) as Boolean {
        if (!GlanceFormat.lockText("YES").equals("LOCKED")) {
            logger.error("YES must map to LOCKED");
            return false;
        }
        if (!GlanceFormat.lockText("NO").equals("UNLOCKED")) {
            logger.error("NO must map to UNLOCKED");
            return false;
        }
        // openapi.json documents that clients "must tolerate values they do
        // not recognize": same convention ControlsView._lockLabel() and
        // VehicleState.mc's _statusValues() already follow.
        if (!GlanceFormat.lockText("PARTIALLY_LOCKED").equals("PARTIALLY_LOCKED")) {
            logger.error("an unrecognised value must pass through verbatim, not be swallowed");
            return false;
        }
        if (!GlanceFormat.lockText(null).equals(GlanceFormat.EM_DASH)) {
            logger.error("expected the em dash for a missing lock reading");
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

    (:test)
    function ageTextBucketsByElapsedTime(logger as Logger) as Boolean {
        var now = 1000000;
        if (!GlanceFormat.ageText(null, now).equals("")) {
            logger.error("no captured-at time must produce an empty age line, not a bogus one");
            return false;
        }
        if (!GlanceFormat.ageText(now - 10, now).equals("just now")) {
            logger.error("under a minute must read 'just now'");
            return false;
        }
        if (!GlanceFormat.ageText(now - 300, now).equals("5 min ago")) {
            logger.error("300 seconds must read '5 min ago', got: " + GlanceFormat.ageText(now - 300, now));
            return false;
        }
        if (!GlanceFormat.ageText(now - 7200, now).equals("2 h ago")) {
            logger.error("7200 seconds must read '2 h ago'");
            return false;
        }
        if (!GlanceFormat.ageText(now - 172800, now).equals("2 d ago")) {
            logger.error("172800 seconds must read '2 d ago'");
            return false;
        }
        return true;
    }


    // A glance is a narrow band, and the state strings are built from
    // whatever the API returned: an unrecognised value can be far longer than
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
        var text = "72%  CHARGING";
        if (!GlanceFormat.truncated(text, 600, measurer()).equals(text)) {
            logger.error("text that fits must not be altered");
            return false;
        }
        return true;
    }

    (:test)
    function overlongTextIsTruncatedWithinTheWidth(logger as Logger) as Boolean {
        var text = "100%  ANOTHER_FUTURE_VALUE  UNLOCKED  17 hours ago";
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
        var out = GlanceFormat.truncated("ANOTHER_FUTURE_VALUE", 60, measurer());
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
