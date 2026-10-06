import Toybox.Lang;
import Toybox.Test;

// Unit tests for source/ui/TextBlock.mc: the word wrapper the onboarding
// screens use. The geometry and the wrapping are pure functions taking a
// measuring callback, so all of this runs without a Dc and without graphics.
//
// The measurer below is deliberately not a real font: a fixed 6 pixels per
// character makes every expectation here arithmetic a reader can check by
// hand. What it verifies is the wrapping logic, not Garmin's glyph metrics.
module TextBlockTests {

    const PX_PER_CHAR = 6;

    class FixedWidthFont {
        function initialize() {}
        function width(s as String) as Number {
            return s.length() * PX_PER_CHAR;
        }
    }

    function measurer() as Method(s as String) as Number {
        return (new FixedWidthFont()).method(:width);
    }

    // The chord of a circle, which is what decides how much room a line of
    // text has on a round face. Values checked against Pythagoras: at the
    // centre the half-chord is the radius; at 3-4-5 proportions it is exact.
    (:test)
    function halfChordFollowsTheCircle(logger as Logger) as Boolean {
        if (TextBlock.halfChord(130, 0) != 130) {
            logger.error("at the centre the half-chord should be the radius");
            return false;
        }
        // 50-120-130 is a Pythagorean triple, so this is exact, not rounded.
        if (TextBlock.halfChord(130, 50) != 120) {
            logger.error("expected 120, got " + TextBlock.halfChord(130, 50));
            return false;
        }
        // On the rim, and beyond it, there is no room rather than an error.
        if (TextBlock.halfChord(130, 130) != 0) {
            logger.error("no room exactly on the rim");
            return false;
        }
        if (TextBlock.halfChord(130, 400) != 0) {
            logger.error("outside the circle must be 0, not negative or a crash");
            return false;
        }
        return true;
    }

    // A line is pinched by whichever of its edges is further from the middle,
    // so the whole glyph box fits rather than just its baseline. A line
    // spanning 10..30 on a 260 face (centre 130) is bounded by its TOP edge,
    // 120 away, not its bottom edge at 100.
    (:test)
    function lineWidthUsesTheWorstEdge(logger as Logger) as Boolean {
        var high = TextBlock.lineWidth(130, 130, 10, 30);
        var expected = 2 * TextBlock.halfChord(130, 120) - 2 * TextBlock.MARGIN;
        if (high != expected) {
            logger.error("top-edge-bound line: expected " + expected + ", got " + high);
            return false;
        }
        // The mirror image below the centre must come out identical.
        var low = TextBlock.lineWidth(130, 130, 230, 250);
        if (low != high) {
            logger.error("a line below the centre must match its mirror above it");
            return false;
        }
        // A line straddling the centre gets the widest chord available.
        var middle = TextBlock.lineWidth(130, 130, 120, 140);
        if (middle <= high) {
            logger.error("the middle of the screen must be wider than the top");
            return false;
        }
        return true;
    }

    // A line entirely off the display has no room. Clamping to 0 rather than
    // going negative is what stops wrapLines() from looping forever.
    (:test)
    function lineWidthNeverGoesNegative(logger as Logger) as Boolean {
        if (TextBlock.lineWidth(130, 130, 400, 420) != 0) {
            logger.error("a line off the screen must report 0 usable width");
            return false;
        }
        return true;
    }

    // The bug this module exists to fix: a sentence must become several lines,
    // every one of them within its width.
    (:test)
    function longTextIsWrappedNotClipped(logger as Logger) as Boolean {
        var text = "A key is created in the MySkoda app, not here. It only works "
                 + "for the vehicles you selected when you created it.";
        var widths = [200, 200, 200, 200, 200, 200, 200] as Array<Number>;
        var lines = TextBlock.wrapLines(text, widths, measurer());

        if (lines.size() < 2) {
            logger.error("expected the sentence to wrap, got " + lines.size() + " line(s)");
            return false;
        }
        for (var i = 0; i < lines.size(); i += 1) {
            var w = (lines[i] as String).length() * PX_PER_CHAR;
            if (w > 200) {
                logger.error("line " + i + " is " + w + "px, over the 200px limit: " + lines[i]);
                return false;
            }
        }
        return true;
    }

    // Wrapping must not lose or duplicate words: the words of the output, in
    // order, must be exactly the words of the input.
    (:test)
    function wrappingPreservesEveryWord(logger as Logger) as Boolean {
        var text = "one two three four five six seven eight nine ten";
        var widths = [60, 60, 60, 60, 60, 60, 60, 60] as Array<Number>;
        var lines = TextBlock.wrapLines(text, widths, measurer());

        var joined = "";
        for (var i = 0; i < lines.size(); i += 1) {
            joined = joined.equals("") ? (lines[i] as String) : joined + " " + (lines[i] as String);
        }
        if (!joined.equals(text)) {
            logger.error("words changed.\n  in:  " + text + "\n  out: " + joined);
            return false;
        }
        return true;
    }

    // Narrower lines toward the top and bottom of a round face are the whole
    // point: a line given less room must take fewer words.
    (:test)
    function narrowerLinesTakeFewerWords(logger as Logger) as Boolean {
        var text = "alpha bravo charlie delta echo foxtrot golf hotel india";
        var narrow = TextBlock.wrapLines(text, [60] as Array<Number>, measurer());
        var wide = TextBlock.wrapLines(text, [240] as Array<Number>, measurer());
        if (narrow.size() <= wide.size()) {
            logger.error("a narrow column must need more lines than a wide one: "
                         + narrow.size() + " vs " + wide.size());
            return false;
        }
        return true;
    }

    // A single word wider than its line has to be broken. Ugly, but the
    // alternative is the word running off the screen, which is the bug.
    (:test)
    function anOverlongWordIsBrokenNotOverflowed(logger as Logger) as Boolean {
        var widths = [60, 60, 60, 60, 60, 60] as Array<Number>;
        var lines = TextBlock.wrapLines("Donaudampfschifffahrtsgesellschaft", widths, measurer());
        if (lines.size() < 2) {
            logger.error("expected the word to be broken across lines");
            return false;
        }
        for (var i = 0; i < lines.size(); i += 1) {
            if ((lines[i] as String).length() * PX_PER_CHAR > 60) {
                logger.error("fragment " + i + " still overflows: " + lines[i]);
                return false;
            }
        }
        return true;
    }

    // Running past the end of the widths array must reuse the last width
    // rather than fail: the caller's line-count guess is only a guess.
    (:test)
    function widthsShorterThanTheTextAreTolerated(logger as Logger) as Boolean {
        var lines = TextBlock.wrapLines("one two three four five six seven eight",
                                        [60] as Array<Number>, measurer());
        if (lines.size() < 2) {
            logger.error("expected several lines from a single 60px width");
            return false;
        }
        for (var i = 0; i < lines.size(); i += 1) {
            if ((lines[i] as String).length() * PX_PER_CHAR > 60) {
                logger.error("line " + i + " overflows the reused width");
                return false;
            }
        }
        return true;
    }

    // Degenerate inputs must return nothing rather than a blank line or a
    // crash: onboarding shows a transient error string that could be empty.
    (:test)
    function emptyAndBlankTextProduceNoLines(logger as Logger) as Boolean {
        if (TextBlock.wrapLines("", [200] as Array<Number>, measurer()).size() != 0) {
            logger.error("empty text should produce no lines");
            return false;
        }
        if (TextBlock.wrapLines("   ", [200] as Array<Number>, measurer()).size() != 0) {
            logger.error("whitespace-only text should produce no lines");
            return false;
        }
        return true;
    }

    // Newlines and runs of spaces are separators like any other whitespace;
    // they must not survive as empty lines or leading spaces.
    (:test)
    function whitespaceRunsCollapse(logger as Logger) as Boolean {
        var lines = TextBlock.wrapLines("one\n\ntwo   three", [200] as Array<Number>, measurer());
        if (lines.size() != 1) {
            logger.error("expected one line, got " + lines.size());
            return false;
        }
        if (!(lines[0] as String).equals("one two three")) {
            logger.error("expected 'one two three', got '" + lines[0] + "'");
            return false;
        }
        return true;
    }

    // A hint at the very bottom of a round face has almost no room. At y 240
    // on a 260 face the usable width is about 84 pixels, so anything longer
    // has to move up rather than run off both sides.
    (:test)
    function aBottomHintMovesUpUntilItFits(logger as Logger) as Boolean {
        var radius = 130;
        var centerY = 130;
        var lineHeight = 21;
        var preferred = 240;

        var atBottom = TextBlock.lineWidth(radius, centerY,
                                           preferred - lineHeight / 2,
                                           preferred + lineHeight / 2);
        var wide = atBottom + 60;   // comfortably wider than the bottom allows

        var y = TextBlock.fittedLineY(radius, centerY, lineHeight, preferred, wide);
        if (y >= preferred) {
            logger.error("a too-wide hint should move up from " + preferred + ", got " + y);
            return false;
        }
        var available = TextBlock.lineWidth(radius, centerY, y - lineHeight / 2, y + lineHeight / 2);
        if (available < wide) {
            logger.error("moved to y " + y + " but only " + available + "px there, needed " + wide);
            return false;
        }
        return true;
    }

    // Something that already fits must not be moved: the hint belongs at the
    // bottom whenever the bottom can hold it.
    (:test)
    function aHintThatFitsStaysPut(logger as Logger) as Boolean {
        var y = TextBlock.fittedLineY(130, 130, 21, 240, 10);
        if (y != 240) {
            logger.error("a 10px hint fits at the bottom; expected 240, got " + y);
            return false;
        }
        return true;
    }

    // Nothing fits across the middle either: stop at the centre rather than
    // walking off the top of the screen.
    (:test)
    function anImpossibleHintStopsAtTheCentre(logger as Logger) as Boolean {
        var y = TextBlock.fittedLineY(130, 130, 21, 240, 9999);
        if (y != 130) {
            logger.error("expected the centre (130) as the last resort, got " + y);
            return false;
        }
        return true;
    }

    // The real strings on the real screen. 260x260 round, FONT_XTINY is about
    // 6px per character at this size, and the block is centred, so this is
    // the closest the pure tests get to the actual onboarding screen. Every
    // line must fit the chord available at its own height, which is the
    // check that would have caught the original bug.
    (:test)
    function theOnboardingMessageFitsA260RoundFace(logger as Logger) as Boolean {
        var text = "A key is created in the MySkoda app (v8.16+), not here. It only "
                 + "works for the vehicles you selected when you created it. Enter it "
                 + "in this app's phone settings. Menu for more.";
        var radius = 130;
        var centerY = 130;
        var lineHeight = 21;

        // Same fixed-point search draw() performs, without the graphics.
        var lines = [] as Array<String>;
        var count = 1;
        for (var pass = 0; pass < 6; pass += 1) {
            var widths = [] as Array<Number>;
            var top = centerY - (count * lineHeight) / 2;
            for (var i = 0; i < count; i += 1) {
                var lineTop = top + i * lineHeight;
                widths.add(TextBlock.lineWidth(radius, centerY, lineTop, lineTop + lineHeight));
            }
            lines = TextBlock.wrapLines(text, widths, measurer());
            if (lines.size() == count) {
                break;
            }
            count = lines.size();
        }

        if (lines.size() == 0) {
            logger.error("the onboarding message produced no lines at all");
            return false;
        }
        if (lines.size() * lineHeight > 2 * radius) {
            logger.error("the block is " + (lines.size() * lineHeight)
                         + "px tall, taller than the " + (2 * radius) + "px display");
            return false;
        }

        var blockTop = centerY - (lines.size() * lineHeight) / 2;
        for (var i = 0; i < lines.size(); i += 1) {
            var lineTop = blockTop + i * lineHeight;
            var available = TextBlock.lineWidth(radius, centerY, lineTop, lineTop + lineHeight);
            var actual = (lines[i] as String).length() * PX_PER_CHAR;
            if (actual > available) {
                logger.error("line " + i + " is " + actual + "px but only " + available
                             + "px is available at that height: " + lines[i]);
                return false;
            }
        }
        return true;
    }

}
