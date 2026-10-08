import Toybox.Lang;
import Toybox.Test;

// Unit tests for ui/ControlTiles.mc (US-036, US-037, US-061): row filtering
// from operations[], the S-PIN gate, the hard constraint that climate's stop
// action is never hidden, the primary-action fallback when the vehicle does
// not support climate at all, and the home rows in TileOrder order.
module ControlTilesTests {

    (:test)
    function tilesFilteredByOperations(logger as Logger) as Boolean {
        var ops = ["startAirConditioning", "stopAirConditioning"] as Array<String>;
        var visible = ControlTiles.visibleCandidates(ops, false);
        if (visible.size() != 2) {
            logger.error("expected exactly the two climate tiles, got " + visible.size().toString());
            return false;
        }
        return true;
    }

    // US-014's convention, reused here: operations == null means "assume
    // everything is possibly supported", not "assume nothing is".
    (:test)
    function nullOperationsAssumesEverythingSupported(logger as Logger) as Boolean {
        var visible = ControlTiles.visibleCandidates(null, false);
        // climate (2) + ventilation (2) + charging (2, task 8); aux heating
        // (2) stays excluded: no S-PIN, regardless of what operations[]
        // would have said.
        if (visible.size() != 6) {
            logger.error("expected 6 tiles with operations unknown and no S-PIN, got " + visible.size().toString());
            return false;
        }
        return true;
    }

    // US-021: "hidden entirely when no S-PIN is configured". Even when the
    // vehicle explicitly lists the operation.
    (:test)
    function auxHeatingHiddenWithoutSpinEvenWhenOperationsListsIt(logger as Logger) as Boolean {
        var ops = ["startAuxiliaryHeating", "stopAuxiliaryHeating"] as Array<String>;

        var withoutSpin = ControlTiles.visibleCandidates(ops, false);
        if (withoutSpin.size() != 0) {
            logger.error("aux heating must be hidden entirely without an S-PIN");
            return false;
        }

        var withSpin = ControlTiles.visibleCandidates(ops, true);
        if (withSpin.size() != 2) {
            logger.error("aux heating must appear once an S-PIN is configured and the operation is listed");
            return false;
        }
        return true;
    }

    (:test)
    function unlistedOperationHidesItsTile(logger as Logger) as Boolean {
        var ops = ["startAirConditioning", "stopAirConditioning"] as Array<String>;
        var visible = ControlTiles.visibleCandidates(ops, true);
        for (var i = 0; i < visible.size(); i += 1) {
            var candidate = visible[i] as ControlTiles.Candidate;
            if (candidate.actionId == ConfirmationPolicy.START_VENTILATION || candidate.actionId == ConfirmationPolicy.STOP_VENTILATION) {
                logger.error("ventilation tiles must not appear when the operation isn't listed");
                return false;
            }
        }
        return true;
    }

    // The task's hard constraint: cached state must never be the reason
    // "stop" is missing: visibleCandidates() doesn't even look at state,
    // only at operations[], so both directions always travel together.
    (:test)
    function bothClimateDirectionsAlwaysOfferedTogether(logger as Logger) as Boolean {
        var ops = ["startAirConditioning", "stopAirConditioning"] as Array<String>;
        var visible = ControlTiles.visibleCandidates(ops, false);

        var hasStart = false;
        var hasStop = false;
        for (var i = 0; i < visible.size(); i += 1) {
            var candidate = visible[i] as ControlTiles.Candidate;
            if (candidate.actionId == ConfirmationPolicy.START_CLIMATE) {
                hasStart = true;
            }
            if (candidate.actionId == ConfirmationPolicy.STOP_CLIMATE) {
                hasStop = true;
            }
        }
        if (!hasStart || !hasStop) {
            logger.error("both Start and Stop climate tiles must be present whenever climate is supported");
            return false;
        }
        return true;
    }

    // US-037: "falls through to the next supported tile when the vehicle
    // does not support it": here, climate is entirely unsupported.
    (:test)
    function primaryFallsThroughWhenClimateUnsupported(logger as Logger) as Boolean {
        var ops = ["startActiveVentilation", "stopActiveVentilation"] as Array<String>;
        var visible = ControlTiles.visibleCandidates(ops, false);
        var primary = ControlTiles.primaryAction(visible, ConfirmationPolicy.START_CLIMATE);
        if (primary != ConfirmationPolicy.START_VENTILATION) {
            logger.error("expected fallback to the first supported tile (start ventilation)");
            return false;
        }
        return true;
    }

    (:test)
    function primaryIsNullWhenNothingIsSupported(logger as Logger) as Boolean {
        var ops = [] as Array<String>;
        var visible = ControlTiles.visibleCandidates(ops, false);
        var primary = ControlTiles.primaryAction(visible, ConfirmationPolicy.START_CLIMATE);
        if (primary != null) {
            logger.error("expected no primary action when the vehicle supports none of this screen's actions");
            return false;
        }
        return true;
    }

    (:test)
    function primaryUsesThePreferredClimateDirectionWhenSupported(logger as Logger) as Boolean {
        var ops = ["startAirConditioning", "stopAirConditioning"] as Array<String>;
        var visible = ControlTiles.visibleCandidates(ops, false);
        var primary = ControlTiles.primaryAction(visible, ConfirmationPolicy.STOP_CLIMATE);
        if (primary != ConfirmationPolicy.STOP_CLIMATE) {
            logger.error("expected the preferred climate direction to win when it is actually supported");
            return false;
        }
        return true;
    }

    // US-037's default: "toggling the climate" resolved from cached state.
    // never trusting a stale or missing reading as "currently running".
    (:test)
    function preferredClimateActionDefaultsToStartWhenUnknownOrStale(logger as Logger) as Boolean {
        if (ControlTiles.preferredClimateAction(null, null) != ConfirmationPolicy.START_CLIMATE) {
            logger.error("no cached state at all must default to Start");
            return false;
        }
        if (ControlTiles.preferredClimateAction("HEATING", 3700) != ConfirmationPolicy.START_CLIMATE) {
            logger.error("a HEATING reading older than an hour must default to Start, not Stop");
            return false;
        }
        if (ControlTiles.preferredClimateAction("OFF", 60) != ConfirmationPolicy.START_CLIMATE) {
            logger.error("a fresh OFF reading must default to Start");
            return false;
        }
        return true;
    }

    (:test)
    function preferredClimateActionPrefersStopWhenFreshAndRunning(logger as Logger) as Boolean {
        if (ControlTiles.preferredClimateAction("HEATING", 60) != ConfirmationPolicy.STOP_CLIMATE) {
            logger.error("a fresh HEATING reading must default to Stop");
            return false;
        }
        if (ControlTiles.preferredClimateAction("VENTILATION", 60) != ConfirmationPolicy.STOP_CLIMATE) {
            logger.error("a fresh VENTILATION reading must default to Stop");
            return false;
        }
        return true;
    }

    // The primary action comes first within its group (US-037), so with the
    // default order it is the first row and the hero stays in view.
    (:test)
    function orderedForDisplayPutsPrimaryFirst(logger as Logger) as Boolean {
        var ops = ["startAirConditioning", "stopAirConditioning"] as Array<String>;
        var visible = ControlTiles.visibleCandidates(ops, false);
        var ordered = ControlTiles.orderedForDisplay(visible, ConfirmationPolicy.STOP_CLIMATE);
        if (ordered.size() != 2) {
            logger.error("expected both tiles preserved in the ordered list");
            return false;
        }
        if ((ordered[0] as ControlTiles.Candidate).actionId != ConfirmationPolicy.STOP_CLIMATE) {
            logger.error("expected the primary action first in display order");
            return false;
        }
        return true;
    }

    // ------------------------------------------------------------ rows

    function _labels(rows as Array<ControlTiles.TileDescriptor>) as String {
        var s = "";
        for (var i = 0; i < rows.size(); i += 1) {
            s += (i > 0 ? "|" : "") + (rows[i] as ControlTiles.TileDescriptor).label;
        }
        return s;
    }

    // PoC NH.TILES: the default order with the new Charging (detail) row
    // right after the charging commands; labels without "\n" (A14).
    (:test)
    function rowsFollowTheDefaultTileOrder(logger as Logger) as Boolean {
        TileOrder.clear();
        var ops = ["startAirConditioning", "stopAirConditioning", "startCharging", "stopCharging"] as Array<String>;
        var rows = ControlTiles.rows(ops, false, ConfirmationPolicy.START_CLIMATE, true, true);
        var got = _labels(rows);
        var want = "Start climate|Stop climate|Start charging|Stop charging|Charging|Find my car|Status|Settings";
        if (!got.equals(want)) {
            logger.error("expected " + want + ", got " + got);
            return false;
        }
        return true;
    }

    // Commands carry no icon; every navigation row does (PoC NH.ICON).
    (:test)
    function navigationRowsCarryIcons(logger as Logger) as Boolean {
        TileOrder.clear();
        var rows = ControlTiles.rows(null, false, ConfirmationPolicy.START_CLIMATE, true, true);
        for (var i = 0; i < rows.size(); i += 1) {
            var row = rows[i] as ControlTiles.TileDescriptor;
            var navigation = row.actionId == ControlTiles.OPEN_CHARGING || row.actionId == ControlTiles.FIND_MY_CAR
                || row.actionId == ControlTiles.OPEN_STATUS || row.actionId == ControlTiles.OPEN_TILE_ORDER;
            if (navigation != (row.icon != null)) {
                logger.error("icon mismatch on row " + row.label);
                return false;
            }
            if (row.label.find("\n") != null) {
                logger.error("row labels must be single-line: " + row.label);
                return false;
            }
        }
        return true;
    }

    // First launch (operations unknown): every action, ten rows (PoC
    // NH.TILES_UNKNOWN), with no cap and no More row.
    (:test)
    function rowsWithUnknownOperationsOfferEverything(logger as Logger) as Boolean {
        TileOrder.clear();
        var rows = ControlTiles.rows(null, false, ConfirmationPolicy.START_CLIMATE,
            ControlTiles.hasChargingDetail(null, false), true);
        if (rows.size() != 10) {
            logger.error("expected 10 rows on first launch, got " + rows.size().toString() + ": " + _labels(rows));
            return false;
        }
        return true;
    }

    // Hidden categories and unsupported navigation drop out; the user's own
    // order wins over the default (US-061).
    (:test)
    function rowsHonourHiddenAndUserOrder(logger as Logger) as Boolean {
        TileOrder.clear();
        TileOrder.setOrder([
            TileOrder.CATEGORY_SETTINGS, TileOrder.CATEGORY_CLIMATE, TileOrder.CATEGORY_CHARGING,
            TileOrder.CATEGORY_CHARGING_DETAIL, TileOrder.CATEGORY_FIND_MY_CAR, TileOrder.CATEGORY_STATUS_DETAIL
        ] as Array<Symbol>);
        TileOrder.toggleHidden(TileOrder.CATEGORY_CHARGING);
        var ops = ["startAirConditioning", "stopAirConditioning", "startCharging", "stopCharging"] as Array<String>;
        var rows = ControlTiles.rows(ops, false, ConfirmationPolicy.STOP_CLIMATE, false, false);
        var got = _labels(rows);
        TileOrder.clear();
        var want = "Settings|Stop climate|Start climate|Status";
        if (!got.equals(want)) {
            logger.error("expected " + want + ", got " + got);
            return false;
        }
        return true;
    }

    // US-037: focus at launch is the primary action's row, wherever the
    // user's order put it; 0 when there is none.
    (:test)
    function indexOfFindsThePrimaryRow(logger as Logger) as Boolean {
        TileOrder.clear();
        TileOrder.setOrder([
            TileOrder.CATEGORY_CHARGING, TileOrder.CATEGORY_CLIMATE
        ] as Array<Symbol>);
        var ops = ["startAirConditioning", "stopAirConditioning", "startCharging", "stopCharging"] as Array<String>;
        var rows = ControlTiles.rows(ops, false, ConfirmationPolicy.START_CLIMATE, true, true);
        var visible = ControlTiles.visibleCandidates(ops, false);
        var index = ControlTiles.indexOf(rows, ControlTiles.primaryAction(visible, ConfirmationPolicy.START_CLIMATE));
        TileOrder.clear();
        // charging (2) + charging detail first, so Start climate is row 3.
        if (index != 3) {
            logger.error("expected the primary row at index 3, got " + index.toString());
            return false;
        }
        if (ControlTiles.indexOf(rows, null) != 0) {
            logger.error("no primary action must focus the first row");
            return false;
        }
        return true;
    }

    // A11: the signature changes when the rows change and only then.
    (:test)
    function signatureTracksTheRows(logger as Logger) as Boolean {
        TileOrder.clear();
        var ops = ["startAirConditioning", "stopAirConditioning"] as Array<String>;
        var a = ControlTiles.signature(ControlTiles.rows(ops, false, ConfirmationPolicy.START_CLIMATE, true, true));
        var b = ControlTiles.signature(ControlTiles.rows(ops, false, ConfirmationPolicy.START_CLIMATE, true, true));
        var c = ControlTiles.signature(ControlTiles.rows(ops, false, ConfirmationPolicy.START_CLIMATE, false, true));
        var d = ControlTiles.signature(ControlTiles.rows(ops, false, ConfirmationPolicy.STOP_CLIMATE, true, true));
        if (!a.equals(b)) {
            logger.error("the same rows must give the same signature");
            return false;
        }
        if (a.equals(c) || a.equals(d)) {
            logger.error("a removed or reordered row must change the signature");
            return false;
        }
        return true;
    }

    // Charging detail: shown when a charging section is cached, or when
    // nothing is known yet; hidden once operations are known and no
    // charging data ever arrived.
    (:test)
    function chargingDetailNeedsDataOrUnknownOperations(logger as Logger) as Boolean {
        var ops = ["startAirConditioning"] as Array<String>;
        if (!ControlTiles.hasChargingDetail(null, false)) {
            logger.error("unknown operations must offer charging detail");
            return false;
        }
        if (!ControlTiles.hasChargingDetail(ops, true)) {
            logger.error("a cached charging section must offer charging detail");
            return false;
        }
        if (ControlTiles.hasChargingDetail(ops, false)) {
            logger.error("known operations without charging data must hide charging detail");
            return false;
        }
        return true;
    }

    // One definition of "climate running", shared with CommandCheck.
    (:test)
    function climateRunningCoversEveryActiveState(logger as Logger) as Boolean {
        var on = ["HEATING", "COOLING", "VENTILATION", "HEATING_AUXILIARY"] as Array<String>;
        for (var i = 0; i < on.size(); i += 1) {
            if (!ControlTiles.isClimateRunning(on[i])) {
                logger.error(on[i] + " must count as running");
                return false;
            }
        }
        if (ControlTiles.isClimateRunning("OFF") || ControlTiles.isClimateRunning(null) || ControlTiles.isClimateRunning("UNKNOWN")) {
            logger.error("OFF, null and UNKNOWN are not running");
            return false;
        }
        return true;
    }

}
