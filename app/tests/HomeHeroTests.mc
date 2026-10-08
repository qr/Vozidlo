import Toybox.Lang;
import Toybox.Test;

// Unit tests for the pure layout and data maths of ui/HomeHero.mc (C1b).
module HomeHeroTests {

    (:test)
    function socTextIsWholePercentOrDash(logger as Logger) as Boolean {
        if (!HomeHero.socText(80).equals("80") || !HomeHero.socText(80.6).equals("80")) {
            logger.error("SoC must show as a whole percent");
            return false;
        }
        if (!HomeHero.socText(null).equals(Labels.DASH) || !HomeHero.socText("x").equals(Labels.DASH)) {
            logger.error("missing or odd SoC must show a dash");
            return false;
        }
        return true;
    }

    (:test)
    function socFracIsClamped(logger as Logger) as Boolean {
        if (HomeHero.socFrac(null) != 0.0 || HomeHero.socFrac(150) != 1.0 || HomeHero.socFrac(-5) != 0.0) {
            logger.error("ring fill must stay within 0..1, no data empty");
            return false;
        }
        var half = HomeHero.socFrac(50.0);
        if (half < 0.49 || half > 0.51) {
            logger.error("50 % must fill half the ring");
            return false;
        }
        return true;
    }

    // Feedback survives the onShow() that follows it (the pop of a
    // confirmation) and goes on the first onShow() after home drew it, so a
    // missing phone or a stale age shows again.
    (:test)
    function feedbackClearsOnceItWasShown(logger as Logger) as Boolean {
        var kept = HomeHero.feedbackAfterShow(Commands.SENT, false);
        if (kept == null || !kept.equals(Commands.SENT)) {
            logger.error("feedback not drawn yet must survive onShow");
            return false;
        }
        if (HomeHero.feedbackAfterShow(Commands.SENT, true) != null) {
            logger.error("feedback already drawn must clear on the next onShow");
            return false;
        }
        if (HomeHero.feedbackAfterShow(null, false) != null) {
            logger.error("no feedback stays no feedback");
            return false;
        }
        var line = HomeHero.statusLine(HomeHero.feedbackAfterShow(Commands.SENT, true), :sent, false, 60);
        if (!line[0].equals(Commands.NO_PHONE)) {
            logger.error("once cleared, the missing phone must show, got " + line[0]);
            return false;
        }
        return true;
    }

    // Feedback > phone offline > age (stale in amber).
    (:test)
    function statusLinePriority(logger as Logger) as Boolean {
        var a = HomeHero.statusLine("Command sent", :sent, false, 99999);
        if (!a[0].equals("Command sent") || a[1] != :sent) {
            logger.error("command feedback must win");
            return false;
        }
        var b = HomeHero.statusLine(null, :sent, false, 60);
        if (!b[0].equals(Commands.NO_PHONE) || b[1] != :error) {
            logger.error("no phone must come next");
            return false;
        }
        var c = HomeHero.statusLine(null, :sent, true, 17 * 3600);
        if (c[1] != :warn || c[0].find("!") != 0) {
            logger.error("stale data must be an amber ! line, got " + c[0]);
            return false;
        }
        var d = HomeHero.statusLine(null, :sent, true, 120);
        if (d[1] != :age || !d[0].equals("2 min ago")) {
            logger.error("fresh data must be a plain age line, got " + d[0]);
            return false;
        }
        var e = HomeHero.statusLine(null, :sent, true, null);
        if (!e[0].equals("No data")) {
            logger.error("nothing cached must say No data");
            return false;
        }
        return true;
    }

    // fēnix 7 Pro: title 104, xtiny 19, chips 21. Status line sits on the
    // bottom, the chips above, the digits' baseline above those.
    (:test)
    function slotsStackFromTheBottom(logger as Logger) as Boolean {
        var y = HomeHero.slots(104, 19, 21, true);
        if (y[0] != 85 || y[1] != 62 || y[2] != 58) {
            logger.error("unexpected slots " + y[0].toString() + "/" + y[1].toString() + "/" + y[2].toString());
            return false;
        }
        var noChips = HomeHero.slots(104, 19, 21, false);
        if (noChips[1] != noChips[0] || noChips[2] != 81) {
            logger.error("without chips the hero must sit on the status line");
            return false;
        }
        return true;
    }

    // The numberMedium digits on fēnix 7 Pro (ascent 54) at baseline 58 rise
    // to about y 14: above that the "100%" corners meet the ring, which is why the
    // hero falls back to a smaller number font there.
    (:test)
    function digitTopErrsHigh(logger as Logger) as Boolean {
        if (HomeHero.digitTop(58, 54) != 14) {
            logger.error("expected digit top 14, got " + HomeHero.digitTop(58, 54).toString());
            return false;
        }
        return true;
    }

    (:test)
    function chipsDropFromTheEnd(logger as Logger) as Boolean {
        var widths = [80, 90, 70] as Array<Number>;
        if (HomeHero.chipsToKeep(widths, 6, 300) != 3) {
            logger.error("three chips in 252 px must all stay");
            return false;
        }
        if (HomeHero.chipsToKeep(widths, 6, 200) != 2) {
            logger.error("the climate chip goes first when the row is too wide");
            return false;
        }
        if (HomeHero.chipsToKeep(widths, 6, 50) != 0) {
            logger.error("nothing fits a 50 px row");
            return false;
        }
        return true;
    }

}
