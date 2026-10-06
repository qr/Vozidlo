import Toybox.Lang;
import Toybox.Test;

// Unit tests for ui/ControlsView.mc's ControlTiles module (US-036, US-037):
// tile filtering from operations[], the S-PIN gate, the hard constraint that
// climate's stop action is never hidden, and the primary-action fallback
// when the vehicle does not support climate at all.
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

    // The primary tile must be first in display order: ControlsView relies
    // on this to preselect it via the framework's own "first Selectable in
    // setLayout() starts highlighted" behaviour (US-037).
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

    // ------------------------------------------------------------------
    // REGRESSION FIX (task 11, US-036): "at most seven tiles are shown;
    // anything beyond that moves into a secondary menu." Tasks 7, 8, 9 and
    // 10 each added tiles independently: climate (2) + ventilation (2) +
    // aux heat (2) + charging (2) + find my car (1) + status (1) +
    // settings (1) is eleven when a vehicle supports everything and the
    // user has an S-PIN set, and nothing capped the total until now. These
    // tests exercise ControlTiles.capped()/overflow() directly, exactly the
    // "whatever the vehicle supports" the task asks for: they never
    // construct a live ControlsView, only the plain descriptor list its
    // _buildTiles() now builds before capping.

    function _descriptors(count as Number) as Array<ControlTiles.TileDescriptor> {
        var list = [] as Array<ControlTiles.TileDescriptor>;
        for (var i = 0; i < count; i += 1) {
            list.add(new ControlTiles.TileDescriptor(:action, "Tile " + i.toString()));
        }
        return list;
    }

    (:test)
    function cappedNeverExceedsSevenWhateverTheVehicleSupports(logger as Logger) as Boolean {
        // 0 through 11 covers every count this screen could ever build
        // (five categories, climate contributing up to six tiles on its
        // own) plus a margin either side.
        for (var count = 0; count <= 11; count += 1) {
            var all = _descriptors(count);
            var visible = ControlTiles.capped(all, :moreActions, "More");
            if (visible.size() > ControlTiles.MAX_VISIBLE_TILES) {
                logger.error("capped() returned " + visible.size().toString() + " tiles for " + count.toString() + " candidates: must never exceed " + ControlTiles.MAX_VISIBLE_TILES.toString());
                return false;
            }
        }
        return true;
    }

    (:test)
    function cappedLeavesAShortListUntouched(logger as Logger) as Boolean {
        var all = _descriptors(5);
        var visible = ControlTiles.capped(all, :moreActions, "More");
        if (visible.size() != 5) {
            logger.error("a list already within the cap must come back unchanged");
            return false;
        }
        if (ControlTiles.overflow(all).size() != 0) {
            logger.error("a list already within the cap must have no overflow");
            return false;
        }
        return true;
    }

    (:test)
    function cappedAtExactlySevenAddsNoMoreTile(logger as Logger) as Boolean {
        var all = _descriptors(7);
        var visible = ControlTiles.capped(all, :moreActions, "More");
        if (visible.size() != 7) {
            logger.error("exactly seven candidates must show all seven, no More tile");
            return false;
        }
        for (var i = 0; i < visible.size(); i += 1) {
            if ((visible[i] as ControlTiles.TileDescriptor).actionId == :moreActions) {
                logger.error("a More tile must never appear when everything already fits");
                return false;
            }
        }
        return true;
    }

    (:test)
    function cappedAddsAMoreTileAndOverflowCarriesEverythingElse(logger as Logger) as Boolean {
        var all = _descriptors(11);
        var visible = ControlTiles.capped(all, :moreActions, "More");
        if (visible.size() != 7) {
            logger.error("eleven candidates must cap at exactly seven visible tiles");
            return false;
        }
        var last = visible[6] as ControlTiles.TileDescriptor;
        if (last.actionId != :moreActions || !last.label.equals("More")) {
            logger.error("the 7th slot must be the More tile");
            return false;
        }
        // US-036's regression-fix brief: "do not silently drop
        // functionality: everything must remain reachable."
        var overflow = ControlTiles.overflow(all);
        if (overflow.size() != 5) {
            logger.error("expected the remaining 5 candidates (11 - 6 direct tiles) in overflow, got " + overflow.size().toString());
            return false;
        }
        if ((6 + overflow.size()) != all.size()) {
            logger.error("every candidate must be accounted for between the 6 direct tiles and overflow");
            return false;
        }
        return true;
    }

    // The user's own TileOrder ordering (and, within climate, US-037's
    // primary-first rule) is what decides "most used" here: capped() must
    // never reorder, only truncate.
    (:test)
    function cappedPreservesOriginalOrderForTheTilesItKeeps(logger as Logger) as Boolean {
        var all = _descriptors(9);
        var visible = ControlTiles.capped(all, :moreActions, "More");
        for (var i = 0; i < 6; i += 1) {
            if ((visible[i] as ControlTiles.TileDescriptor).label != (all[i] as ControlTiles.TileDescriptor).label) {
                logger.error("capped() must keep the first six candidates in their original order");
                return false;
            }
        }
        return true;
    }

    (:test)
    function overflowPreservesOrderToo(logger as Logger) as Boolean {
        var all = _descriptors(9);
        var overflow = ControlTiles.overflow(all);
        for (var i = 0; i < overflow.size(); i += 1) {
            if ((overflow[i] as ControlTiles.TileDescriptor).label != (all[6 + i] as ControlTiles.TileDescriptor).label) {
                logger.error("overflow() must preserve the original order of whatever didn't fit");
                return false;
            }
        }
        return true;
    }

}
