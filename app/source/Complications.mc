import Toybox.Complications;
import Toybox.Lang;

// US-038 (task 10): publishes state of charge, charging state, lock state
// and range as Connect IQ complications, so the user's own watch face can
// show vehicle state without this app building one (a watch face is
// explicitly out of scope for the product, see
// CONTRIBUTING.md, "What this project will not do"). Requires the
// ComplicationPublisher permission (manifest.xml) and the resource block
// at resources/complications/complications.xml, one <complication> per id
// below.
//
// Named VehicleComplications, not Complications, so this module's own name
// never shadows Toybox.Complications, which it imports below: Monkey C
// has no namespacing that would let two same-named modules coexist
// unqualified in one scope.
//
// PUBLISH ONLY, from Cache.mc, never by making a request: identical
// contract to GlanceView.mc, and for the identical reason: US-038 promises
// a watch face can show this WITHOUT the state ever costing a request the
// user didn't ask for. publish() is called from the home screen's onShow()
// (HomeScreen), i.e. whenever the full app is opened or returned to: there
// is no background service in this app (out of scope), so a complication
// reflects whatever Cache.mc held the last time this app actually ran.
module VehicleComplications {

    // Stable indices into resources/complications/complications.xml's
    // <complication id="..."> attributes (0-255, per the SDK's own
    // Complications guide). NEVER renumber an existing one after release:
    // that guide's own warning: doing so breaks every watch face already
    // displaying it.
    const ID_SOC = 0;
    const ID_CHARGING_STATE = 1;
    const ID_LOCK_STATE = 2;
    const ID_RANGE = 3;

    // The app-wide "no data" dash (Labels.DASH), so a watch face shows the
    // same placeholder as every screen.
    const _PLACEHOLDER = Labels.DASH;

    // Called once per touch-point (never wired to a timer or to
    // onUpdate()), which keeps this comfortably under any update-rate
    // concern by construction rather than by throttling.
    function publish() as Void {
        if (!(Toybox has :Complications)) {
            return; // defensive only: this project targets a single,
                     // known-supported device (manifest.xml), so this
                     // should never actually be false.
        }
        _publishSoc();
        _publishChargingState();
        _publishLockState();
        _publishRange();
    }

    function _publishSoc() as Void {
        var charging = Cache.section("charging");
        var soc = (charging != null) ? charging.get("batterySocPercent") : null;
        Complications.updateComplication(ID_SOC, {
            :value => _numericOrPlaceholder(soc),
            :shortLabel => "SoC",
            // "" rather than null when there is no reading: Complications.Data's
            // :unit key types as Complications.Unit or String (no Null variant),
            // and an empty string reads as "no unit" exactly like null would
            // per the SDK's own Face It table ("a numerical or string value
            // will be displayed without conversion and without any units
            // appended") without fighting the dict literal's inferred type.
            :unit => (soc != null) ? "%" : ""
        });
    }

    function _publishChargingState() as Void {
        var charging = Cache.section("charging");
        var state = (charging != null) ? (charging.get("state") as String?) : null;
        // Sentence-case words from Labels ("Plugged in", not
        // READY_FOR_CHARGING): a watch face shows :value as it is (A16).
        Complications.updateComplication(ID_CHARGING_STATE, {
            :value => Labels.charging(state),
            :shortLabel => "Chrg"
        });
    }

    function _publishLockState() as Void {
        var status = Cache.section("status");
        var locked = (status != null) ? (status.get("doorsLocked") as String?) : null;
        Complications.updateComplication(ID_LOCK_STATE, {
            :value => Labels.lock(locked),
            :shortLabel => "Lock"
        });
    }

    // US-038 lists "range", meaning the vehicle's remaining cruising range:
    // the same charging.rangeMeters Cache.mc already stores (see that
    // module's _projectCharging()), converted to whole kilometres. Never
    // re-derived from fuelStatus: charging.rangeMeters is what task 7/8's
    // own screens already treat as authoritative for an EV, and this
    // module has no reason to disagree with them.
    function _publishRange() as Void {
        var charging = Cache.section("charging");
        var rangeMeters = (charging != null) ? charging.get("rangeMeters") : null;
        var km = _metersToKm(rangeMeters);
        Complications.updateComplication(ID_RANGE, {
            :value => (km != null) ? (km as Number) : _PLACEHOLDER,
            :shortLabel => "Rng",
            :unit => (km != null) ? "km" : "" // see _publishSoc()'s own comment on why "" not null
        });
    }

    // Complications.Data's :value accepts String, Number, Float, Long,
    // Double or null (see the SDK's own typedef): a raw cached Object is
    // already one of those (Cache.mc's stored fields are always one of
    // Storage's accepted scalar types) or null, so this only needs to swap
    // null for the placeholder string; never invents a zero.
    function _numericOrPlaceholder(value as Object?) as String or Number or Float or Long or Double {
        if (value == null) {
            return _PLACEHOLDER;
        }
        if (value instanceof Number) {
            return value as Number;
        }
        if (value instanceof Float) {
            return value as Float;
        }
        if (value instanceof Long) {
            return value as Long;
        }
        if (value instanceof Double) {
            return value as Double;
        }
        if (value instanceof String) {
            return value as String;
        }
        return _PLACEHOLDER; // an unexpected stored type: never crash, show the placeholder
    }

    function _metersToKm(value as Object?) as Number? {
        if (value == null) {
            return null;
        }
        var meters;
        if (value instanceof Float) {
            meters = value as Float;
        } else if (value instanceof Number) {
            meters = (value as Number).toFloat();
        } else {
            return null;
        }
        return (meters / 1000.0).toNumber();
    }

}
