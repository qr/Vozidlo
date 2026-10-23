import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;

// Unit tests for ui/ChargingFormat.mc (US-023, C3): which detail rows exist
// and what they say. The rule that matters most is "rows with missing data
// are left out", so most cases feed nulls.
module ChargingFormatTests {

    function _rowsEqual(logger as Logger, actual as Array<String>, expected as Array<String>) as Boolean {
        if (actual.size() != expected.size()) {
            logger.error("expected " + expected.size().toString() + " rows, got " + actual.size().toString() + ": " + actual.toString());
            return false;
        }
        for (var i = 0; i < expected.size(); i += 1) {
            if (!actual[i].equals(expected[i])) {
                logger.error("row " + i.toString() + ": expected '" + expected[i] + "', got '" + actual[i] + "'");
                return false;
            }
        }
        return true;
    }

    // Nothing known: no rows at all, never "Power: —".
    (:test)
    function detailRowsEmptyWhenNothingIsKnown(logger as Logger) as Boolean {
        var rows = ChargingFormat.detailRows(null, null, null, null, null, 2);
        return _rowsEqual(logger, rows, [] as Array<String>);
    }

    // The mock's default car: plugged in, not charging, only range known.
    (:test)
    function detailRowsShowOnlyRangeWhenParkedOnTheCable(logger as Logger) as Boolean {
        var rows = ChargingFormat.detailRows(null, "OFF", null, null, 36000, 2);
        return _rowsEqual(logger, rows, ["36 km range"] as Array<String>);
    }

    // A live charging session fills both slots; range drops off (PoC).
    (:test)
    function detailRowsWhileChargingPreferPowerAndFullBy(logger as Logger) as Boolean {
        var epoch = 1760000000;
        var rows = ChargingFormat.detailRows(7.2, "AC", epoch, 95, 19800, 2);
        var expected = ["7.2 kW · AC", "Full by " + ChargingFormat.clockAt(epoch) + " (95 min)"] as Array<String>;
        return _rowsEqual(logger, rows, expected);
    }

    // Cached data never carries fullyChargedAt; the remaining minutes alone
    // still make a row, and range moves up into the free slot.
    (:test)
    function detailRowsWithoutFullyChargedAtUseRemainingMinutes(logger as Logger) as Boolean {
        var rows = ChargingFormat.detailRows(11, "AC", null, 40, 19800, 2);
        return _rowsEqual(logger, rows, ["11 kW · AC", "Full in 40 min"] as Array<String>);
    }

    (:test)
    function detailRowsNeverExceedMaxRows(logger as Logger) as Boolean {
        var rows = ChargingFormat.detailRows(7.4, "DC", null, 30, 50000, 3);
        var expected = ["7.4 kW · DC fast", "Full in 30 min", "50 km range"] as Array<String>;
        if (!_rowsEqual(logger, rows, expected)) {
            return false;
        }
        return _rowsEqual(logger, ChargingFormat.detailRows(7.4, "DC", null, 30, 50000, 1),
            ["7.4 kW · DC fast"] as Array<String>);
    }

    // OFF is the chip's job; the power alone still makes a row, and a type
    // alone (power not reported) too.
    (:test)
    function powerRowLeavesOutMissingHalves(logger as Logger) as Boolean {
        var a = ChargingFormat.powerRow(3.6, "OFF");
        var b = ChargingFormat.powerRow(null, "AC");
        var c = ChargingFormat.powerRow(null, "OFF");
        if (a == null || !a.equals("3.6 kW")) {
            logger.error("expected '3.6 kW', got " + (a != null ? a : "null"));
            return false;
        }
        if (b == null || !b.equals("AC")) {
            logger.error("expected 'AC', got " + (b != null ? b : "null"));
            return false;
        }
        if (c != null) {
            logger.error("OFF without power must give no row, got '" + c + "'");
            return false;
        }
        return true;
    }

    (:test)
    function fullRowCombinesClockAndMinutes(logger as Logger) as Boolean {
        var both = ChargingFormat.fullRow("18:40", 95);
        var clockOnly = ChargingFormat.fullRow("18:40", null);
        if (both == null || !both.equals("Full by 18:40 (95 min)")) {
            logger.error("unexpected combined row: " + (both != null ? both : "null"));
            return false;
        }
        if (clockOnly == null || !clockOnly.equals("Full by 18:40")) {
            logger.error("unexpected clock-only row: " + (clockOnly != null ? clockOnly : "null"));
            return false;
        }
        if (ChargingFormat.fullRow(null, null) != null) {
            logger.error("no clock and no minutes must give no row");
            return false;
        }
        return true;
    }

    // Metres to whole km, rounded; a value of the wrong type is missing.
    (:test)
    function rangeRowRoundsToKilometres(logger as Logger) as Boolean {
        var r = ChargingFormat.rangeRow(19800);
        if (r == null || !r.equals("20 km range")) {
            logger.error("expected '20 km range', got " + (r != null ? r : "null"));
            return false;
        }
        if (ChargingFormat.rangeRow("36000") != null) {
            logger.error("a string must be treated as missing, not parsed");
            return false;
        }
        return true;
    }

    (:test)
    function clockPadsToTwoDigits(logger as Logger) as Boolean {
        var s = ChargingFormat.clock(8, 5);
        if (!s.equals("08:05")) {
            logger.error("expected '08:05', got '" + s + "'");
            return false;
        }
        return true;
    }

    // Whole kW without a decimal, fractional with one, Long and Double
    // accepted like their smaller siblings.
    (:test)
    function powerTextHandlesEveryJsonNumberType(logger as Logger) as Boolean {
        var cases = [[11, "11"], [7.26, "7.3"], [22L, "22"], [7.4d, "7.4"]] as Array<Array>;
        for (var i = 0; i < cases.size(); i += 1) {
            var got = ChargingFormat.powerText(cases[i][0] as Object);
            var want = cases[i][1] as String;
            if (got == null || !got.equals(want)) {
                logger.error("case " + i.toString() + ": expected '" + want + "', got " + (got != null ? got : "null"));
                return false;
            }
        }
        return true;
    }

    // ------------------------------------------------------------ layout

    function _heroH(g as Geo.Display) as Number {
        return g.heroFont == Graphics.FONT_NUMBER_MEDIUM ? g.fonts.numMedH : g.fonts.numMildH;
    }

    // C3 on the fēnix 7 Pro, today's numbers: title 34, hero 58, chip 134,
    // rows from 160 at a 20 px pitch, age 202, no data 98 / 136.
    (:test)
    function fenix7proChargingSlotsAreToday(logger as Logger) as Boolean {
        var g = GeoTests.fenix7pro();
        var sl = ChargingFormat.slots(g, g.titleTop, _heroH(g));
        return GeoTests._eq(logger, "heroTop", sl.heroTop, 58)
            && GeoTests._eq(logger, "chipTop", sl.chipTop, 134)
            && GeoTests._eq(logger, "rowsTop", sl.rowsTop, 160)
            && GeoTests._eq(logger, "pitch", sl.pitch, 20)
            && GeoTests._eq(logger, "ageTop", sl.ageTop, 202)
            && GeoTests._eq(logger, "maxRows", sl.maxRows, 2)
            && GeoTests._eq(logger, "noDataTop", sl.noDataTop, 98)
            && GeoTests._eq(logger, "noDataSubTop", sl.noDataSubTop, 136);
    }

    // M1: the hero font was picked so both detail rows clear the age line,
    // so every watch keeps two; a taller FONT_XTINY drops the second one
    // rather than overlapping the age.
    (:test)
    function chargingRowsClearTheAgeOnEveryFixture(logger as Logger) as Boolean {
        var all = GeoTests.all();
        for (var i = 0; i < all.size(); i += 1) {
            var g = all[i] as Geo.Display;
            var sl = ChargingFormat.slots(g, g.titleTop, _heroH(g));
            if (sl.maxRows != 2) {
                logger.error(GeoTests.describe(g) + ": expected two detail rows, got " + sl.maxRows.toString());
                return false;
            }
        }
        var tall = Geo.make(260, 260, true, Geo.INPUT_A, true, new Geo.Fonts(24, 29, 32, 37, 60, 74));
        var t = ChargingFormat.slots(tall, tall.titleTop, _heroH(tall));
        return GeoTests._eq(logger, "tall xtiny rows", t.maxRows, 1);
    }

    // PoC NC.profile on the fēnix 7 Pro, today's numbers: title 40, name
    // 70, chip 108, facts 136 at 19 px, timers from 178 with room for
    // three by 216, states 104 / 136, errors 112.
    (:test)
    function fenix7proProfileSlotsAreToday(logger as Logger) as Boolean {
        var g = GeoTests.fenix7pro();
        var tTop = ChargingFormat.profileTitleTop(g);
        var sl = ChargingFormat.profileSlots(g, tTop);
        var timersTop = sl.factsTop + 2 * sl.pitch + sl.timerGap;
        return GeoTests._eq(logger, "title", tTop, 40)
            && GeoTests._eq(logger, "nameTop", sl.nameTop, 70)
            && GeoTests._eq(logger, "chipTop", sl.chipTop, 108)
            && GeoTests._eq(logger, "factsTop", sl.factsTop, 136)
            && GeoTests._eq(logger, "pitch", sl.pitch, 19)
            && GeoTests._eq(logger, "timersTop", timersTop, 178)
            && GeoTests._eq(logger, "lastTop", sl.lastTop, 216)
            && GeoTests._eq(logger, "timer room", sl.timerRoom(timersTop), 3)
            && GeoTests._eq(logger, "room under a third fact", sl.timerRoom(timersTop + sl.pitch), 2)
            && GeoTests._eq(logger, "no room past the last line", sl.timerRoom(sl.lastTop + 1), 0)
            && GeoTests._eq(logger, "stateTop", sl.stateTop, 104)
            && GeoTests._eq(logger, "stateSubTop", sl.stateSubTop, 136)
            && GeoTests._eq(logger, "errorTop", sl.errorTop, 112);
    }

}
