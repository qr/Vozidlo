import Toybox.Lang;
import Toybox.Test;

// Unit tests for the pure layout of ui/StatusPages.mc: the page slots and
// the M12 lock grid, on the display fixtures of tests/GeoTests.mc. The
// fēnix 7 Pro pins are today's numbers (decisions.md "Layouts follow the
// screen"); the other watches check the M12 rules: squeeze before "+N",
// and the indicator keep-out moving only the right edge.
module StatusLayoutTests {

    // FONT_XTINY label widths per screen, from the device fonts
    // (tools/ui/devices/11-devdata.js). A table, not a real font, so the
    // grid runs on any simulator.
    class LabelWidths {
        private var _widths as Dictionary<String, Number>;

        function initialize(widths as Dictionary<String, Number>) {
            _widths = widths;
        }

        function width(s as String) as Number {
            var w = _widths.get(s);
            return w != null ? w : 0;
        }
    }

    function _measurer(widths as Dictionary<String, Number>) as Method(s as String) as Number {
        return (new LabelWidths(widths)).method(:width);
    }

    function _fenixWidths() as Method(s as String) as Number {
        return _measurer({ "Doors" => 37, "Windows" => 57, "Bonnet" => 46, "Trunk" => 38, "Lights" => 40, "Sunroof" => 51 });
    }

    function _venu3sWidths() as Method(s as String) as Number {
        return _measurer({ "Doors" => 73, "Windows" => 112, "Bonnet" => 87, "Trunk" => 69, "Lights" => 75, "Sunroof" => 97 });
    }

    function _vivoactive6Widths() as Method(s as String) as Number {
        return _measurer({ "Doors" => 69, "Windows" => 105, "Bonnet" => 81, "Trunk" => 65, "Lights" => 70, "Sunroof" => 91 });
    }

    function _venu445mmWidths() as Method(s as String) as Number {
        return _measurer({ "Doors" => 84, "Windows" => 129, "Bonnet" => 99, "Trunk" => 80, "Lights" => 86, "Sunroof" => 111 });
    }

    // The mock car (sunroof unsupported, trunk open): five items, the open
    // one first.
    function _fiveItems() as Array<Chips.Chip> {
        return StatusPages.lockItems({ "doors" => "CLOSED", "windows" => "CLOSED", "bonnet" => "CLOSED",
            "trunk" => "OPEN", "lights" => "OFF", "sunroof" => "UNSUPPORTED" });
    }

    function _sixItems() as Array<Chips.Chip> {
        return StatusPages.lockItems({ "doors" => "CLOSED", "windows" => "OPEN", "bonnet" => "CLOSED",
            "trunk" => "OPEN", "lights" => "OFF", "sunroof" => "CLOSED" });
    }

    function _grid(g as Geo.Display, chips as Array<Chips.Chip>, measure as Method(s as String) as Number) as StatusPages.Grid {
        var sl = StatusPages.slots(g, g.titleTop);
        return StatusPages.grid(g, StatusPages.labelWidths(chips, measure), sl.wordTop + g.fonts.mediumH, sl.ageTop);
    }

    // Every chip clears the age line (the clearance of the step used) and
    // stays inside the span of its rows.
    function _clear(logger as Logger, what as String, g as Geo.Display, t as StatusPages.Grid) as Boolean {
        var sl = StatusPages.slots(g, g.titleTop);
        var sq = StatusPages.SQUEEZE[t.step] as Array<Number>;
        if (t.bottom() > sl.ageTop - g.px(sq[2] as Number)) {
            logger.error(what + ": grid bottom " + t.bottom().toString() + " reaches the age line " + sl.ageTop.toString());
            return false;
        }
        for (var i = 0; i < t.count(); i += 1) {
            var sp = g.span(t.chipY(i), t.chipY(i) + t.hc, Theme.RING_MARGIN);
            if (t.chipX(i) < sp[0] || t.chipX(i) + t.w > sp[1]) {
                logger.error(what + ": chip " + i.toString() + " at x " + t.chipX(i).toString() + " leaves the span "
                    + sp[0].toString() + ".." + sp[1].toString());
                return false;
            }
        }
        return true;
    }

    // ------------------------------------------------------------ fēnix pins

    // Today's coordinates: title 34, value 64, word 70, grid 116, AC lines
    // 128, value lines 142, pitch 20, age 192, status 212, empty 98 / 136.
    (:test)
    function fenix7proSlotsAreToday(logger as Logger) as Boolean {
        var g = GeoTests.fenix7pro();
        var sl = StatusPages.slots(g, g.titleTop);
        return GeoTests._eq(logger, "title", g.titleTop, 34)
            && GeoTests._eq(logger, "valueTop", sl.valueTop, 64)
            && GeoTests._eq(logger, "wordTop", sl.wordTop, 70)
            && GeoTests._eq(logger, "gridTop", sl.gridTop, 116)
            && GeoTests._eq(logger, "acLinesTop", sl.acLinesTop, 128)
            && GeoTests._eq(logger, "value lines", sl.valueTop + g.fonts.numMedH + g.px(4), 142)
            && GeoTests._eq(logger, "pitch", sl.pitch, 20)
            && GeoTests._eq(logger, "ageTop", sl.ageTop, 192)
            && GeoTests._eq(logger, "statusTop", sl.statusTop, 212)
            && GeoTests._eq(logger, "emptyTop", sl.emptyTop, 98)
            && GeoTests._eq(logger, "emptySubTop", sl.emptySubTop, 136);
    }

    // C2 grid: W 89 at x 38 / 133, chip height 22, pitch 24, rows from 116,
    // a lone fifth chip centred at x 86; six items fill the third row.
    (:test)
    function fenix7proGridIsToday(logger as Logger) as Boolean {
        var g = GeoTests.fenix7pro();
        var t = _grid(g, _fiveItems(), _fenixWidths());
        var six = _grid(g, _sixItems(), _fenixWidths());
        return GeoTests._eq(logger, "shown", t.shown, 5) && GeoTests._eq(logger, "more", t.more, 0)
            && GeoTests._eq(logger, "squeeze step", t.step, 0)
            && GeoTests._eq(logger, "W", t.w, 89) && GeoTests._eq(logger, "Hc", t.hc, 22)
            && GeoTests._eq(logger, "pitch", t.pitch, 24) && GeoTests._eq(logger, "top", t.top, 116)
            && GeoTests._eq(logger, "x left", t.chipX(0), 38) && GeoTests._eq(logger, "x right", t.chipX(1), 133)
            && GeoTests._eq(logger, "x lone", t.chipX(4), 86) && GeoTests._eq(logger, "row 3 y", t.chipY(4), 164)
            && GeoTests._eq(logger, "six shown", six.shown, 6) && GeoTests._eq(logger, "six W", six.w, 89)
            && GeoTests._eq(logger, "six x left", six.chipX(4), 38) && GeoTests._eq(logger, "six x right", six.chipX(5), 133)
            && _clear(logger, "fēnix 7 Pro", g, t) && _clear(logger, "fēnix 7 Pro six", g, six);
    }

    // ------------------------------------------------------------ M12

    // Venu 3S: three rows only fit with every squeeze step (word to grid
    // gap, row gap, age clearance), and then all five items show.
    (:test)
    function venu3sSqueezesToShowAllFive(logger as Logger) as Boolean {
        var g = GeoTests.venu3s();
        var t = _grid(g, _fiveItems(), _venu3sWidths());
        return GeoTests._eq(logger, "shown", t.shown, 5) && GeoTests._eq(logger, "more", t.more, 0)
            && GeoTests._eq(logger, "squeeze step", t.step, 3)
            && GeoTests._eq(logger, "top", t.top, 161) && GeoTests._eq(logger, "pitch", t.pitch, 39)
            && GeoTests._eq(logger, "W fits Windows", t.w, 112 + g.px(30))
            && _clear(logger, "Venu 3S", g, t);
    }

    // Venu 4 45 mm: the first squeeze step is enough for five items; with
    // the indicator on, the grid moves left of it at the same width.
    (:test)
    function venu445mmSqueezesToShowAllFive(logger as Logger) as Boolean {
        var g = GeoTests.venu445mm();
        var t = _grid(g, _fiveItems(), _venu445mmWidths());
        g.keepOut = true;
        var k = _grid(g, _fiveItems(), _venu445mmWidths());
        var limit = (g.hint as Array<Number>)[0] - g.px(8);
        return GeoTests._eq(logger, "shown", t.shown, 5) && GeoTests._eq(logger, "more", t.more, 0)
            && GeoTests._eq(logger, "squeeze step", t.step, 1)
            && GeoTests._eq(logger, "W", t.w, 181) && GeoTests._eq(logger, "x0 centred", t.x0, 41)
            && GeoTests._eq(logger, "keep-out shown", k.shown, 5) && GeoTests._eq(logger, "keep-out W", k.w, 181)
            && GeoTests._eq(logger, "keep-out x0", k.x0, 34)
            && GeoTests._eq(logger, "keep-out right edge", k.x0 + k.gridW, limit)
            && _clear(logger, "Venu 4 45 mm", g, k);
    }

    // vívoactive 6 with the indicator: the right edge stops px(8) short of
    // it, the grid shifts left instead of shrinking, and "Windows" keeps
    // its full width in the chip.
    (:test)
    function vivoactive6KeepOutShiftsTheGridLeft(logger as Logger) as Boolean {
        var g = GeoTests.vivoactive6();
        var t = _grid(g, _fiveItems(), _vivoactive6Widths());
        g.keepOut = true;
        var k = _grid(g, _fiveItems(), _vivoactive6Widths());
        var limit = (g.hint as Array<Number>)[0] - g.px(8);
        if (k.x0 + k.gridW > limit) {
            logger.error("grid right edge " + (k.x0 + k.gridW).toString() + " passes the keep-out " + limit.toString());
            return false;
        }
        if (k.x0 >= t.x0 || k.w != t.w) {
            logger.error("under the keep-out the grid must shift left at the same width");
            return false;
        }
        var text = Ui.fit("Windows", k.w - g.px(24), _vivoactive6Widths());
        return GeoTests._eq(logger, "x0 centred", t.x0, 41) && GeoTests._eq(logger, "keep-out x0", k.x0, 40)
            && GeoTests._eq(logger, "squeeze step", k.step, 0) && GeoTests._eq(logger, "shown", k.shown, 5)
            && StatusPagesTests._expect(logger, "Windows label", text, "Windows")
            && _clear(logger, "vívoactive 6", g, k);
    }

    // When no squeeze makes three rows fit (a large FONT_XTINY), two rows
    // with "+N" take over; the open items come first, so they stay.
    (:test)
    function tightScreenFallsBackToPlusN(logger as Logger) as Boolean {
        var g = Geo.make(260, 260, true, Geo.INPUT_A, true, new Geo.Fonts(24, 29, 32, 37, 60, 74));
        var chips = _sixItems();
        var t = _grid(g, chips, _fenixWidths());
        if (!GeoTests._eq(logger, "shown", t.shown, 3) || !GeoTests._eq(logger, "more", t.more, 3)
            || !GeoTests._eq(logger, "chips drawn", t.count(), 4) || !_clear(logger, "tight", g, t)) {
            return false;
        }
        if ((chips[0] as Chips.Chip).kind != :warn || (chips[1] as Chips.Chip).kind != :warn) {
            logger.error("open items must be among the chips shown");
            return false;
        }
        var more = StatusPages.moreChip(chips, t.shown);
        var allOpen = StatusPages.lockItems({ "doors" => "OPEN", "windows" => "OPEN", "bonnet" => "OPEN",
            "trunk" => "OPEN", "lights" => "ON", "sunroof" => "CLOSED" });
        var hidesOpen = StatusPages.moreChip(allOpen, 3);
        if (more.kind != :outline || hidesOpen.kind != :warn) {
            logger.error("+N is an outline, amber only when it hides an open item");
            return false;
        }
        return StatusPagesTests._expect(logger, "+N text", more.text, "+3")
            && StatusPagesTests._expect(logger, "+N over five", hidesOpen.text, "+3");
    }

    // On every fixture the grid clears the age line and stays inside the
    // outline, with all six items where the screen allows it. The 218 px
    // Forerunner 255S is the one screen where it does not: three rows do
    // not fit above the age even fully squeezed, so it shows three items
    // and "+3" (M12; open items sort first, so none hides behind it).
    (:test)
    function gridFitsOnEveryFixture(logger as Logger) as Boolean {
        var all = GeoTests.all();
        for (var i = 0; i < all.size(); i += 1) {
            var g = all[i] as Geo.Display;
            var measure = g.w > 300 ? _venu445mmWidths() : _fenixWidths();
            var t = _grid(g, _sixItems(), measure);
            if (!_clear(logger, GeoTests.describe(g), g, t)) {
                return false;
            }
            var behind = g.w == 218 ? 3 : 0;
            if (t.more != behind) {
                logger.error(GeoTests.describe(g) + ": expected " + behind.toString() + " behind +N, got " + t.more.toString());
                return false;
            }
        }
        return true;
    }

}
