import Toybox.Graphics;
import Toybox.Lang;

// Shared text layout and drawing for the Night Panel screens
// (docs/design/ui-improvements.md B4, B5, C8). The pure half takes a
// measuring callback like TextBlock does, so tests run without a Dc; the
// drawing half is what keeps every screen on the same fonts and colours.
//
// App scope only: the glance does its own minimal drawing so this module
// stays out of the 64 KB glance arena.
module Ui {

    // Every glyph FONT_NUMBER_* actually has (C8 step 6); letters and "—"
    // render as boxes or nothing in those fonts (A8).
    const NUMBER_GLYPHS = " #%+-./0123456789:°";

    // Space between a number and its unit; measured on the PoC hero.
    const UNIT_GAP = 4;

    // ------------------------------------------------------------ pure

    // Guards the number fonts: a value like "—" or "Off" must fall back to a
    // text font instead of drawing empty boxes (A8).
    function isNumberGlyphs(s as String) as Boolean {
        if (s.length() == 0) {
            return false;
        }
        var chars = s.toCharArray();
        for (var i = 0; i < chars.size(); i += 1) {
            if (NUMBER_GLYPHS.find((chars[i] as Char).toString()) == null) {
                return false;
            }
        }
        return true;
    }

    // Truncate by pixels with "…" (B4 copy rule, A5). Never returns anything
    // wider than maxW: a round screen clips whatever overruns, so "fits" has
    // to be a guarantee, not an estimate. Binary search keeps the measuring
    // calls per draw logarithmic.
    function fit(text as String, maxW as Number, measure as Method(s as String) as Number) as String {
        if (measure.invoke(text) <= maxW) {
            return text;
        }
        var lo = 0;
        var hi = text.length() - 1;
        var best = -1;
        while (lo <= hi) {
            var mid = (lo + hi) / 2;
            var candidate = _trimEnd(text.substring(0, mid) as String) + Labels.ELLIPSIS;
            if (measure.invoke(candidate) <= maxW) {
                best = mid;
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
        if (best < 0) {
            return "";
        }
        return _trimEnd(text.substring(0, best) as String) + Labels.ELLIPSIS;
    }

    function _trimEnd(s as String) as String {
        var n = s.length();
        while (n > 0 && (s.substring(n - 1, n) as String).equals(" ")) {
            n -= 1;
        }
        return s.substring(0, n) as String;
    }

    // Usable width for a glyph box from top to bottom on the 260 round face
    // (C8 step 2), with a wider margin on ring screens (Theme.RING_MARGIN).
    function usable(top as Number, bottom as Number, margin as Number) as Number {
        var u = TextBlock.lineWidth(130, 130, top, bottom) - 2 * (margin - TextBlock.MARGIN);
        return u > 0 ? u : 0;
    }

    // Wrap to per-line chord widths but never past maxLines; the last line
    // gets "…" so a cut address reads as cut (C5: two lines, then "…").
    function wrapFit(text as String, widths as Array<Number>, maxLines as Number,
                     measure as Method(s as String) as Number) as Array<String> {
        var lines = TextBlock.wrapLines(text, widths, measure);
        if (maxLines <= 0) {
            return [] as Array<String>;
        }
        if (lines.size() <= maxLines) {
            return lines;
        }
        lines = lines.slice(0, maxLines) as Array<String>;
        var last = maxLines - 1;
        var w = 0;
        if (widths.size() > 0) {
            w = (last < widths.size() ? widths[last] : widths[widths.size() - 1]) as Number;
        }
        lines[last] = fit((lines[last] as String) + Labels.ELLIPSIS, w, measure);
        return lines;
    }

    // First font in `fonts` (largest first) whose rendering of `text` fits
    // maxW, else the last one; the caller still fit()s the result. Exists
    // because fēnix 8/9 scale system fonts, so "medium fits" cannot be a
    // constant (Facts in the plan).
    function pickFont(text as String, fonts as Array<Graphics.FontType>, maxW as Number,
                      measure as Method(s as String, font as Graphics.FontType) as Number) as Graphics.FontType {
        for (var i = 0; i < fonts.size() - 1; i += 1) {
            if (measure.invoke(text, fonts[i] as Graphics.FontType) <= maxW) {
                return fonts[i] as Graphics.FontType;
            }
        }
        return fonts[fonts.size() - 1] as Graphics.FontType;
    }

    // Binds a Dc to the callback shapes the pure helpers take.
    class Measure {
        private var _dc as Dc;
        private var _font as Graphics.FontType;

        function initialize(dc as Dc, font as Graphics.FontType) {
            _dc = dc;
            _font = font;
        }

        function width(s as String) as Number {
            return _dc.getTextWidthInPixels(s, _font);
        }

        function widthIn(s as String, font as Graphics.FontType) as Number {
            return _dc.getTextWidthInPixels(s, font);
        }
    }

    // A measuring callback for fit()/wrapFit() on a real Dc.
    function measurer(dc as Dc, font as Graphics.FontType) as Method(s as String) as Number {
        return (new Measure(dc, font)).method(:width);
    }

    // A two-argument measuring callback for pickFont() on a real Dc.
    function fontMeasurer(dc as Dc) as Method(s as String, font as Graphics.FontType) as Number {
        return (new Measure(dc, Graphics.FONT_XTINY)).method(:widthIn);
    }

    // ------------------------------------------------------------ drawing

    // Screen title: FONT_TINY in the accent, sentence case, fitted to the
    // chord at its own y (B4, C2 "title tiny y 34"). Returns the bottom y so
    // the caller can stack below it.
    function title(dc as Dc, text as String, y as Number) as Number {
        var font = Graphics.FONT_TINY;
        var h = dc.getFontHeight(font);
        var s = fit(text, usable(y, y + h, Theme.MARGIN), measurer(dc, font));
        dc.setColor(Theme.c(Theme.ACCENT), Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, y, font, s, Graphics.TEXT_JUSTIFY_CENTER);
        return y + h;
    }

    // Hero number with its unit: digits in the number font, unit in a text
    // font in TEXT_2 on the same baseline (A8). A value the number font cannot
    // draw ("—", "Off") falls back to FONT_MEDIUM. y is the top of the number
    // box; returns the total width so callers can place an icon beside it.
    function drawValueWithUnit(dc as Dc, cx as Number, y as Number, value as String, unit as String?,
                               numFont as Graphics.FontType, unitFont as Graphics.FontType,
                               color as Number) as Number {
        var nf = isNumberGlyphs(value) ? numFont : Graphics.FONT_MEDIUM;
        var wv = dc.getTextWidthInPixels(value, nf);
        var wu = 0;
        var gap = 0;
        var u = unit;
        if (u != null) {
            wu = dc.getTextWidthInPixels(u, unitFont);
            gap = wu > 0 ? UNIT_GAP : 0;
        }
        var total = wv + gap + wu;
        var x0 = cx - total / 2;
        dc.setColor(Theme.c(color), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0, y, nf, value, Graphics.TEXT_JUSTIFY_LEFT);
        if (u != null && wu > 0) {
            var uy = y + Graphics.getFontAscent(nf) - Graphics.getFontAscent(unitFont);
            dc.setColor(Theme.c(Theme.TEXT_2), Graphics.COLOR_TRANSPARENT);
            dc.drawText(x0 + wv + gap, uy, unitFont, u, Graphics.TEXT_JUSTIFY_LEFT);
        }
        return total;
    }

    // Hero word ("Locked", "Heating") in FONT_MEDIUM with an optional icon in
    // front (B4: words in medium, never in a number font). Returns the width.
    function drawHeroWord(dc as Dc, cx as Number, y as Number, word as String, icon as Symbol?,
                          color as Number) as Number {
        var font = Graphics.FONT_MEDIUM;
        var iconR = 12;
        var iw = icon != null ? 2 * iconR + 8 : 0;
        var w = dc.getTextWidthInPixels(word, font);
        var x0 = cx - (w + iw) / 2;
        var col = Theme.c(color);
        if (icon != null) {
            NightIcons.draw(dc, icon, x0 + iconR, y + dc.getFontHeight(font) / 2, iconR, col);
        }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0 + iw, y, font, word, Graphics.TEXT_JUSTIFY_LEFT);
        return w + iw;
    }

    // One xtiny line under a hero: age (:age), command feedback (:sent),
    // stale (:warn) or failure (:error). Warn and error get a "!" in front
    // when the text has none, so they survive the monochrome test (B1.2).
    // Returns the bottom y.
    function drawStatusLine(dc as Dc, y as Number, text as String, kind as Symbol) as Number {
        var font = Graphics.FONT_XTINY;
        var h = dc.getFontHeight(font);
        var color = Theme.TEXT_2;
        var shown = text;
        if (kind == :sent) {
            color = Theme.TEXT_1;
        } else if (kind == :warn || kind == :error) {
            color = kind == :warn ? Theme.WARNING : Theme.DESTRUCTIVE;
            if (shown.find("!") != 0) {
                shown = "! " + shown;
            }
        }
        shown = fit(shown, usable(y, y + h, Theme.MARGIN), measurer(dc, font));
        dc.setColor(Theme.c(color), Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, y, font, shown, Graphics.TEXT_JUSTIFY_CENTER);
        return y + h;
    }

}
