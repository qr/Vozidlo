import Toybox.Lang;

// Task 8 (US-022..US-026): every pure, side-effect-free decision the
// charging screens need, kept apart from any View/Delegate exactly the way
// ui/ControlsView.mc's own ControlTiles module is, so tests/ChargingTests.mc
// can exercise "what does this state mean", "which choices does the picker
// offer" and "is this profile the one where the car is parked" without
// constructing a live View, a Cache entry or a network response at all.
module ChargingLogic {

    // US-024: the schema permits 1-100 but documents that vehicles typically
    // accept 50-100 in steps of ten and reject anything else: offering
    // exactly this list, never the schema's full range, is the whole of that
    // decision. Fixed array, not computed, so a test can assert its exact
    // contents (see docs/requirements.md, US-022 to US-027).
    function limitChoices() as Array<Number> {
        return [50, 60, 70, 80, 90, 100] as Array<Number>;
    }

    // Index into limitChoices() to preselect: `current`
    // (settings.targetStateOfChargeInPercent) rounded down to the nearest
    // ten and clamped into range, or the schema's own example (80) when
    // nothing has ever been cached.
    function limitIndexFor(current as Number?) as Number {
        var choices = limitChoices();
        if (current == null) {
            return _indexOf(choices, 80);
        }
        if (current <= (choices[0] as Number)) {
            return 0;
        }
        if (current >= (choices[choices.size() - 1] as Number)) {
            return choices.size() - 1;
        }
        var rounded = (current / 10) * 10;
        var idx = _indexOf(choices, rounded);
        if (idx >= 0) {
            return idx;
        }
        return _indexOf(choices, 80);
    }

    function _indexOf(choices as Array<Number>, value as Number) as Number {
        for (var i = 0; i < choices.size(); i += 1) {
            if ((choices[i] as Number) == value) {
                return i;
            }
        }
        return 0;
    }

    // US-024: "indicating batteryCareModeTargetValueInPercent as
    // recommended" is nothing fancier than this equality check. `careTarget`
    // null means the vehicle never reported one, so nothing is recommended:
    // never invent a default here.
    function isRecommended(value as Number, careTarget as Number?) as Boolean {
        return careTarget != null && value == careTarget;
    }

    // US-023: the six documented `state` values in plain language. Any other
    // value is returned verbatim rather than "unknown": openapi.json
    // documents that new values may be added over time and clients "must
    // tolerate values they do not recognize" (the same rule
    // VehicleState.mc's own comment quotes for every other enum in this app).
    function stateLabel(state as String?) as String {
        if (state == null) {
            return "—";
        }
        if (state.equals("CONNECT_CABLE")) {
            return "Connect the cable";
        }
        if (state.equals("CHARGING")) {
            return "Charging";
        }
        if (state.equals("CONSERVING")) {
            return "Conserving battery";
        }
        if (state.equals("READY_FOR_CHARGING")) {
            return "Ready to charge";
        }
        if (state.equals("DISCHARGING")) {
            return "Discharging";
        }
        if (state.equals("CHARGING_INTERRUPTED")) {
            return "Charging interrupted";
        }
        return state;
    }

    // US-023: AC/DC/OFF in plain language; forward-compatible the same way.
    function chargeTypeLabel(chargeType as String?) as String {
        if (chargeType == null) {
            return "—";
        }
        if (chargeType.equals("AC")) {
            return "AC";
        }
        if (chargeType.equals("DC")) {
            return "DC (fast)";
        }
        if (chargeType.equals("OFF")) {
            return "Not charging";
        }
        return chargeType;
    }

    // US-022: the one state under which starting is still offered but must
    // be accompanied by a warning that no cable appears to be connected.
    function needsCableWarning(state as String?) as Boolean {
        return state != null && state.equals("CONNECT_CABLE");
    }

    // US-025: the concrete case this task exists to guard against. An
    // empty (or absent) availableChargeModes hides the action regardless of
    // what operations[] claims (our reference vehicle lists setChargeMode in
    // operations[] and returns availableChargeModes: [], see
    // docs/requirements.md, US-025).
    function modeActionVisible(availableModes as Array<String>?, hasOperation as Boolean) as Boolean {
        if (!hasOperation) {
            return false;
        }
        return availableModes != null && availableModes.size() > 0;
    }

    // Plain-language label for one charge mode value, falling back to the
    // raw value for anything not in the documented list (forward-compatible,
    // same rule as stateLabel()/chargeTypeLabel() above).
    function modeLabel(mode as String?) as String {
        if (mode == null) {
            return "—";
        }
        if (mode.equals("MANUAL")) {
            return "Manual";
        }
        if (mode.equals("TIMER")) {
            return "Timer";
        }
        if (mode.equals("TIMER_CHARGING_WITH_CLIMATISATION")) {
            return "Timer + climate";
        }
        if (mode.equals("PREFERRED_CHARGING_TIMES")) {
            return "Preferred times";
        }
        if (mode.equals("ONLY_OWN_CURRENT")) {
            return "Own power only";
        }
        if (mode.equals("IMMEDIATE_DISCHARGING")) {
            return "Immediate discharging";
        }
        if (mode.equals("HOME_STORAGE_CHARGING")) {
            return "Home storage";
        }
        return mode;
    }

    // US-026: highlights the profile matching where the car is parked. A
    // profile id is an int64 (`format: int64` in openapi.json), which JSON
    // decoding can hand back as either Number or Long depending on
    // magnitude: neither == nor .equals() compares those two types as
    // equal to each other even when the underlying value is, so both sides
    // are normalised to Long first.
    function isCurrentProfile(profileId as Object?, currentPositionProfileId as Object?) as Boolean {
        if (profileId == null || currentPositionProfileId == null) {
            return false;
        }
        var a = _toComparableLong(profileId);
        var b = _toComparableLong(currentPositionProfileId);
        if (a == null || b == null) {
            return profileId.equals(currentPositionProfileId);
        }
        return a == b;
    }

    function _toComparableLong(value as Object) as Long? {
        if (value instanceof Number) {
            return (value as Number).toLong();
        }
        if (value instanceof Long) {
            return value as Long;
        }
        return null;
    }

    // US-026: max charging current in plain language.
    function maxCurrentLabel(value as String?) as String {
        if (value == null) {
            return "—";
        }
        if (value.equals("MAXIMUM")) {
            return "Maximum";
        }
        if (value.equals("REDUCED")) {
            return "Reduced";
        }
        return value;
    }

    function dayAbbrev(day as String?) as String {
        if (day == null) {
            return "—";
        }
        if (day.equals("MONDAY")) {
            return "Mon";
        }
        if (day.equals("TUESDAY")) {
            return "Tue";
        }
        if (day.equals("WEDNESDAY")) {
            return "Wed";
        }
        if (day.equals("THURSDAY")) {
            return "Thu";
        }
        if (day.equals("FRIDAY")) {
            return "Fri";
        }
        if (day.equals("SATURDAY")) {
            return "Sat";
        }
        if (day.equals("SUNDAY")) {
            return "Sun";
        }
        return day;
    }

    // US-026: "enabled timers with their time and recurrence". This is the
    // recurrence half; `time` (HH:mm) is shown as-is by whatever draws it.
    // A timer this app has never seen a `type` for (forward-compat, same
    // rule as every other enum) still renders as something, never blank.
    function timerRecurrenceLabel(timerType as String?, recurringOn as Array<String>?, oneOffDay as String?) as String {
        if (timerType == null) {
            return "—";
        }
        if (timerType.equals("ONE_OFF")) {
            return (oneOffDay != null) ? ("Once, " + dayAbbrev(oneOffDay)) : "Once";
        }
        if (timerType.equals("RECURRING")) {
            if (recurringOn == null || recurringOn.size() == 0) {
                return "Recurring";
            }
            var text = "";
            for (var i = 0; i < recurringOn.size(); i += 1) {
                if (i > 0) {
                    text += ",";
                }
                text += dayAbbrev(recurringOn[i] as String?);
            }
            return text;
        }
        return timerType;
    }

}
