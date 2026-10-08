import Toybox.Lang;
import Toybox.Test;

// Unit tests for ui/Labels.mc: the one enum-to-word table (A16). The label
// cases moved here from ChargingTests.mc when the functions left
// ChargingLogic; the words changed to the short chip wording (B4).
module LabelsTests {

    function _expectAll(logger as Logger, name as String, fn as Method(raw as String?) as String,
                        cases as Dictionary<String, String>) as Boolean {
        var keys = cases.keys();
        for (var i = 0; i < keys.size(); i += 1) {
            var key = keys[i] as String;
            var expected = cases.get(key) as String;
            var actual = fn.invoke(key);
            if (!actual.equals(expected)) {
                logger.error(name + " " + key + ": expected '" + expected + "', got '" + actual + "'");
                return false;
            }
        }
        return true;
    }

    // US-023: all six documented charging states, in chip wording.
    (:test)
    function chargingCoversAllSixDocumentedValues(logger as Logger) as Boolean {
        return _expectAll(logger, "charging", new Lang.Method(Labels, :charging), {
            "CHARGING" => "Charging",
            "READY_FOR_CHARGING" => "Plugged in",
            "CONNECT_CABLE" => "Plug in",
            "CHARGING_INTERRUPTED" => "Paused",
            "CONSERVING" => "Conserving",
            "DISCHARGING" => "Discharging"
        });
    }

    // openapi.json: clients "must tolerate values they do not recognize".
    // Humanised, not raw (A16) and not "Unknown".
    (:test)
    function unknownValuesAreHumanised(logger as Logger) as Boolean {
        if (!Labels.human("SOME_NEW_VALUE").equals("Some new value")) {
            logger.error("expected 'Some new value', got '" + Labels.human("SOME_NEW_VALUE") + "'");
            return false;
        }
        if (!Labels.charging("PRECONDITIONING_BATTERY").equals("Preconditioning battery")) {
            logger.error("an unknown charging state must be humanised, got '" + Labels.charging("PRECONDITIONING_BATTERY") + "'");
            return false;
        }
        if (!Labels.mode("SOME_FUTURE_MODE").equals("Some future mode")) {
            logger.error("an unknown mode must be humanised, got '" + Labels.mode("SOME_FUTURE_MODE") + "'");
            return false;
        }
        if (!Labels.chargeType("SOMETHING_NEW").equals("Something new")) {
            logger.error("an unknown chargeType must be humanised");
            return false;
        }
        if (!Labels.openClosed("UNSUPPORTED").equals("Unsupported")) {
            logger.error("an unknown door state must be humanised");
            return false;
        }
        return true;
    }

    // "No data" is a dash everywhere in this app, for every table.
    (:test)
    function nullIsADashEverywhere(logger as Logger) as Boolean {
        var fns = [
            new Lang.Method(Labels, :human), new Lang.Method(Labels, :lock),
            new Lang.Method(Labels, :charging), new Lang.Method(Labels, :chargeType),
            new Lang.Method(Labels, :engine), new Lang.Method(Labels, :climate),
            new Lang.Method(Labels, :openClosed), new Lang.Method(Labels, :mode),
            new Lang.Method(Labels, :maxCurrent), new Lang.Method(Labels, :day)
        ] as Array<Method(raw as String?) as String>;
        for (var i = 0; i < fns.size(); i += 1) {
            var actual = (fns[i] as Method(raw as String?) as String).invoke(null);
            if (!actual.equals("—")) {
                logger.error("function " + i.toString() + " rendered null as '" + actual + "'");
                return false;
            }
        }
        return true;
    }

    (:test)
    function lockWordsAndInsecureStates(logger as Logger) as Boolean {
        var ok = _expectAll(logger, "lock", new Lang.Method(Labels, :lock), {
            "YES" => "Locked", "NO" => "Unlocked", "OPENED" => "Open",
            "TRUNK_OPENED" => "Trunk open", "UNKNOWN" => "Unknown"
        });
        if (!ok) {
            return false;
        }
        if (Labels.isInsecureLock("YES") || Labels.isInsecureLock(null) || Labels.isInsecureLock("UNKNOWN")) {
            logger.error("locked, no data and unknown are not insecure");
            return false;
        }
        if (!Labels.isInsecureLock("NO") || !Labels.isInsecureLock("OPENED") || !Labels.isInsecureLock("TRUNK_OPENED")) {
            logger.error("unlocked, open and trunk open are insecure");
            return false;
        }
        return true;
    }

    (:test)
    function chargeTypeEngineClimateAndOpenClosed(logger as Logger) as Boolean {
        if (!_expectAll(logger, "chargeType", new Lang.Method(Labels, :chargeType),
                        { "AC" => "AC", "DC" => "DC fast", "OFF" => "Not charging" })) {
            return false;
        }
        if (!_expectAll(logger, "engine", new Lang.Method(Labels, :engine),
                        { "GASOLINE" => "Petrol", "ELECTRIC" => "Electric", "DIESEL" => "Diesel", "CNG" => "Gas" })) {
            return false;
        }
        if (!_expectAll(logger, "climate", new Lang.Method(Labels, :climate), {
                "OFF" => "Off", "HEATING" => "Heating", "COOLING" => "Cooling",
                "VENTILATION" => "Ventilating", "HEATING_AUXILIARY" => "Aux heating" })) {
            return false;
        }
        return _expectAll(logger, "openClosed", new Lang.Method(Labels, :openClosed),
                          { "CLOSED" => "Closed", "OPEN" => "Open", "ON" => "On", "OFF" => "Off" });
    }

    // US-025: the words ChargingLogic.modeLabel used, unchanged by the move.
    (:test)
    function modeKeepsItsWords(logger as Logger) as Boolean {
        return _expectAll(logger, "mode", new Lang.Method(Labels, :mode), {
            "MANUAL" => "Manual",
            "TIMER" => "Timer",
            "TIMER_CHARGING_WITH_CLIMATISATION" => "Timer + climate",
            "PREFERRED_CHARGING_TIMES" => "Preferred times",
            "ONLY_OWN_CURRENT" => "Own power only",
            "IMMEDIATE_DISCHARGING" => "Immediate discharging",
            "HOME_STORAGE_CHARGING" => "Home storage"
        });
    }

    // US-026: profile max current and timer weekdays.
    (:test)
    function maxCurrentAndDay(logger as Logger) as Boolean {
        if (!_expectAll(logger, "maxCurrent", new Lang.Method(Labels, :maxCurrent),
                        { "MAXIMUM" => "Maximum", "REDUCED" => "Reduced" })) {
            return false;
        }
        return _expectAll(logger, "day", new Lang.Method(Labels, :day), {
            "MONDAY" => "Mon", "TUESDAY" => "Tue", "WEDNESDAY" => "Wed", "THURSDAY" => "Thu",
            "FRIDAY" => "Fri", "SATURDAY" => "Sat", "SUNDAY" => "Sun"
        });
    }

}
