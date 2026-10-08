import Toybox.Lang;

// Every API enum to words, in one place (A16, B4). Sentence case, one or two
// words so a value fits a chip. openapi.json says clients "must tolerate
// values they do not recognize": an unknown value is humanised
// ("SOME_NEW_VALUE" -> "Some new value"), never shown raw and never "Unknown".
//
// Took over ChargingLogic's stateLabel, chargeTypeLabel, modeLabel,
// maxCurrentLabel and dayAbbrev (Phase 0). (:glance) because the glance and
// the complications show the same lock and charging words.
(:glance)
module Labels {

    const DASH = "—";
    const ELLIPSIS = "…";

    // Generic fallback for values the app has never seen. null is "no data",
    // which reads as a dash everywhere in this app.
    function human(raw as String?) as String {
        if (raw == null) {
            return DASH;
        }
        var chars = raw.toLower().toCharArray();
        var out = "";
        for (var i = 0; i < chars.size(); i += 1) {
            var ch = chars[i] as Char;
            if (ch == '_') {
                ch = ' ';
            }
            if (i == 0) {
                out += ch.toString().toUpper();
            } else {
                out += ch.toString();
            }
        }
        return out;
    }

    // status.doorsLocked (US-059).
    function lock(raw as String?) as String {
        if (raw == null) {
            return DASH;
        }
        if (raw.equals("YES")) {
            return "Locked";
        }
        if (raw.equals("NO")) {
            return "Unlocked";
        }
        if (raw.equals("OPENED")) {
            return "Open";
        }
        if (raw.equals("TRUNK_OPENED")) {
            return "Trunk open";
        }
        if (raw.equals("UNKNOWN")) {
            return "Unknown";
        }
        return human(raw);
    }

    // The lock states that get the amber treatment and sort first (A9).
    function isInsecureLock(raw as String?) as Boolean {
        if (raw == null) {
            return false;
        }
        return raw.equals("NO") || raw.equals("OPENED") || raw.equals("TRUNK_OPENED");
    }

    // charging.state (US-023), short enough for a chip ("Plug in", not
    // "Connect the cable").
    function charging(raw as String?) as String {
        if (raw == null) {
            return DASH;
        }
        if (raw.equals("CHARGING")) {
            return "Charging";
        }
        if (raw.equals("READY_FOR_CHARGING")) {
            return "Plugged in";
        }
        if (raw.equals("CONNECT_CABLE")) {
            return "Plug in";
        }
        if (raw.equals("CHARGING_INTERRUPTED")) {
            return "Paused";
        }
        if (raw.equals("CONSERVING")) {
            return "Conserving";
        }
        if (raw.equals("DISCHARGING")) {
            return "Discharging";
        }
        return human(raw);
    }

    // charging.chargeType (US-023).
    function chargeType(raw as String?) as String {
        if (raw == null) {
            return DASH;
        }
        if (raw.equals("AC")) {
            return "AC";
        }
        if (raw.equals("DC")) {
            return "DC fast";
        }
        if (raw.equals("OFF")) {
            return "Not charging";
        }
        return human(raw);
    }

    // Engine type on the fuel page; "Petrol" because the app speaks British
    // English and GASOLINE is the API's word, not the user's.
    function engine(raw as String?) as String {
        if (raw == null) {
            return DASH;
        }
        if (raw.equals("GASOLINE")) {
            return "Petrol";
        }
        if (raw.equals("ELECTRIC")) {
            return "Electric";
        }
        if (raw.equals("DIESEL")) {
            return "Diesel";
        }
        if (raw.equals("CNG")) {
            return "Gas";
        }
        return human(raw);
    }

    // airConditioning.state.
    function climate(raw as String?) as String {
        if (raw == null) {
            return DASH;
        }
        if (raw.equals("OFF")) {
            return "Off";
        }
        if (raw.equals("HEATING")) {
            return "Heating";
        }
        if (raw.equals("COOLING")) {
            return "Cooling";
        }
        if (raw.equals("VENTILATION")) {
            return "Ventilating";
        }
        if (raw.equals("HEATING_AUXILIARY")) {
            return "Aux heating";
        }
        return human(raw);
    }

    // Doors, windows, bonnet, trunk, lights, sunroof, window heating.
    function openClosed(raw as String?) as String {
        if (raw == null) {
            return DASH;
        }
        if (raw.equals("CLOSED")) {
            return "Closed";
        }
        if (raw.equals("OPEN")) {
            return "Open";
        }
        if (raw.equals("ON")) {
            return "On";
        }
        if (raw.equals("OFF")) {
            return "Off";
        }
        return human(raw);
    }

    // Charge mode (US-025); the words ChargingLogic.modeLabel used.
    function mode(raw as String?) as String {
        if (raw == null) {
            return DASH;
        }
        if (raw.equals("MANUAL")) {
            return "Manual";
        }
        if (raw.equals("TIMER")) {
            return "Timer";
        }
        if (raw.equals("TIMER_CHARGING_WITH_CLIMATISATION")) {
            return "Timer + climate";
        }
        if (raw.equals("PREFERRED_CHARGING_TIMES")) {
            return "Preferred times";
        }
        if (raw.equals("ONLY_OWN_CURRENT")) {
            return "Own power only";
        }
        if (raw.equals("IMMEDIATE_DISCHARGING")) {
            return "Immediate discharging";
        }
        if (raw.equals("HOME_STORAGE_CHARGING")) {
            return "Home storage";
        }
        return human(raw);
    }

    // Profile max charging current (US-026).
    function maxCurrent(raw as String?) as String {
        if (raw == null) {
            return DASH;
        }
        if (raw.equals("MAXIMUM")) {
            return "Maximum";
        }
        if (raw.equals("REDUCED")) {
            return "Reduced";
        }
        return human(raw);
    }

    // Timer weekdays (US-026); three letters so a recurrence fits one line.
    function day(raw as String?) as String {
        if (raw == null) {
            return DASH;
        }
        if (raw.equals("MONDAY")) {
            return "Mon";
        }
        if (raw.equals("TUESDAY")) {
            return "Tue";
        }
        if (raw.equals("WEDNESDAY")) {
            return "Wed";
        }
        if (raw.equals("THURSDAY")) {
            return "Thu";
        }
        if (raw.equals("FRIDAY")) {
            return "Fri";
        }
        if (raw.equals("SATURDAY")) {
            return "Sat";
        }
        if (raw.equals("SUNDAY")) {
            return "Sun";
        }
        return human(raw);
    }

}
