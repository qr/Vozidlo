import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;

// Unit tests for ui/MonochromeTest.mc (US-060). The SDK has no pixel
// readback API (Toybox.Graphics.Dc/BufferedBitmap are draw-only, checked
// against the SDK's own reference pages), so a genuine "render the screen
// and assert every state is still distinguishable" test is not possible
// here; this exercises the one piece that IS pure and testable: the colour
// mapping itself: leaving the actual "render without colour" check to a
// human flipping MonochromeTest.setEnabled(true) on-device (or via the
// simulator's File -> Edit Persistent Storage) and looking, as this task's
// final report explains.
module MonochromeTestTests {

    (:test)
    function colorPassesThroughUnchangedWhenDisabled(logger as Logger) as Boolean {
        MonochromeTest.setEnabled(false);
        if (MonochromeTest.color(Graphics.COLOR_RED) != Graphics.COLOR_RED) {
            logger.error("disabled must never alter a colour");
            return false;
        }
        if (MonochromeTest.color(Graphics.COLOR_GREEN) != Graphics.COLOR_GREEN) {
            logger.error("disabled must never alter a colour");
            return false;
        }
        return true;
    }

    (:test)
    function colorCollapsesEveryHueToWhiteWhenEnabled(logger as Logger) as Boolean {
        MonochromeTest.setEnabled(true);
        var hues = [
            Graphics.COLOR_RED, Graphics.COLOR_ORANGE, Graphics.COLOR_YELLOW,
            Graphics.COLOR_GREEN, Graphics.COLOR_BLUE, Graphics.COLOR_DK_GRAY, Graphics.COLOR_LT_GRAY
        ] as Array<Graphics.ColorType>;
        for (var i = 0; i < hues.size(); i += 1) {
            if (MonochromeTest.color(hues[i] as Graphics.ColorType) != Graphics.COLOR_WHITE) {
                logger.error("every non-black/transparent colour must collapse to white when enabled");
                MonochromeTest.setEnabled(false);
                return false;
            }
        }
        MonochromeTest.setEnabled(false);
        return true;
    }

    // Black (every screen's own canvas background) and transparent (the
    // "no fill" sentinel used everywhere in this app) are structural, not a
    // state signal: collapsing them too would just make the whole canvas
    // white-on-white, defeating the point.
    (:test)
    function colorLeavesBlackAndTransparentAloneWhenEnabled(logger as Logger) as Boolean {
        MonochromeTest.setEnabled(true);
        var black = MonochromeTest.color(Graphics.COLOR_BLACK);
        var transparent = MonochromeTest.color(Graphics.COLOR_TRANSPARENT);
        MonochromeTest.setEnabled(false);
        if (black != Graphics.COLOR_BLACK) {
            logger.error("black must stay black even when enabled");
            return false;
        }
        if (transparent != Graphics.COLOR_TRANSPARENT) {
            logger.error("transparent must stay transparent even when enabled");
            return false;
        }
        return true;
    }

    (:test)
    function whiteStaysWhiteWhenEnabled(logger as Logger) as Boolean {
        MonochromeTest.setEnabled(true);
        var result = MonochromeTest.color(Graphics.COLOR_WHITE);
        MonochromeTest.setEnabled(false);
        if (result != Graphics.COLOR_WHITE) {
            logger.error("white must map to white");
            return false;
        }
        return true;
    }

}
