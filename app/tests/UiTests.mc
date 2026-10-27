import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

// Unit tests for the pure half of ui/Ui.mc. Measurers are arithmetic, like
// TextBlockTests: 6 px per character, so every expectation can be checked by
// hand. What is verified is the fitting logic, not Garmin's glyph metrics.
module UiTests {

    const PX = 6;

    class Fixed {
        function initialize() {}

        function width(s as String) as Number {
            return s.length() * PX;
        }

        // Per-font widths roughly in the fēnix 7 Pro ratio (medium 15,
        // small 13, tiny 11 px for a lower-case letter).
        function widthIn(s as String, font as Graphics.FontType) as Number {
            if (font == Graphics.FONT_MEDIUM) {
                return s.length() * 15;
            }
            if (font == Graphics.FONT_SMALL) {
                return s.length() * 13;
            }
            return s.length() * 11;
        }
    }

    function measurer() as Method(s as String) as Number {
        return (new Fixed()).method(:width);
    }

    function fontMeasurer() as Method(s as String, font as Graphics.FontType) as Number {
        return (new Fixed()).method(:widthIn);
    }

    // An unfocused row with a sub-label stacks label and sub as one block
    // centred in the row; measured fēnix 7 Pro heights (row 53, TINY 29,
    // XTINY 19) and the fēnix 8 / fr955 ones (55, 29, 21).
    (:test)
    function plainRowStacksLabelAndSubInTheRow(logger as Logger) as Boolean {
        var a = NightMenuLayout.plainLines(53, 29, 19);
        if (a[0] != 16 || a[1] != 40) {
            logger.error("fenix7pro: expected 16 and 40, got " + a[0] + " and " + a[1]);
            return false;
        }
        var b = NightMenuLayout.plainLines(55, 29, 21);
        if (b[0] - 29 / 2 < 0 || b[1] + 21 / 2 > 55) {
            logger.error("both lines must stay inside a 55 px row");
            return false;
        }
        return true;
    }

    // In a 65 px row the focus pill follows its text (FONT_MEDIUM 37 + 14 on
    // the fēnix 7 Pro, SMALL 32 + XTINY 19 + 14 with a sub-label) and never
    // grows past the row minus the inset on each side.
    (:test)
    function pillFollowsItsTextInsideTheRow(logger as Logger) as Boolean {
        if (NightMenuLayout.pillHeight(65, 37, 14, 3) != 51) {
            logger.error("plain pill should be 51 px");
            return false;
        }
        if (NightMenuLayout.pillHeight(65, 51, 14, 3) != 59) {
            logger.error("pill with a sub-label should be capped at 59 px");
            return false;
        }
        if (NightMenuLayout.pillHeight(53, 51, 14, 5) != 43) {
            logger.error("a pill must not outgrow the row minus the inset");
            return false;
        }
        return true;
    }

    // The rows above and below the focus sit one row off the centre, where the
    // circle is narrower: a TINY label there gets the chord at y 181..209, not
    // the full 193 px (fēnix 7 Pro). On the Venu 3S the row is cy + rowH.
    (:test)
    function neighbourRowsFitTheChord(logger as Logger) as Boolean {
        var g = GeoTests.fenix7pro();
        var w = NightMenuLayout.neighbourWidth(g, g.rowH, 29);
        if (w <= 0 || w >= 193 || w != Ui.usableIn(g, 181, 209, Theme.MARGIN)) {
            logger.error("unexpected neighbour width " + w);
            return false;
        }
        if (NightMenuLayout.neighbourWidth(g, g.rowH, 48) >= w) {
            logger.error("a taller block (label + sub) must get less width");
            return false;
        }
        var v = GeoTests.venu3s();
        var centre = v.cy + v.rowH;
        if (NightMenuLayout.neighbourWidth(v, v.rowH, 40) != Ui.usableIn(v, centre - 20, centre + 20, Theme.MARGIN)) {
            logger.error("the Venu 3S neighbour row must be measured one row below its centre");
            return false;
        }
        return true;
    }

    // A8: the number font has digits and a few symbols, no letters, no "—".
    (:test)
    function isNumberGlyphsRejectsLettersAndEmDash(logger as Logger) as Boolean {
        if (!Ui.isNumberGlyphs("100%") || !Ui.isNumberGlyphs("12.5") || !Ui.isNumberGlyphs("21°")) {
            logger.error("digits, % . and ° must be accepted");
            return false;
        }
        if (Ui.isNumberGlyphs("km") || Ui.isNumberGlyphs("Off") || Ui.isNumberGlyphs("12 km")) {
            logger.error("letters must be rejected");
            return false;
        }
        if (Ui.isNumberGlyphs("—")) {
            logger.error("the em dash must be rejected");
            return false;
        }
        if (Ui.isNumberGlyphs("")) {
            logger.error("an empty value has nothing to draw in a number font");
            return false;
        }
        return true;
    }

    // B4: truncate by pixels with "…", and never exceed the width given.
    (:test)
    function fitAddsEllipsisAndNeverExceeds(logger as Logger) as Boolean {
        var text = "Start ventilation now";
        if (!Ui.fit(text, 1000, measurer()).equals(text)) {
            logger.error("text that fits must be returned unchanged");
            return false;
        }
        for (var maxW = 0; maxW <= text.length() * PX; maxW += 5) {
            var s = Ui.fit(text, maxW, measurer());
            if (s.length() * PX > maxW) {
                logger.error("fit to " + maxW.toString() + " px returned '" + s + "', " + (s.length() * PX).toString() + " px");
                return false;
            }
        }
        var cut = Ui.fit(text, 60, measurer());
        if (!cut.equals("Start ven…")) {
            logger.error("expected 'Start ven…' at 60 px, got '" + cut + "'");
            return false;
        }
        // No space left in front of the ellipsis.
        var trimmed = Ui.fit(text, 42, measurer());
        if (!trimmed.equals("Start…")) {
            logger.error("expected 'Start…' at 42 px, got '" + trimmed + "'");
            return false;
        }
        return true;
    }

    // C8 step 2: usable = chord minus margins, wider margin narrows it; the
    // margin is in px of the 260 face and scales with the screen.
    (:test)
    function usableFollowsTheChordAndMargin(logger as Logger) as Boolean {
        var g = GeoTests.fenix7pro();
        var mid = Ui.usableIn(g, 120, 140, 8);
        if (mid != TextBlock.lineWidth(130, 130, 120, 140)) {
            logger.error("margin 8 must equal TextBlock.lineWidth");
            return false;
        }
        if (Ui.usableIn(g, 120, 140, 12) != mid - 8) {
            logger.error("margin 12 must take 4 px more from each side");
            return false;
        }
        if (Ui.usableIn(g, 250, 270, 12) != 0) {
            logger.error("a box outside the circle has no room, not a negative width");
            return false;
        }
        var v = GeoTests.venu3s();
        if (Ui.usableIn(v, 185, 205, 8) != 2 * TextBlock.halfChord(195, 10) - 2 * 12) {
            logger.error("on the Venu 3S the margin of 8 must scale to 12 px");
            return false;
        }
        return true;
    }

    // SG §5: a title that does not fit moves down 2 px at a time, at most
    // px(20), and stays put when it fits.
    (:test)
    function titleMovesDownBeforeItIsCut(logger as Logger) as Boolean {
        var g = GeoTests.fenix7pro();
        if (Ui.titleTop(g, 100, 34) != 34) {
            logger.error("a title that fits must stay at y 34");
            return false;
        }
        if (Ui.titleTop(g, 1000, 34) != 54) {
            logger.error("a title that never fits moves down 20 px, no more");
            return false;
        }
        // 190 px of TINY: does not fit at 40 (170 px there), fits a little lower.
        var t = Ui.titleTop(g, 190, 40);
        if (t <= 40 || t >= 60 || Ui.usableIn(g, t, t + 29, Theme.MARGIN) < 190
            || Ui.usableIn(g, t - 2, t + 27, Theme.MARGIN) >= 190) {
            logger.error("expected the first y where 190 px fit, got " + t.toString());
            return false;
        }
        var v = GeoTests.venu3s();
        if (Ui.titleTop(v, 2000, 51) != 51 + 30) {
            logger.error("on the Venu 3S the 20 px limit scales to 30");
            return false;
        }
        return true;
    }

    // C5: two lines at most, the second marked as cut.
    (:test)
    function wrapFitCapsLinesAndMarksTheCut(logger as Logger) as Boolean {
        var lines = Ui.wrapFit("Testlaan 1, 1000 AA Teststad, Netherlands", [60, 60] as Array<Number>, 2, measurer());
        if (lines.size() != 2) {
            logger.error("expected 2 lines, got " + lines.size().toString());
            return false;
        }
        var last = lines[1] as String;
        if (last.find("…") == null) {
            logger.error("the second line must end in '…', got '" + last + "'");
            return false;
        }
        if (last.length() * PX > 60) {
            logger.error("the cut line must still fit 60 px, got '" + last + "'");
            return false;
        }
        var short = Ui.wrapFit("Short", [60, 60] as Array<Number>, 2, measurer());
        if (short.size() != 1 || !(short[0] as String).equals("Short")) {
            logger.error("text that fits must come back unchanged");
            return false;
        }
        return true;
    }

    // On the button watches a list shows three rows (Geo.Display.rowH),
    // close together: the three fit with room to spare, and the rows two
    // away, whose text would still land inside the circle at this pitch, lie
    // under the mask (NightMenuLayout.maskBands), whose window is those three
    // rows. Up to 1.3.0 the rows two away were not drawn instead. The scroll
    // watches show every row in view. The home hero has the whole area above
    // the focused row. The values are logged per device.
    (:test)
    function listsShowThreeRows(logger as Logger) as Boolean {
        var g = Geo.current();
        var h = g.rowH;
        var screen = System.getDeviceSettings().screenHeight;
        var bands = NightMenuLayout.maskBands(screen, h, 1);
        logger.debug(System.getDeviceSettings().partNumber + ": FONT_MEDIUM " + Graphics.getFontHeight(Graphics.FONT_MEDIUM).toString()
            + ", screen " + screen.toString()
            + " -> rowH " + h.toString() + ", heroBottom " + g.heroBottom.toString()
            + (NightMenuLayout.masks(g.input) ? ", mask " + bands[0].toString() + " to " + bands[1].toString() : ", no mask"));
        if (3 * h > screen * 4 / 5) {
            logger.error("three rows of " + h.toString() + " should take at most four fifths of " + screen.toString());
            return false;
        }
        var window = bands[1] - bands[0];
        if (window < 3 * h || window > 3 * h + 1) {
            logger.error("the mask must leave three rows, " + (3 * h).toString() + " px, got " + window.toString());
            return false;
        }
        var block = Graphics.getFontHeight(Graphics.FONT_TINY) + Graphics.getFontHeight(Graphics.FONT_XTINY);
        var pill = NightMenuLayout.pillHeight(h, Graphics.getFontHeight(Graphics.FONT_SMALL) + Graphics.getFontHeight(Graphics.FONT_XTINY),
            g.px(14), g.px(3));
        if (h - block / 2 < pill / 2 + 4) {
            logger.error("a neighbour's text would run into the focus pill");
            return false;
        }
        if (g.heroBottom != screen / 2 - h / 2) {
            logger.error("heroBottom must be the centre minus half a row");
            return false;
        }
        return true;
    }

    // Was onlyTheFocusAndItsNeighboursAreDrawn (culling by index, up to
    // 1.3.0). Now every row is drawn and the mask covers the screen beyond a
    // row and a half from the centre: on every screen, whichever way a
    // centred focused row is rounded, the focused row and both neighbours
    // keep every pixel and the rows two away are covered but for at most a
    // pixel. The top band is off at focus 0 (the title above row 0), and
    // only the button watches are masked.
    (:test)
    function theMaskCoversOnlyTheRowsTwoAway(logger as Logger) as Boolean {
        var all = GeoTests.all();
        for (var i = 0; i < all.size(); i += 1) {
            var g = all[i] as Geo.Display;
            var rowH = g.rowH;
            var bands = NightMenuLayout.maskBands(g.h, rowH, 1);
            var tops = [(g.h - rowH) / 2, (g.h - rowH + 1) / 2] as Array<Number>;
            var label = g.w.toString() + "x" + g.h.toString() + ", rows of " + rowH.toString();
            for (var k = 0; k < tops.size(); k += 1) {
                var top = tops[k] as Number;
                if (top - rowH < bands[0] || top + 2 * rowH > bands[1]) {
                    logger.error(label + ": the mask " + bands[0].toString() + " to " + bands[1].toString()
                        + " covers part of a neighbour of the row at " + top.toString());
                    return false;
                }
                if (top - rowH - bands[0] > 1 || bands[1] - (top + 2 * rowH) > 1) {
                    logger.error(label + ": the rows two away show more than a pixel past the mask");
                    return false;
                }
            }
            if (NightMenuLayout.maskBands(g.h, rowH, 0)[0] != 0) {
                logger.error(label + ": no top band while row 0 has the focus");
                return false;
            }
            var scroll = g.input == Geo.INPUT_B || g.input == Geo.INPUT_C;
            if (NightMenuLayout.masks(g.input) == scroll) {
                logger.error(label + ": the button watches are masked, the scroll watches are not");
                return false;
            }
        }
        return true;
    }

    // Focus pill label: largest font that fits, else the smallest offered.
    (:test)
    function pickFontFallsBackLargestFirst(logger as Logger) as Boolean {
        var fonts = [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY] as Array<Graphics.FontType>;
        // "Start climate" = 13 chars: medium 195, small 169, tiny 143.
        if (Ui.pickFont("Start climate", fonts, 200, fontMeasurer()) != Graphics.FONT_MEDIUM) {
            logger.error("medium fits 200 px");
            return false;
        }
        if (Ui.pickFont("Start climate", fonts, 170, fontMeasurer()) != Graphics.FONT_SMALL) {
            logger.error("small is the first to fit 170 px");
            return false;
        }
        if (Ui.pickFont("Start climate", fonts, 150, fontMeasurer()) != Graphics.FONT_TINY) {
            logger.error("tiny is the first to fit 150 px");
            return false;
        }
        if (Ui.pickFont("Start climate", fonts, 10, fontMeasurer()) != Graphics.FONT_TINY) {
            logger.error("nothing fits: the smallest font, which the caller then fits");
            return false;
        }
        return true;
    }

}
