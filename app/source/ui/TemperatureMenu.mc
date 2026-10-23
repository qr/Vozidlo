import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// US-018's on-watch half: "adjustable on the watch as well as in phone
// settings." AppBase.getSettingsView() is a watch app's own hook for this
// (docs/best-practices: "watch faces and data fields may not" offer one),
// wired from VozidloApp.getSettingsView(). A list of whole degrees on every
// watch (M6), the same move as the charge limit (ChargingLimitMenu): the old
// UP/DOWN stepper put its + and - glyphs at buttons the Venu watches do not
// have. A pick commits to the SAME Properties key the phone-side setting
// (settings.xml) edits, so there is exactly one value regardless of which
// side changed it last.
//
// Whole degrees in whatever unit Settings.Config.temperatureUnit names,
// never converted (Commands.airConditioningBody explains why the app does
// no C/F conversion).
module TemperatureMenu {

    // The list per unit: 16 to 30 °C, 60 to 86 °F (the same range).
    function choices(unit as String) as Array<Number> {
        var first = unit.equals("F") ? 60 : 16;
        var last = unit.equals("F") ? 86 : 30;
        var out = [] as Array<Number>;
        for (var v = first; v <= last; v += 1) {
            out.add(v);
        }
        return out;
    }

    // Index of the choice nearest to value (the lower one on a tie),
    // clamped to the ends of the list.
    function indexFor(value as Numeric, choices as Array<Number>) as Number {
        var best = 0;
        var bestD = null as Float?;
        for (var i = 0; i < choices.size(); i += 1) {
            var d = ((choices[i] as Number) - value).abs().toFloat();
            if (bestD == null || d < bestD) {
                best = i;
                bestD = d;
            }
        }
        return best;
    }

    // Check column for one row: null (no column) when there is no current
    // value, else whether value is exactly the current one, so 21.5 from
    // the car checks no row.
    function checkFor(value as Number, current as Numeric?) as Boolean? {
        if (current == null) {
            return null;
        }
        return current.toFloat() == value.toFloat();
    }

    // US-018's default chain: an existing override first, then what the car
    // itself last reported, but only in the unit this list is in (no
    // conversion); null when neither is known.
    function current(settings as Settings.Config) as Numeric? {
        var existing = settings.targetTemperature;
        if (existing != null) {
            return existing;
        }
        var cached = Cache.section("airConditioning");
        if (cached == null) {
            return null;
        }
        var unit = cached.get("targetUnit");
        if (!(unit instanceof String) || !(unit as String).equals(Commands.apiUnit(settings.temperatureUnit))) {
            return null;
        }
        var value = cached.get("targetValue");
        if (value instanceof Float || value instanceof Number) {
            return value as Numeric;
        }
        return null;
    }

    // A neutral default to focus on when nothing is known, so the list never
    // opens on its first row by accident.
    function defaultFor(unit as String) as Number {
        return unit.equals("F") ? 70 : 21;
    }

    // "Temperature": "Target temperature" does not fit the NightMenu title
    // area on any round watch. Focus on the current value (nearest row),
    // checked only on an exact match.
    function build(unit as String, current as Numeric?) as NightMenu {
        var list = choices(unit);
        var focusOn = current != null ? Math.round(current.toFloat()).toNumber() : defaultFor(unit);
        var suffix = unit.equals("F") ? " °F" : " °C";
        var menu = new NightMenu("Temperature", indexFor(focusOn, list), null);
        for (var i = 0; i < list.size(); i += 1) {
            var value = list[i] as Number;
            menu.addItem(new NightMenuItem(value, value.toString() + suffix, null, null, checkFor(value, current)));
        }
        return menu;
    }

    // The settings view: the list for this watch's unit and value.
    function settingsView() as [NightMenu, TemperatureMenuDelegate] {
        var settings = getApp().getSettings();
        return [build(settings.temperatureUnit, current(settings)), new TemperatureMenuDelegate()];
    }

}

// A pick pops the list (NightMenuDelegate(true)), back to the system's
// settings, and commits at once: this is a preference, not a command, so
// there is nothing to confirm.
class TemperatureMenuDelegate extends NightMenuDelegate {

    function initialize() {
        NightMenuDelegate.initialize(true);
    }

    function onPick(id as Object?) as Void {
        if (id instanceof Number) {
            Properties.setValue("TargetTemperature", id as Number);
            // A Properties write made from inside the app, not synced in
            // from the phone, does not trigger onSettingsChanged() on its own
            // (same situation OnboardingClearConfirmDelegate documents): call
            // it directly so the home screen's next command picks this up.
            getApp().onSettingsChanged();
            WatchUi.requestUpdate();
        }
    }

}
