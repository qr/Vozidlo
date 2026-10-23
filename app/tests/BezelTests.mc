import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

// Unit tests for the pure half of ui/Bezel.mc. ciqDegrees() is the one
// conversion between the design's clockwise canvas angles and Dc.drawArc's
// counter-clockwise ones; getting it wrong mirrors every hint arc. The
// frame tests run on the Venu X1 fixture (GeoTests.venux1).
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
        var p = Bezel.polarAt(130, 130, r, deg);
        if (p[0] != x || p[1] != y) {
            logger.error("polarAt(130, 130, " + r.toString() + ", " + deg.toString() + "): expected " + x.toString() + "," + y.toString()
                + ", got " + p[0].toString() + "," + p[1].toString());
            return false;
        }
        return true;
    }

    // Canvas convention: 0 = 3 o'clock, 90 = 6 o'clock (clockwise, y down).
    (:test)
    function polarUsesCanvasAngles(logger as Logger) as Boolean {
        if (Bezel.polarAt(195, 195, 100, 0)[0] != 295) {
            logger.error("polarAt must measure from the centre it is given");
            return false;
        }
        return _at(logger, 100, 0, 230, 130)
            && _at(logger, 100, 90, 130, 230)
            && _at(logger, 100, -90, 130, 30)
            && _at(logger, 100, 180, 30, 130)
            && _at(logger, 108, Bezel.BTN_START, 224, 76);
    }

    // The deprecated BTN_* angles map onto the positions glyphAt() takes.
    (:test)
    function anglesMapToPositions(logger as Logger) as Boolean {
        if (Bezel.posOf(Bezel.BTN_START) != :start || Bezel.posOf(Bezel.BTN_BACK) != :back
            || Bezel.posOf(Bezel.BTN_UP) != :up || Bezel.posOf(Bezel.BTN_DOWN) != :down) {
            logger.error("every BTN_* angle must map to its position");
            return false;
        }
        if (Geo.buttonAngle(:up) != Bezel.BTN_UP || Geo.buttonAngle(:start) != Bezel.BTN_START) {
            logger.error("Geo and Bezel must agree on the button angles");
            return false;
        }
        return true;
    }

    function _near(logger as Logger, what as String, p as [Float, Float], x as Numeric, y as Numeric) as Boolean {
        if ((p[0] - x).abs() > 1.0 || (p[1] - y).abs() > 1.0) {
            logger.error(what + ": expected about " + x.toString() + "," + y.toString()
                + ", got " + p[0].format("%.1f") + "," + p[1].format("%.1f"));
            return false;
        }
        return true;
    }

    // The X1 ring is the display frame inset px(4) = 7, walked clockwise
    // from top centre: a quarter of it is the middle of the right side.
    (:test)
    function framePointWalksTheRectangle(logger as Logger) as Boolean {
        var x = GeoTests.venux1();
        return _near(logger, "start", Bezel.framePoint(x, 0), 224, 7)
            && _near(logger, "quarter", Bezel.framePoint(x, 0.25), 441, 243)
            && _near(logger, "half", Bezel.framePoint(x, 0.5), 224, 479)
            && _near(logger, "three quarters", Bezel.framePoint(x, 0.75), 7, 243)
            && _near(logger, "full turn wraps", Bezel.framePoint(x, 1.0), 224, 7);
    }

    // The pointer's base point: straight on the sides, on the corner circle
    // (r 58 - 7, centre 390,58) at 45 degrees.
    (:test)
    function frameHitFindsTheFrame(logger as Logger) as Boolean {
        var x = GeoTests.venux1();
        if (!(_near(logger, "up", Bezel.frameHit(x, -90), 224, 7)
            && _near(logger, "right", Bezel.frameHit(x, 0), 441, 243)
            && _near(logger, "left", Bezel.frameHit(x, 180), 7, 243)
            && _near(logger, "down", Bezel.frameHit(x, 90), 224, 479))) {
            return false;
        }
        var p = Bezel.frameHit(x, -45);
        var dx = p[0] - 390;
        var dy = p[1] - 58;
        var d = Math.sqrt(dx * dx + dy * dy);
        if ((d - 51).abs() > 1.0 || p[0] < 390 || p[1] > 58) {
            logger.error("a corner ray must end on the corner circle, got " + p[0].format("%.1f") + "," + p[1].format("%.1f"));
            return false;
        }
        return true;
    }

}
