import Toybox.Lang;
import Toybox.Test;

// Unit tests for ui/TemperatureMenu.mc (US-018, M6): the list of whole
// degrees per unit, which row gets the focus and which the check, without
// building the menu itself.
module TemperatureMenuTests {

    (:test)
    function celsiusListsSixteenToThirty(logger as Logger) as Boolean {
        var c = TemperatureMenu.choices("C");
        if (c.size() != 15 || c[0] != 16 || c[14] != 30) {
            logger.error("expected 15 choices 16..30 °C, got " + c.size() + " from " + c[0]);
            return false;
        }
        return true;
    }

    (:test)
    function fahrenheitListsSixtyToEightySix(logger as Logger) as Boolean {
        var f = TemperatureMenu.choices("F");
        if (f.size() != 27 || f[0] != 60 || f[26] != 86) {
            logger.error("expected 27 choices 60..86 °F, got " + f.size() + " from " + f[0]);
            return false;
        }
        return true;
    }

    // Nearest row, clamped to the ends of the list, the lower one on a tie.
    (:test)
    function indexIsNearestAndClamped(logger as Logger) as Boolean {
        var c = TemperatureMenu.choices("C");
        var cases = [[21, 5], [16, 0], [30, 14], [5, 0], [100, 14], [21.4, 5], [21.6, 6], [21.5, 5]] as Array<Array<Numeric>>;
        for (var i = 0; i < cases.size(); i += 1) {
            var got = TemperatureMenu.indexFor(cases[i][0], c);
            if (got != cases[i][1]) {
                logger.error("indexFor(" + cases[i][0] + ") = " + got + ", expected " + cases[i][1]);
                return false;
            }
        }
        var f = TemperatureMenu.choices("F");
        if (TemperatureMenu.indexFor(21, f) != 0 || TemperatureMenu.indexFor(70, f) != 10) {
            logger.error("°F: 21 must clamp to 60 (index 0), 70 is index 10");
            return false;
        }
        return true;
    }

    // A check only on the row that is exactly the current value; no check
    // column at all when no value is known.
    (:test)
    function checkOnlyOnAnExactMatch(logger as Logger) as Boolean {
        if (TemperatureMenu.checkFor(21, 21) != true || TemperatureMenu.checkFor(22, 21) != false) {
            logger.error("21 checks the 21 row and no other");
            return false;
        }
        if (TemperatureMenu.checkFor(21, 21.0) != true) {
            logger.error("a car value of 21.0 is exactly 21");
            return false;
        }
        if (TemperatureMenu.checkFor(21, 21.5) != false || TemperatureMenu.checkFor(22, 21.5) != false) {
            logger.error("21.5 checks no row");
            return false;
        }
        if (TemperatureMenu.checkFor(21, null) != null) {
            logger.error("no current value means no check column");
            return false;
        }
        return true;
    }

    (:test)
    function defaultIsInTheList(logger as Logger) as Boolean {
        var units = ["C", "F"] as Array<String>;
        for (var i = 0; i < units.size(); i += 1) {
            var list = TemperatureMenu.choices(units[i]);
            var d = TemperatureMenu.defaultFor(units[i]);
            if (list[TemperatureMenu.indexFor(d, list)] != d) {
                logger.error("default " + d + " is not a row of the " + units[i] + " list");
                return false;
            }
        }
        return true;
    }

}
