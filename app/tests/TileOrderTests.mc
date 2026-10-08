import Toybox.Lang;
import Toybox.Test;

// Unit tests for ui/TileOrder.mc (US-061): default order, persistence
// round-trips, move/hide, the charging-detail migration, and the two derived
// views (visible() for the home rows, orderableCategories() for what
// TileOrderView lists).
// TileOrder.clear() opens every test that touches Storage, matching this
// project's existing convention (see tests/QuotaTests.mc's own comment on
// the same pattern).
module TileOrderTests {

    (:test)
    function defaultOrderMatchesTheStory(logger as Logger) as Boolean {
        TileOrder.clear();
        var order = TileOrder.order();
        var expected = [
            TileOrder.CATEGORY_CLIMATE, TileOrder.CATEGORY_CHARGING, TileOrder.CATEGORY_CHARGING_DETAIL,
            TileOrder.CATEGORY_FIND_MY_CAR, TileOrder.CATEGORY_STATUS_DETAIL, TileOrder.CATEGORY_SETTINGS
        ] as Array<Symbol>;
        if (order.size() != expected.size()) {
            logger.error("expected all six categories with nothing persisted yet");
            return false;
        }
        for (var i = 0; i < expected.size(); i += 1) {
            if (order[i] != expected[i]) {
                logger.error("default order must be climate, charging, charging detail, find my car, status detail, settings");
                return false;
            }
        }
        return true;
    }

    (:test)
    function setOrderPersistsAndSurvivesAReload(logger as Logger) as Boolean {
        TileOrder.clear();
        var newOrder = [
            TileOrder.CATEGORY_SETTINGS, TileOrder.CATEGORY_CLIMATE, TileOrder.CATEGORY_CHARGING,
            TileOrder.CATEGORY_CHARGING_DETAIL, TileOrder.CATEGORY_FIND_MY_CAR, TileOrder.CATEGORY_STATUS_DETAIL
        ] as Array<Symbol>;
        TileOrder.setOrder(newOrder);

        // TileOrder never caches in a module variable (same convention
        // Quota.mc documents for itself): order() re-reads Storage fresh
        // every call, so calling it again here IS the "survives a reload"
        // check, no simulated restart needed.
        var reloaded = TileOrder.order();
        for (var i = 0; i < newOrder.size(); i += 1) {
            if (reloaded[i] != newOrder[i]) {
                logger.error("persisted order did not round-trip through Storage");
                return false;
            }
        }
        return true;
    }

    (:test)
    function moveUpAndMoveDownSwapNeighboursAndClampAtTheEnds(logger as Logger) as Boolean {
        TileOrder.clear();
        // Default: climate, charging, chargingDetail, findMyCar, statusDetail, settings.
        TileOrder.moveUp(TileOrder.CATEGORY_CLIMATE); // already first: no-op
        var order = TileOrder.order();
        if (order[0] != TileOrder.CATEGORY_CLIMATE) {
            logger.error("moving the first entry up must be a no-op");
            return false;
        }

        TileOrder.moveDown(TileOrder.CATEGORY_CLIMATE);
        order = TileOrder.order();
        if (order[0] != TileOrder.CATEGORY_CHARGING || order[1] != TileOrder.CATEGORY_CLIMATE) {
            logger.error("moving climate down once must swap it with charging");
            return false;
        }

        TileOrder.moveDown(TileOrder.CATEGORY_SETTINGS); // already last: no-op
        order = TileOrder.order();
        if (order[order.size() - 1] != TileOrder.CATEGORY_SETTINGS) {
            logger.error("moving the last entry down must be a no-op");
            return false;
        }
        return true;
    }

    (:test)
    function toggleHiddenHidesAndShowsAgain(logger as Logger) as Boolean {
        TileOrder.clear();
        if (TileOrder.isHidden(TileOrder.CATEGORY_CHARGING)) {
            logger.error("nothing is hidden until toggled");
            return false;
        }
        TileOrder.toggleHidden(TileOrder.CATEGORY_CHARGING);
        if (!TileOrder.isHidden(TileOrder.CATEGORY_CHARGING)) {
            logger.error("expected charging to be hidden after one toggle");
            return false;
        }
        TileOrder.toggleHidden(TileOrder.CATEGORY_CHARGING);
        if (TileOrder.isHidden(TileOrder.CATEGORY_CHARGING)) {
            logger.error("expected charging to be shown again after a second toggle");
            return false;
        }
        return true;
    }

    // Settings is the way into tile order: hiding it would lock the user
    // out, so it cannot be hidden, and a hidden Settings saved before this
    // rule is ignored.
    (:test)
    function settingsCannotBeHidden(logger as Logger) as Boolean {
        TileOrder.clear();
        if (TileOrder.isHideable(TileOrder.CATEGORY_SETTINGS) || !TileOrder.isHideable(TileOrder.CATEGORY_CLIMATE)) {
            logger.error("only Settings is not hideable");
            return false;
        }
        TileOrder.toggleHidden(TileOrder.CATEGORY_SETTINGS);
        if (TileOrder.isHidden(TileOrder.CATEGORY_SETTINGS)) {
            logger.error("toggleHidden must not hide Settings");
            return false;
        }
        TileOrder.setHidden([TileOrder.CATEGORY_SETTINGS, TileOrder.CATEGORY_CLIMATE] as Array<Symbol>);
        if (TileOrder.isHidden(TileOrder.CATEGORY_SETTINGS) || !TileOrder.isHidden(TileOrder.CATEGORY_CLIMATE)) {
            logger.error("a stored hidden Settings must be ignored, climate kept hidden");
            return false;
        }
        var visible = TileOrder.visible([TileOrder.CATEGORY_CLIMATE, TileOrder.CATEGORY_SETTINGS] as Array<Symbol>);
        if (visible.size() != 1 || visible[0] != TileOrder.CATEGORY_SETTINGS) {
            logger.error("home must still show Settings");
            return false;
        }
        TileOrder.clear();
        return true;
    }

    // What the home list shows: supported AND not hidden.
    (:test)
    function visibleFiltersByBothSupportedAndHidden(logger as Logger) as Boolean {
        TileOrder.clear();
        TileOrder.toggleHidden(TileOrder.CATEGORY_CHARGING);
        var supported = [
            TileOrder.CATEGORY_CLIMATE, TileOrder.CATEGORY_CHARGING, TileOrder.CATEGORY_STATUS_DETAIL, TileOrder.CATEGORY_SETTINGS
        ] as Array<Symbol>; // findMyCar not supported on this vehicle build

        var visible = TileOrder.visible(supported);
        for (var i = 0; i < visible.size(); i += 1) {
            var category = visible[i] as Symbol;
            if (category == TileOrder.CATEGORY_FIND_MY_CAR) {
                logger.error("an unsupported category must never appear in visible()");
                return false;
            }
            if (category == TileOrder.CATEGORY_CHARGING) {
                logger.error("a hidden category must never appear in visible()");
                return false;
            }
        }
        if (visible.size() != 3) {
            logger.error("expected exactly climate, status detail and settings, got " + visible.size().toString());
            return false;
        }
        return true;
    }

    // What TileOrderView lists: supported categories only. A HIDDEN one
    // must still appear here, or the user could never unhide it (US-061:
    // "tiles for unsupported actions never appear, in the ordering screen
    // either" says nothing about hidden ones).
    (:test)
    function orderableCategoriesExcludesUnsupportedButKeepsHidden(logger as Logger) as Boolean {
        TileOrder.clear();
        TileOrder.toggleHidden(TileOrder.CATEGORY_CHARGING);
        var supported = [
            TileOrder.CATEGORY_CLIMATE, TileOrder.CATEGORY_CHARGING, TileOrder.CATEGORY_STATUS_DETAIL, TileOrder.CATEGORY_SETTINGS
        ] as Array<Symbol>;

        var orderable = TileOrder.orderableCategories(supported);
        var hasCharging = false;
        var hasFindMyCar = false;
        for (var i = 0; i < orderable.size(); i += 1) {
            var category = orderable[i] as Symbol;
            if (category == TileOrder.CATEGORY_CHARGING) {
                hasCharging = true;
            }
            if (category == TileOrder.CATEGORY_FIND_MY_CAR) {
                hasFindMyCar = true;
            }
        }
        if (!hasCharging) {
            logger.error("a HIDDEN but supported category must still appear so it can be un-hidden");
            return false;
        }
        if (hasFindMyCar) {
            logger.error("an unsupported category must never appear in the ordering screen either");
            return false;
        }
        return true;
    }

    (:test)
    function supportedCategoriesAlwaysOffersStatusAndSettings(logger as Logger) as Boolean {
        var supported = TileOrder.supportedCategories(false, false, false, false);
        if (supported.size() != 2) {
            logger.error("with nothing else supported, only status detail and settings must remain");
            return false;
        }
        return true;
    }

    (:test)
    function isChargingOperationRecognisesOnlyTheChargingCommands(logger as Logger) as Boolean {
        if (!TileOrder.isChargingOperation("startCharging")) {
            logger.error("startCharging must classify as charging");
            return false;
        }
        if (!TileOrder.isChargingOperation("stopCharging")) {
            logger.error("stopCharging must classify as charging");
            return false;
        }
        if (TileOrder.isChargingOperation("startAirConditioning")) {
            logger.error("a climate operation must never classify as charging");
            return false;
        }
        return true;
    }

    // US-061 / the task's hard constraint: nothing in this module ever
    // consults a usage count: order() only ever returns what setOrder()
    // (a direct user action) put there, or the fixed default.
    (:test)
    function orderNeverChangesOnItsOwn(logger as Logger) as Boolean {
        TileOrder.clear();
        var first = TileOrder.order();
        // Reading state repeatedly (as the home does on every onShow())
        // must never itself mutate the persisted order.
        TileOrder.order();
        TileOrder.order();
        var again = TileOrder.order();
        for (var i = 0; i < first.size(); i += 1) {
            if (first[i] != again[i]) {
                logger.error("repeated reads must never change the order by themselves");
                return false;
            }
        }
        return true;
    }

    // An order saved before charging detail existed (five names) gets it
    // right after charging, not at the end; the stored value itself is left
    // alone until the user changes the order (storage keys unchanged).
    (:test)
    function storedOrderWithoutChargingDetailGetsItAfterCharging(logger as Logger) as Boolean {
        TileOrder.clear();
        TileOrder.setOrder([
            TileOrder.CATEGORY_SETTINGS, TileOrder.CATEGORY_CHARGING, TileOrder.CATEGORY_CLIMATE,
            TileOrder.CATEGORY_FIND_MY_CAR, TileOrder.CATEGORY_STATUS_DETAIL
        ] as Array<Symbol>);
        var order = TileOrder.order();
        var expected = [
            TileOrder.CATEGORY_SETTINGS, TileOrder.CATEGORY_CHARGING, TileOrder.CATEGORY_CHARGING_DETAIL,
            TileOrder.CATEGORY_CLIMATE, TileOrder.CATEGORY_FIND_MY_CAR, TileOrder.CATEGORY_STATUS_DETAIL
        ] as Array<Symbol>;
        TileOrder.clear();
        if (order.size() != expected.size()) {
            logger.error("expected six categories after the migration, got " + order.size().toString());
            return false;
        }
        for (var i = 0; i < expected.size(); i += 1) {
            if (order[i] != expected[i]) {
                logger.error("charging detail must land right after charging, mismatch at " + i.toString());
                return false;
            }
        }
        return true;
    }

    // A stored order that already lists charging detail keeps it where the
    // user put it: the migration only fills a gap.
    (:test)
    function storedChargingDetailPositionIsKept(logger as Logger) as Boolean {
        TileOrder.clear();
        TileOrder.setOrder([
            TileOrder.CATEGORY_CHARGING_DETAIL, TileOrder.CATEGORY_CLIMATE, TileOrder.CATEGORY_CHARGING
        ] as Array<Symbol>);
        var order = TileOrder.order();
        TileOrder.clear();
        if (order[0] != TileOrder.CATEGORY_CHARGING_DETAIL || order[2] != TileOrder.CATEGORY_CHARGING
            || order[3] != TileOrder.CATEGORY_FIND_MY_CAR) {
            logger.error("a stored charging detail position must be kept, the rest appended");
            return false;
        }
        return true;
    }

    // The detail row and the command pair carry different labels, so the
    // ordering screen never lists "Charging" twice.
    (:test)
    function chargingCategoriesHaveDistinctLabels(logger as Logger) as Boolean {
        var commands = TileOrder.label(TileOrder.CATEGORY_CHARGING);
        var detail = TileOrder.label(TileOrder.CATEGORY_CHARGING_DETAIL);
        if (commands.equals(detail) || !detail.equals("Charging")) {
            logger.error("expected a short command label and Charging for the detail, got " + commands + " / " + detail);
            return false;
        }
        var supported = TileOrder.supportedCategories(true, true, true, true);
        if (supported.size() != 6 || supported[2] != TileOrder.CATEGORY_CHARGING_DETAIL) {
            logger.error("supportedCategories must include charging detail after charging when flagged");
            return false;
        }
        return true;
    }

}
