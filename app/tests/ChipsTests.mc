import Toybox.Lang;
import Toybox.Test;

// Unit tests for the pure half of ui/Chips.mc: which state gets which chip
// (warn means amber plus "!", B3) and the width arithmetic the C8 layout
// checks rely on.
module ChipsTests {

    function _is(logger as Logger, chip as Chips.Chip?, text as String, kind as Symbol) as Boolean {
        if (chip == null) {
            logger.error("expected a '" + text + "' chip, got none");
            return false;
        }
        if (!chip.text.equals(text) || chip.kind != kind) {
            logger.error("expected '" + text + "', got '" + chip.text + "' of another kind");
            return false;
        }
        return true;
    }

    // US-059: an insecure car is amber, whatever is open.
    (:test)
    function lockChipWarnsWhenInsecure(logger as Logger) as Boolean {
        return _is(logger, Chips.forLock("TRUNK_OPENED"), "Trunk open", :warn)
            && _is(logger, Chips.forLock("NO"), "Unlocked", :warn)
            && _is(logger, Chips.forLock("YES"), "Locked", :outline);
    }

    // PoC resolution: the cable chip reads "! Plug in" in amber.
    (:test)
    function chargingChipKinds(logger as Logger) as Boolean {
        var cable = Chips.forCharging("CONNECT_CABLE");
        if (!_is(logger, cable, "Plug in", :warn)) {
            return false;
        }
        if (Chips.iconFor(cable as Chips.Chip) != :bang) {
            logger.error("a warn chip must carry the '!' icon");
            return false;
        }
        if (!_is(logger, Chips.forCharging("CHARGING"), "Charging", :accent)) {
            return false;
        }
        if (!_is(logger, Chips.forCharging("READY_FOR_CHARGING"), "Plugged in", :outline)) {
            return false;
        }
        if (Chips.forCharging(null) != null || Chips.forCharging("DISCHARGING") != null) {
            logger.error("no data and discharging need no chip");
            return false;
        }
        return true;
    }

    (:test)
    function climateChipOnlyWhileRunning(logger as Logger) as Boolean {
        if (Chips.forClimate("OFF") != null || Chips.forClimate(null) != null) {
            logger.error("climate OFF or no data must give no chip");
            return false;
        }
        return _is(logger, Chips.forClimate("HEATING"), "Heating", :outline);
    }

    // B4: 8 px padding each side, 14 for an icon; a row adds its gaps.
    (:test)
    function widthMaths(logger as Logger) as Boolean {
        if (Chips.width(50, false) != 66 || Chips.width(50, true) != 80) {
            logger.error("expected 66 without and 80 with an icon for 50 px of text");
            return false;
        }
        if (Chips.rowWidth([80, 66] as Array<Number>, 6) != 152) {
            logger.error("expected 80 + 6 + 66 = 152");
            return false;
        }
        if (Chips.rowWidth([] as Array<Number>, 6) != 0) {
            logger.error("an empty row has no width");
            return false;
        }
        return true;
    }

}
