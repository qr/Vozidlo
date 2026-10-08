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
    // the full 193 px.
    (:test)
    function neighbourRowsFitTheChord(logger as Logger) as Boolean {
        var w = NightMenuLayout.neighbourWidth(65, 29);
        if (w <= 0 || w >= 193 || w != Ui.usable(181, 209, Theme.MARGIN)) {
            logger.error("unexpected neighbour width " + w);
            return false;
        }
        if (NightMenuLayout.neighbourWidth(65, 48) >= w) {
            logger.error("a taller block (label + sub) must get less width");
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

    // C8 step 2: usable = chord minus margins, wider margin narrows it.
    (:test)
    function usableFollowsTheChordAndMargin(logger as Logger) as Boolean {
        var mid = Ui.usable(120, 140, 8);
        if (mid != TextBlock.lineWidth(130, 130, 120, 140)) {
            logger.error("margin 8 must equal TextBlock.lineWidth");
            return false;
        }
        if (Ui.usable(120, 140, 12) != mid - 8) {
            logger.error("margin 12 must take 4 px more from each side");
            return false;
        }
        if (Ui.usable(250, 270, 12) != 0) {
            logger.error("a box outside the circle has no room, not a negative width");
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

    // Every list shows three rows (Theme.rowHeight()), close together: the
    // three fit with room to spare, and the rows two away, whose text would
    // still land inside the circle at this pitch, are not drawn. The home
    // hero has the whole area above the focused row. The values are logged
    // per device.
    (:test)
    function listsShowThreeRows(logger as Logger) as Boolean {
        var h = Theme.rowHeight();
        var screen = System.getDeviceSettings().screenHeight;
        logger.debug(System.getDeviceSettings().partNumber + ": FONT_MEDIUM " + Graphics.getFontHeight(Graphics.FONT_MEDIUM).toString()
            + ", screen " + screen.toString()
            + " -> rowHeight " + h.toString() + ", heroBottom " + Theme.heroBottom().toString());
        if (3 * h > screen * 4 / 5) {
            logger.error("three rows of " + h.toString() + " should take at most four fifths of " + screen.toString());
            return false;
        }
        var block = Graphics.getFontHeight(Graphics.FONT_TINY) + Graphics.getFontHeight(Graphics.FONT_XTINY);
        var pill = NightMenuLayout.pillHeight(h, Graphics.getFontHeight(Graphics.FONT_SMALL) + Graphics.getFontHeight(Graphics.FONT_XTINY), 14, 3);
        if (h - block / 2 < pill / 2 + 4) {
            logger.error("a neighbour's text would run into the focus pill");
            return false;
        }
        if (Theme.heroBottom() != screen / 2 - h / 2 || Theme.HOME_TITLE_H != Theme.heroBottom()) {
            logger.error("heroBottom must be the centre minus half a row, and the home title that tall");
            return false;
        }
        return true;
    }

    // Only the focused row and one either side are drawn; the title counts
    // as row -1, and before the first draw (focus -1) everything is.
    (:test)
    function onlyTheFocusAndItsNeighboursAreDrawn(logger as Logger) as Boolean {
        if (!NightMenuLayout.isShown(3, 3) || !NightMenuLayout.isShown(2, 3) || !NightMenuLayout.isShown(4, 3)) {
            logger.error("the focus and its neighbours must be drawn");
            return false;
        }
        if (NightMenuLayout.isShown(1, 3) || NightMenuLayout.isShown(5, 3)) {
            logger.error("rows two away must be blank");
            return false;
        }
        if (!NightMenuLayout.isShown(-1, 0) || NightMenuLayout.isShown(-1, 1)) {
            logger.error("the title shows at focus 0 only");
            return false;
        }
        if (!NightMenuLayout.isShown(7, -1)) {
            logger.error("an unknown focus must show every row");
            return false;
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
