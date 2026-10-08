import Toybox.Lang;

// US-036/US-037: which actions the home list offers, and which one gets the
// focus. Pure and side-effect-free apart from TileOrder's Storage read in
// rows(), so tests/ControlTilesTests.mc can exercise "which rows show up" and
// "which one is primary" without constructing a live menu. Moved unchanged
// from the old ControlsView.mc (Night Panel WP1); the seven-tile cap and its
// More menu went with the grid: the hero list scrolls, so every action is a
// row (ui-improvements.md C1b "No 7-tile cap needed").
module ControlTiles {

    // One entry in the fixed candidate list this screen can ever show.
    // `operation` is the exact operations[] name (see mock/openapi.json's
    // VehicleOperation enum) gating this row; `requiresSpin` is US-021's
    // "hidden entirely when no S-PIN is configured", checked independently
    // of operations[] since the API has no way to say "supported, but only
    // with a PIN we don't have".
    class Candidate {
        public var actionId as Symbol;
        public var operation as String;
        public var requiresSpin as Boolean;
        public var label as String;

        function initialize(action as Symbol, operationName as String, spinRequired as Boolean, tileLabel as String) {
            actionId = action;
            operation = operationName;
            requiresSpin = spinRequired;
            label = tileLabel;
        }
    }

    // Navigation rows: not operations[]-gated commands, so they skip every
    // command guard (HomeDelegate opens a screen for them).
    const FIND_MY_CAR as Symbol = :findMyCar;
    const OPEN_STATUS as Symbol = :openStatusDetail;
    const OPEN_CHARGING as Symbol = :openChargingDetail;
    const OPEN_TILE_ORDER as Symbol = :openTileOrder;

    // Fixed order: also the fallback search order primaryAction() below
    // walks when climate itself is unsupported. The two charging rows
    // (US-022) share the same operations[] gate and are never S-PIN gated.
    // Both directions are offered together exactly like climate's own pair:
    // visibleCandidates() never looks at charging STATE, only at capability,
    // so CONNECT_CABLE (Commands.announcement()) can never be the reason
    // "Start charging" is hidden.
    function _candidates() as Array<Candidate> {
        return [
            new Candidate(ConfirmationPolicy.START_CLIMATE, "startAirConditioning", false, "Start climate"),
            new Candidate(ConfirmationPolicy.STOP_CLIMATE, "stopAirConditioning", false, "Stop climate"),
            new Candidate(ConfirmationPolicy.START_VENTILATION, "startActiveVentilation", false, "Start ventilation"),
            new Candidate(ConfirmationPolicy.STOP_VENTILATION, "stopActiveVentilation", false, "Stop ventilation"),
            new Candidate(ConfirmationPolicy.START_AUX_HEATING, "startAuxiliaryHeating", true, "Start aux heat"),
            new Candidate(ConfirmationPolicy.STOP_AUX_HEATING, "stopAuxiliaryHeating", true, "Stop aux heat"),
            new Candidate(ConfirmationPolicy.START_CHARGING, "startCharging", false, "Start charging"),
            new Candidate(ConfirmationPolicy.STOP_CHARGING, "stopCharging", false, "Stop charging")
        ] as Array<Candidate>;
    }

    // US-014's "operations absent means treat everything as possibly
    // supported" applies here exactly as it does to VehicleState.Vehicle:
    // duplicated rather than reused because Cache.operations() returns a
    // bare Array<String>?, not a VehicleState.Vehicle. See VehicleState.mc's
    // own hasOperation() for the twin.
    function _hasOperation(operations as Array<String>?, name as String) as Boolean {
        if (operations == null) {
            return true;
        }
        for (var i = 0; i < operations.size(); i += 1) {
            if ((operations[i] as String).equals(name)) {
                return true;
            }
        }
        return false;
    }

    // US-036 ("actions absent from operations[] are not rendered") and
    // US-021 ("hidden entirely when no S-PIN is set") in one pass. Never
    // hides "stop" based on state/staleness: this function never looks at
    // state at all, only capability, see the hard constraint in
    // docs/requirements.md US-036 and preferredClimateAction() below for
    // where staleness IS considered.
    function visibleCandidates(operations as Array<String>?, hasSpin as Boolean) as Array<Candidate> {
        var all = _candidates();
        var visible = [] as Array<Candidate>;
        for (var i = 0; i < all.size(); i += 1) {
            var candidate = all[i] as Candidate;
            if (candidate.requiresSpin && !hasSpin) {
                continue;
            }
            if (!_hasOperation(operations, candidate.operation)) {
                continue;
            }
            visible.add(candidate);
        }
        return visible;
    }

    // US-037's default ("toggling the climate") resolved from the cache:
    // only a FRESH, explicitly-running reading flips the preselection to
    // Stop: anything else (off, unknown, absent, or older than an hour,
    // matching the status pages' own staleness threshold) prefers Start.
    // This never hides Stop (visibleCandidates() always offers both together
    // when climate is supported at all): it only decides which one gets the
    // focus by default.
    function preferredClimateAction(state as String?, ageSeconds as Number?) as Symbol {
        if (state == null || ageSeconds == null) {
            return ConfirmationPolicy.START_CLIMATE;
        }
        if (ageSeconds > 3600) {
            return ConfirmationPolicy.START_CLIMATE;
        }
        return isClimateRunning(state) ? ConfirmationPolicy.STOP_CLIMATE : ConfirmationPolicy.START_CLIMATE;
    }

    // The airConditioning states that mean something is running in the car.
    // Shared with CommandCheck, so "climate on" means the same thing when
    // home picks a row and when a command is checked.
    function isClimateRunning(state as String?) as Boolean {
        if (state == null) {
            return false;
        }
        return state.equals("HEATING") || state.equals("COOLING")
            || state.equals("VENTILATION") || state.equals("HEATING_AUXILIARY");
    }

    // US-037: "falls through to the next supported tile when the vehicle
    // does not support it". `preferredClimate` names which climate
    // direction the caller would like as primary; if climate isn't
    // supported at all (neither direction is in `visible`), this falls
    // through to the first candidate that IS visible, in fixed order. Null
    // only when the vehicle supports none of this screen's actions.
    function primaryAction(visible as Array<Candidate>, preferredClimate as Symbol) as Symbol? {
        if (visible.size() == 0) {
            return null;
        }
        for (var i = 0; i < visible.size(); i += 1) {
            var candidate = visible[i] as Candidate;
            if (candidate.actionId == preferredClimate) {
                return candidate.actionId;
            }
        }
        return (visible[0] as Candidate).actionId;
    }

    // Puts the primary action first within its group, keeping every other
    // candidate in the fixed order. With the default TileOrder the primary
    // is then the first row, so the hero stays fully visible at launch.
    function orderedForDisplay(visible as Array<Candidate>, primary as Symbol?) as Array<Candidate> {
        if (primary == null) {
            return visible;
        }
        var ordered = [] as Array<Candidate>;
        for (var i = 0; i < visible.size(); i += 1) {
            var candidate = visible[i] as Candidate;
            if (candidate.actionId == primary) {
                ordered.add(candidate);
            }
        }
        for (var i = 0; i < visible.size(); i += 1) {
            var candidate = visible[i] as Candidate;
            if (candidate.actionId != primary) {
                ordered.add(candidate);
            }
        }
        return ordered;
    }

    // One home row: an action id (command or navigation), its label and an
    // optional icon. Commands carry no icon (PoC NH.TILES), the navigation
    // rows do (PoC NH.ICON), which is also how they read apart at a glance.
    class TileDescriptor {
        public var actionId as Symbol;
        public var label as String;
        public var icon as Symbol?;

        function initialize(action as Symbol, tileLabel as String, tileIcon as Symbol?) {
            actionId = action;
            label = tileLabel;
            icon = tileIcon;
        }
    }

    // Charging detail is offered when there is something to show or nothing
    // is known yet (first launch, operations unknown): the detail screen
    // itself shows "no charging data yet" in the second case (US-023).
    function hasChargingDetail(operations as Array<String>?, hasChargingSection as Boolean) as Boolean {
        return hasChargingSection || operations == null;
    }

    // What both the home and the tile-order screen treat as supported, so the
    // ordering screen offers exactly what home shows, never less (US-061).
    function supportedCategories(visible as Array<Candidate>, chargingDetail as Boolean, findMyCar as Boolean) as Array<Symbol> {
        var hasClimate = false;
        var hasCharging = false;
        for (var i = 0; i < visible.size(); i += 1) {
            if (TileOrder.isChargingOperation((visible[i] as Candidate).operation)) {
                hasCharging = true;
            } else {
                hasClimate = true;
            }
        }
        return TileOrder.supportedCategories(hasClimate, hasCharging, chargingDetail, findMyCar);
    }

    // Every home row in final display order: the user's TileOrder category
    // order (US-061, never by usage), the primary first within its group
    // (US-037), gated by operations[], the S-PIN and the two navigation
    // flags. `findMyCar` is !ParkingFeature.isKnownUnsupported() (US-028).
    function rows(operations as Array<String>?, hasSpin as Boolean, preferredClimate as Symbol,
                  chargingDetail as Boolean, findMyCar as Boolean) as Array<TileDescriptor> {
        var visible = visibleCandidates(operations, hasSpin);
        var ordered = orderedForDisplay(visible, primaryAction(visible, preferredClimate));
        var categories = TileOrder.visible(supportedCategories(visible, chargingDetail, findMyCar));
        var result = [] as Array<TileDescriptor>;
        for (var c = 0; c < categories.size(); c += 1) {
            var category = categories[c] as Symbol;
            if (category == TileOrder.CATEGORY_CLIMATE || category == TileOrder.CATEGORY_CHARGING) {
                var charging = category == TileOrder.CATEGORY_CHARGING;
                for (var i = 0; i < ordered.size(); i += 1) {
                    var candidate = ordered[i] as Candidate;
                    if (TileOrder.isChargingOperation(candidate.operation) == charging) {
                        result.add(new TileDescriptor(candidate.actionId, candidate.label, null));
                    }
                }
            } else if (category == TileOrder.CATEGORY_CHARGING_DETAIL) {
                result.add(new TileDescriptor(OPEN_CHARGING, "Charging", :bolt));
            } else if (category == TileOrder.CATEGORY_FIND_MY_CAR) {
                result.add(new TileDescriptor(FIND_MY_CAR, "Find my car", :pin));
            } else if (category == TileOrder.CATEGORY_STATUS_DETAIL) {
                result.add(new TileDescriptor(OPEN_STATUS, "Status", :list));
            } else if (category == TileOrder.CATEGORY_SETTINGS) {
                result.add(new TileDescriptor(OPEN_TILE_ORDER, "Settings", :gear));
            }
        }
        return result;
    }

    // Row index of `action`, or 0 when it is absent (no primary, or the user
    // hid its category): focus then starts on the first row.
    function indexOf(list as Array<TileDescriptor>, action as Symbol?) as Number {
        if (action == null) {
            return 0;
        }
        for (var i = 0; i < list.size(); i += 1) {
            if ((list[i] as TileDescriptor).actionId == action) {
                return i;
            }
        }
        return 0;
    }

    // A11: the home keeps its rows (and so its focus) on return unless this
    // changed. Ids alone are enough: a label never changes without its id.
    function signature(list as Array<TileDescriptor>) as String {
        var s = "";
        for (var i = 0; i < list.size(); i += 1) {
            s += (list[i] as TileDescriptor).actionId.toString() + ";";
        }
        return s;
    }

}
