import Toybox.Lang;
import Toybox.Test;

// Unit tests for the pure half of ui/Bezel.mc. ciqDegrees() is the one
// conversion between the design's clockwise canvas angles and Dc.drawArc's
// counter-clockwise ones; getting it wrong mirrors every hint arc.
module BezelTests {

    (:test)
    function ciqDegreesMirrorsCanvasAngles(logger as Logger) as Boolean {
        if (Bezel.ciqDegrees(Bezel.BTN_START) != 30) {
            logger.error("START (-30 canvas) must be 30 in CIQ, got " + Bezel.ciqDegrees(Bezel.BTN_START).toString());
            return false;
        }
        if (Bezel.ciqDegrees(Bezel.BTN_UP) != 180) {
            logger.error("UP (180 canvas) must stay 180, got " + Bezel.ciqDegrees(Bezel.BTN_UP).toString());
            return false;
        }
        if (Bezel.ciqDegrees(Bezel.BTN_DOWN) != 210) {
            logger.error("DOWN (150 canvas) must be 210 in CIQ, got " + Bezel.ciqDegrees(Bezel.BTN_DOWN).toString());
            return false;
        }
        if (Bezel.ciqDegrees(-90) != 90 || Bezel.ciqDegrees(0) != 0 || Bezel.ciqDegrees(450) != 270) {
            logger.error("12 o'clock is 90 in CIQ; 0 stays 0; angles past 360 wrap");
            return false;
        }
        return true;
    }

    function _at(logger as Logger, r as Number, deg as Number, x as Number, y as Number) as Boolean {
        var p = Bezel.polar(r, deg);
        if (p[0] != x || p[1] != y) {
            logger.error("polar(" + r.toString() + ", " + deg.toString() + "): expected " + x.toString() + "," + y.toString()
                + ", got " + p[0].toString() + "," + p[1].toString());
            return false;
        }
        return true;
    }

    // Canvas convention: 0 = 3 o'clock, 90 = 6 o'clock (clockwise, y down).
    (:test)
    function polarUsesCanvasAngles(logger as Logger) as Boolean {
        return _at(logger, 100, 0, 230, 130)
            && _at(logger, 100, 90, 130, 230)
            && _at(logger, 100, -90, 130, 30)
            && _at(logger, 100, 180, 30, 130)
            && _at(logger, 108, Bezel.BTN_START, 224, 76);
    }

}
