import Toybox.Lang;

// Task 8 (US-022..US-026): every pure, side-effect-free decision the
// charging screens need, kept apart from any View/Delegate exactly the way
// ui/ControlTiles.mc is, so tests/ChargingTests.mc
// can exercise "what does this state mean", "which choices does the picker
// offer" and "is this profile the one where the car is parked" without
// constructing a live View, a Cache entry or a network response at all.
// Enum-to-word labels moved to ui/Labels.mc so every screen and the glance
// share one wording (A16).
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

    // US-026: "enabled timers with their time and recurrence". This is the
    // recurrence half; `time` (HH:mm) is shown as-is by whatever draws it.
    // A timer this app has never seen a `type` for (forward-compat, same
    // rule as every other enum) still renders as something, never blank.
    function timerRecurrenceLabel(timerType as String?, recurringOn as Array<String>?, oneOffDay as String?) as String {
        if (timerType == null) {
            return Labels.DASH;
        }
        if (timerType.equals("ONE_OFF")) {
            return (oneOffDay != null) ? ("Once, " + Labels.day(oneOffDay)) : "Once";
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
                text += Labels.day(recurringOn[i] as String?);
            }
            return text;
        }
        return timerType;
    }

}
