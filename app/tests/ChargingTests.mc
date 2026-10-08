import Toybox.Lang;
import Toybox.Test;

// Unit tests for ui/ChargingLogic.mc (task 8, US-022..US-026): every pure
// decision the charging screens make, exercised without constructing a
// live View, Cache entry or network response: same rationale as
// ControlTilesTests.mc for ui/ControlTiles.mc.
module ChargingTests {

    // ------------------------------------------------------- US-023: state

    // US-022: the one state that still offers Start but must warn.
    (:test)
    function needsCableWarningOnlyForConnectCable(logger as Logger) as Boolean {
        if (!ChargingLogic.needsCableWarning("CONNECT_CABLE")) {
            logger.error("CONNECT_CABLE must trigger the cable warning");
            return false;
        }
        if (ChargingLogic.needsCableWarning("CHARGING")) {
            logger.error("CHARGING must not trigger the cable warning");
            return false;
        }
        if (ChargingLogic.needsCableWarning(null)) {
            logger.error("no cached state at all must not trigger the cable warning");
            return false;
        }
        return true;
    }

    // ------------------------------------------------------- US-024: limit

    (:test)
    function limitChoicesIsExactlyFiftyToHundredInTens(logger as Logger) as Boolean {
        var choices = ChargingLogic.limitChoices();
        var expected = [50, 60, 70, 80, 90, 100] as Array<Number>;
        if (choices.size() != expected.size()) {
            logger.error("expected 6 choices, got " + choices.size().toString());
            return false;
        }
        for (var i = 0; i < expected.size(); i += 1) {
            if ((choices[i] as Number) != (expected[i] as Number)) {
                logger.error("choice " + i.toString() + ": expected " + expected[i].toString() + ", got " + choices[i].toString());
                return false;
            }
        }
        return true;
    }

    (:test)
    function limitIndexForPreselectsTheCurrentValue(logger as Logger) as Boolean {
        var choices = ChargingLogic.limitChoices();
        if ((choices[ChargingLogic.limitIndexFor(80)] as Number) != 80) {
            logger.error("80 must preselect the 80 choice");
            return false;
        }
        if ((choices[ChargingLogic.limitIndexFor(50)] as Number) != 50) {
            logger.error("the lowest offered value must preselect itself");
            return false;
        }
        if ((choices[ChargingLogic.limitIndexFor(100)] as Number) != 100) {
            logger.error("the highest offered value must preselect itself");
            return false;
        }
        return true;
    }

    // US-024: values outside the offered range (the schema's own 1-49) must
    // still clamp to something on the picker, never index out of bounds.
    (:test)
    function limitIndexForClampsOutOfRangeValues(logger as Logger) as Boolean {
        var choices = ChargingLogic.limitChoices();
        if ((choices[ChargingLogic.limitIndexFor(1)] as Number) != 50) {
            logger.error("a value below the offered range must clamp to the lowest choice");
            return false;
        }
        if ((choices[ChargingLogic.limitIndexFor(100)] as Number) != 100) {
            logger.error("the maximum must clamp to the highest choice");
            return false;
        }
        return true;
    }

    // No cached value yet: must still preselect something sensible rather
    // than crash or default to index 0 arbitrarily.
    (:test)
    function limitIndexForDefaultsWhenNothingCached(logger as Logger) as Boolean {
        var choices = ChargingLogic.limitChoices();
        var idx = ChargingLogic.limitIndexFor(null);
        if (idx < 0 || idx >= choices.size()) {
            logger.error("expected a valid index with nothing cached, got " + idx.toString());
            return false;
        }
        return true;
    }

    // US-024: "indicating batteryCareModeTargetValueInPercent as
    // recommended".
    (:test)
    function isRecommendedMatchesBatteryCareTargetOnly(logger as Logger) as Boolean {
        if (!ChargingLogic.isRecommended(80, 80)) {
            logger.error("a value equal to the care target must be recommended");
            return false;
        }
        if (ChargingLogic.isRecommended(90, 80)) {
            logger.error("a different value must not be recommended");
            return false;
        }
        if (ChargingLogic.isRecommended(80, null)) {
            logger.error("no care target at all must never be recommended");
            return false;
        }
        return true;
    }

    // ------------------------------------------------------- US-025: mode

    // The concrete case this task exists to guard against: an empty
    // availableChargeModes hides the action even though operations[] lists
    // setChargeMode (hasOperation true here).
    (:test)
    function modeActionHiddenWhenAvailableModesEmptyEvenWithOperation(logger as Logger) as Boolean {
        if (ChargingLogic.modeActionVisible([] as Array<String>, true)) {
            logger.error("an empty availableChargeModes must hide the action regardless of operations[]");
            return false;
        }
        if (ChargingLogic.modeActionVisible(null, true)) {
            logger.error("an absent availableChargeModes must also hide the action");
            return false;
        }
        return true;
    }

    (:test)
    function modeActionVisibleWithNonEmptyModesAndOperation(logger as Logger) as Boolean {
        var modes = ["MANUAL", "TIMER"] as Array<String>;
        if (!ChargingLogic.modeActionVisible(modes, true)) {
            logger.error("non-empty modes plus the operation must show the action");
            return false;
        }
        return true;
    }

    // Even non-empty modes must not be offered if the operation itself is
    // gone from operations[]: modeActionVisible() checks both.
    (:test)
    function modeActionHiddenWithoutTheOperationEvenWithModes(logger as Logger) as Boolean {
        var modes = ["MANUAL", "TIMER"] as Array<String>;
        if (ChargingLogic.modeActionVisible(modes, false)) {
            logger.error("modes present but the operation absent must still hide the action");
            return false;
        }
        return true;
    }

    // ---------------------------------------------------- US-026: profiles

    (:test)
    function isCurrentProfileMatchesById(logger as Logger) as Boolean {
        if (!ChargingLogic.isCurrentProfile(123456, 123456)) {
            logger.error("matching ids must be the current profile");
            return false;
        }
        if (ChargingLogic.isCurrentProfile(123456, 999)) {
            logger.error("different ids must not match");
            return false;
        }
        if (ChargingLogic.isCurrentProfile(null, 123456)) {
            logger.error("a null profile id must never match");
            return false;
        }
        if (ChargingLogic.isCurrentProfile(123456, null)) {
            logger.error("no current-position profile at all must never match");
            return false;
        }
        return true;
    }

    // JSON int64 values can decode as either Number or Long depending on
    // magnitude: isCurrentProfile() must still match across that boundary.
    (:test)
    function isCurrentProfileMatchesAcrossNumberAndLong(logger as Logger) as Boolean {
        var asLong = 123456L;
        if (!ChargingLogic.isCurrentProfile(123456, asLong)) {
            logger.error("a Number id and an equal Long id must still be recognised as the same profile");
            return false;
        }
        return true;
    }

    (:test)
    function timerRecurrenceLabelForRecurringListsDays(logger as Logger) as Boolean {
        var days = ["MONDAY", "WEDNESDAY", "FRIDAY"] as Array<String>;
        var label = ChargingLogic.timerRecurrenceLabel("RECURRING", days, null);
        if (!label.equals("Mon,Wed,Fri")) {
            logger.error("expected 'Mon,Wed,Fri', got '" + label + "'");
            return false;
        }
        return true;
    }

    (:test)
    function timerRecurrenceLabelForOneOffNamesTheDay(logger as Logger) as Boolean {
        var label = ChargingLogic.timerRecurrenceLabel("ONE_OFF", null, "TUESDAY");
        if (!label.equals("Once, Tue")) {
            logger.error("expected 'Once, Tue', got '" + label + "'");
            return false;
        }
        return true;
    }

    // Forward-compat: an unrecognised timer type must still render as
    // something, never crash and never silently vanish.
    (:test)
    function timerRecurrenceLabelPassesThroughUnrecognisedTypeVerbatim(logger as Logger) as Boolean {
        var label = ChargingLogic.timerRecurrenceLabel("SOME_FUTURE_TYPE", null, null);
        if (!label.equals("SOME_FUTURE_TYPE")) {
            logger.error("expected the unrecognised timer type verbatim, got '" + label + "'");
            return false;
        }
        return true;
    }

}
