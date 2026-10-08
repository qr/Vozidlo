import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Word-wrapped paragraph text that fits inside a ROUND display.
//
// Why this exists: WatchUi.Text does not wrap. Its :width option bounds
// justification, not layout, so a long string is drawn as a single line that
// runs off both edges. Every onboarding screen did exactly that: the first
// thing a new user sees was "rks for the vehicles you selected when y".
//
// Why a rectangle is not good enough: on a 260x260 round face the usable
// width depends on how far a line sits from the middle. The widest chord is
// at the centre; a line near the top or bottom has much less room. Wrapping
// to one fixed width either wastes the middle of the screen or overruns the
// ends. So each line gets the width actually available at its own height.
//
// The geometry and the wrapping are pure functions taking plain numbers and a
// measuring callback, so they are unit-testable without a Dc, see
// tests/TextBlockTests.mc. Only draw() touches graphics.
module TextBlock {

    // Keep glyphs off the bezel. The display's own edge is not the usable
    // edge: anti-aliasing and the physical bezel both eat into it.
    const MARGIN = 8;

    // Half the chord of a circle of `radius` at vertical distance `dy` from
    // the centre. Returns 0 outside the circle rather than failing, so a
    // caller that asks about an impossible line gets "no room" instead of an
    // exception.
    function halfChord(radius as Number, dy as Number) as Number {
        var r2 = radius * radius;
        var d2 = dy * dy;
        if (d2 >= r2) {
            return 0;
        }
        return Math.sqrt(r2 - d2).toNumber();
    }

    // Usable width for a line whose glyph box spans `top`..`bottom`, measured
    // from the top of the display, on a circle of `radius` centred at
    // `centerY`.
    //
    // The binding constraint is whichever of the line's two edges is further
    // from the middle: a line above the centre is pinched by its top edge,
    // one below it by its bottom edge, so the whole box fits, not just its
    // baseline.
    function lineWidth(radius as Number, centerY as Number, top as Number, bottom as Number) as Number {
        var dTop = (top - centerY).abs();
        var dBottom = (bottom - centerY).abs();
        var dy = dTop > dBottom ? dTop : dBottom;
        var usable = 2 * halfChord(radius, dy) - 2 * MARGIN;
        return usable > 0 ? usable : 0;
    }

    // Greedy word wrap. `widths` gives the usable width per line, in order;
    // once it runs out the last entry is reused, so a caller that
    // underestimates the line count still gets sane output instead of an
    // out-of-range access.
    //
    // `measure` takes a String and returns its pixel width. Passing it in,
    // rather than a Dc, is what makes this testable.
    //
    // A single word too wide for its line is broken mid-word. That is ugly,
    // and it is still the right call: the alternative is a word that runs off
    // the screen, which is the bug this module exists to fix.
    function wrapLines(text as String, widths as Array<Number>, measure as Method(s as String) as Number) as Array<String> {
        var lines = [] as Array<String>;
        var words = _words(text);
        if (words.size() == 0) {
            return lines;
        }

        var current = "";
        for (var i = 0; i < words.size(); i += 1) {
            var word = words[i] as String;
            var limit = _widthFor(widths, lines.size());
            var candidate = current.equals("") ? word : current + " " + word;

            if (measure.invoke(candidate) <= limit) {
                current = candidate;
                continue;
            }

            // Does not fit. Close the current line first, if there is one.
            if (!current.equals("")) {
                lines.add(current);
                current = "";
                limit = _widthFor(widths, lines.size());
            }

            // The word alone may still be too wide for a whole line.
            if (measure.invoke(word) <= limit) {
                current = word;
                continue;
            }
            var rest = word;
            while (measure.invoke(rest) > limit && rest.length() > 1) {
                var cut = _longestPrefix(rest, limit, measure);
                lines.add(rest.substring(0, cut) as String);
                rest = rest.substring(cut, rest.length()) as String;
                limit = _widthFor(widths, lines.size());
            }
            current = rest;
        }
        if (!current.equals("")) {
            lines.add(current);
        }
        return lines;
    }

    // How many characters of `s` fit within `limit`. At least one, so a
    // caller in the mid-word break loop above always makes progress even when
    // a single glyph is wider than the line.
    function _longestPrefix(s as String, limit as Number, measure as Method(t as String) as Number) as Number {
        var n = 1;
        while (n < s.length() && measure.invoke(s.substring(0, n + 1) as String) <= limit) {
            n += 1;
        }
        return n;
    }

    function _widthFor(widths as Array<Number>, index as Number) as Number {
        if (widths.size() == 0) {
            return 0;
        }
        if (index >= widths.size()) {
            return widths[widths.size() - 1] as Number;
        }
        return widths[index] as Number;
    }

    // Split on runs of whitespace. Monkey C's String has no split(), and
    // toCharArray() is the cheapest way to walk it without building a
    // substring per character.
    function _words(text as String) as Array<String> {
        var out = [] as Array<String>;
        var chars = text.toCharArray();
        var start = -1;
        for (var i = 0; i < chars.size(); i += 1) {
            var c = chars[i] as Char;
            var isSpace = (c == ' ') || (c == '\n') || (c == '\t') || (c == '\r');
            if (isSpace) {
                if (start >= 0) {
                    out.add(text.substring(start, i) as String);
                    start = -1;
                }
            } else if (start < 0) {
                start = i;
            }
        }
        if (start >= 0) {
            out.add(text.substring(start, chars.size()) as String);
        }
        return out;
    }

    // The highest y at or above `preferredY` where a line of `textWidth` fits
    // the chord, never going above the centre (the widest point: if it does
    // not fit there it does not fit at all).
    //
    // Single-line hints at the very bottom of a round face are the same bug as
    // the unwrapped paragraph this module was written for, in miniature. At
    // y 240 on a 260 face the usable width is about 84 pixels, which is three
    // or four words short of any useful hint, so the text ran off both sides.
    // Rather than silently truncate something the user is meant to read, move
    // it up to where it fits.
    function fittedLineY(radius as Number, centerY as Number, lineHeight as Number,
                         preferredY as Number, textWidth as Number) as Number {
        var y = preferredY;
        while (y > centerY) {
            var top = fittedLineTop(y, lineHeight);
            if (lineWidth(radius, centerY, top, top + lineHeight) >= textWidth) {
                return y;
            }
            y -= 2;
        }
        return centerY;
    }

    // drawFittedLine() draws with VCENTER, so `y` is the middle of the glyph
    // box and this is its top. Kept as the one place both the check above and
    // the draw below derive the box from (A1): before, the check assumed a
    // centred box while the text was drawn top-aligned at y, half a line
    // lower than the box that had been checked.
    function fittedLineTop(y as Number, lineHeight as Number) as Number {
        return y - lineHeight / 2;
    }

    // Justification drawFittedLine() uses; public so a test pins A1.
    const FITTED_JUSTIFY = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

    // Draws one line at the lowest point at or above `preferredY` where it fits
    // whole, truncating only if it cannot fit even across the middle. `y` is
    // the vertical centre of the line (A1). Returns the y actually used, so a
    // caller can lay something else out around it.
    function drawFittedLine(dc as Dc, text as String, font as Graphics.FontType,
                            color as Graphics.ColorType, preferredY as Number) as Number {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var radius = (width < height ? width : height) / 2;
        var centerY = height / 2;
        var lineHeight = dc.getFontHeight(font);

        var shown = text;
        var textWidth = dc.getTextWidthInPixels(shown, font);
        var y = fittedLineY(radius, centerY, lineHeight, preferredY, textWidth);

        // Too wide even across the middle: trim until it fits there.
        var top = fittedLineTop(y, lineHeight);
        var available = lineWidth(radius, centerY, top, top + lineHeight);
        while (textWidth > available && shown.length() > 1) {
            shown = (shown.substring(0, shown.length() - 2) as String) + "…";
            textWidth = dc.getTextWidthInPixels(shown, font);
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, y, font, shown, FITTED_JUSTIFY);
        return y;
    }

    // Lays `text` out as a vertically centred block of wrapped lines and
    // draws it. Returns the lines drawn, so a caller can tell whether
    // anything had to be dropped.
    //
    // The line count and the per-line widths depend on each other: more lines
    // means a taller block, which pushes the outer lines further from the
    // centre, which narrows them, which can force another line. So it
    // iterates to a fixed point. It converges in two or three passes for real
    // strings; the cap is there so a pathological input cannot spin.
    function draw(dc as Dc, text as String, font as Graphics.FontType, color as Graphics.ColorType) as Array<String> {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var radius = (width < height ? width : height) / 2;
        var centerX = width / 2;
        var centerY = height / 2;
        var lineHeight = dc.getFontHeight(font);

        var metrics = new _Metrics(dc, font);
        var measure = metrics.method(:width);

        var lines = [] as Array<String>;
        var count = 1;
        for (var pass = 0; pass < 6; pass += 1) {
            var widths = _widthsFor(radius, centerY, lineHeight, count);
            lines = wrapLines(text, widths, measure);
            if (lines.size() == count || lines.size() == 0) {
                break;
            }
            count = lines.size();
        }

        // More than the screen can hold. Drop the overflow rather than draw
        // past the bottom edge, and mark the cut so it reads as truncated
        // instead of as a sentence that simply stops.
        var maxLines = height / lineHeight;
        if (lines.size() > maxLines && maxLines > 0) {
            lines = lines.slice(0, maxLines) as Array<String>;
            lines[lines.size() - 1] = (lines[lines.size() - 1] as String) + "…";
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var top = centerY - (lines.size() * lineHeight) / 2;
        for (var i = 0; i < lines.size(); i += 1) {
            dc.drawText(centerX, top + i * lineHeight, font, lines[i] as String,
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
        return lines;
    }

    // Usable width of each line of a `count`-line block, centred vertically.
    function _widthsFor(radius as Number, centerY as Number, lineHeight as Number, count as Number) as Array<Number> {
        var widths = [] as Array<Number>;
        var top = centerY - (count * lineHeight) / 2;
        for (var i = 0; i < count; i += 1) {
            var lineTop = top + i * lineHeight;
            widths.add(lineWidth(radius, centerY, lineTop, lineTop + lineHeight));
        }
        return widths;
    }

    // Wraps a Dc so its text measurement can be passed as a Method. Exists
    // only because wrapLines() takes a callback rather than a Dc, which is
    // what lets the tests measure with arithmetic instead of graphics.
    class _Metrics {
        private var _dc as Dc;
        private var _font as Graphics.FontType;

        function initialize(dc as Dc, font as Graphics.FontType) {
            _dc = dc;
            _font = font;
        }

        function width(s as String) as Number {
            return _dc.getTextWidthInPixels(s, _font);
        }
    }

}
