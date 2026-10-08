import Toybox.Application.Storage;
import Toybox.Lang;

// US-061 (task 10): the user's own order and visibility for the landing
// screen's top-level row categories: climate, charging, find my car,
// status detail, settings, the five named in the story, plus charging detail
// (Night Panel D1: the home list gives Charging detail its own row so it is
// reachable with buttons, ui-improvements.md A-list "Home grid"). This module
// NEVER reorders itself by usage (the story's own hard constraint, see
// docs/requirements.md, US-061: "Do not reorder tiles
// automatically by usage count").
//
// A pure ordering/persistence layer, with no dependency on Cache.mc,
// ControlTiles or any live vehicle state: every "is this supported"
// question is answered by the CALLER (ControlTiles.rows(), TileOrderView.mc)
// and passed in as plain booleans, so this module never needs to know
// what an operations[] name looks like and stays trivially testable in
// isolation (see tests/TileOrderTests.mc). This mirrors ui/ControlTiles.mc:
// a pure module deliberately kept separate from any live View.
//
// Persisted in Application.Storage rather than a Properties-backed
// <setting>: Settings are typed list/boolean/numeric/alphaNumeric/password
// (docs/best-practices, "Storage, Properties and Settings are three
// different things") and none of those model "an ordered subset of six
// symbols": this is exclusively an on-device preference with no natural
// phone-side UI, same reasoning as Cache.mc's own choice of Storage for
// vehicle state.
module TileOrder {

    const CATEGORY_CLIMATE = :climate;
    const CATEGORY_CHARGING = :charging;
    const CATEGORY_CHARGING_DETAIL = :chargingDetail;
    const CATEGORY_FIND_MY_CAR = :findMyCar;
    const CATEGORY_STATUS_DETAIL = :statusDetail;
    const CATEGORY_SETTINGS = :settings;

    const _ORDER_STORAGE_KEY = "tileOrder";
    const _HIDDEN_STORAGE_KEY = "tileOrderHidden";

    function defaultOrder() as Array<Symbol> {
        return [
            CATEGORY_CLIMATE, CATEGORY_CHARGING, CATEGORY_CHARGING_DETAIL,
            CATEGORY_FIND_MY_CAR, CATEGORY_STATUS_DETAIL, CATEGORY_SETTINGS
        ] as Array<Symbol>;
    }

    // charging tiles (task 8) share ControlTiles' own Candidate shape and
    // operations[] gate rather than being a separate concept in that
    // module: this is the one place that distinction is turned back into
    // a category boundary for ordering purposes. Pure and string-based
    // (never touches Cache/ControlTiles types).
    function isChargingOperation(operation as String) as Boolean {
        return operation.equals("startCharging") || operation.equals("stopCharging");
    }

    // US-061: "tiles for unsupported actions never appear, in the ordering
    // screen either": callers pass `hasFindMyCarTile` as
    // !ParkingFeature.isKnownUnsupported() (model/Parking.mc's persisted flag) and
    // `hasChargingDetail` as ControlTiles.hasChargingDetail() (a charging
    // section is cached, or operations are still unknown). Status detail
    // and settings are always offered: both are always-available
    // navigation, never gated on vehicle capability.
    function supportedCategories(hasClimateTile as Boolean, hasChargingTile as Boolean, hasChargingDetail as Boolean,
                                 hasFindMyCarTile as Boolean) as Array<Symbol> {
        var result = [] as Array<Symbol>;
        if (hasClimateTile) {
            result.add(CATEGORY_CLIMATE);
        }
        if (hasChargingTile) {
            result.add(CATEGORY_CHARGING);
        }
        if (hasChargingDetail) {
            result.add(CATEGORY_CHARGING_DETAIL);
        }
        if (hasFindMyCarTile) {
            result.add(CATEGORY_FIND_MY_CAR);
        }
        result.add(CATEGORY_STATUS_DETAIL);
        result.add(CATEGORY_SETTINGS);
        return result;
    }

    // The persisted order, falling back to defaultOrder() when nothing has
    // been saved yet. Never returns fewer than all six categories: a
    // category present in defaultOrder() but missing from what was stored
    // (corrupt data, or a category added by a later app version) is
    // appended in its default relative position rather than silently
    // dropped, so a caller never needs to null-check a category out of
    // this list. Charging detail is the one exception: orders saved before
    // it existed get it right after charging, where the default puts it,
    // instead of after settings at the very end of the home list.
    function order() as Array<Symbol> {
        var stored = Storage.getValue(_ORDER_STORAGE_KEY);
        var result = [] as Array<Symbol>;
        if (stored instanceof Array) {
            var names = stored as Array;
            for (var i = 0; i < names.size(); i += 1) {
                var category = _fromName(names[i] as Object?);
                if (category != null && !_contains(result, category)) {
                    result.add(category);
                }
            }
        }
        if (!_contains(result, CATEGORY_CHARGING_DETAIL)) {
            var migrated = [] as Array<Symbol>;
            for (var i = 0; i < result.size(); i += 1) {
                migrated.add(result[i] as Symbol);
                if (result[i] == CATEGORY_CHARGING) {
                    migrated.add(CATEGORY_CHARGING_DETAIL);
                }
            }
            result = migrated;
        }
        var defaults = defaultOrder();
        for (var i = 0; i < defaults.size(); i += 1) {
            var category = defaults[i] as Symbol;
            if (!_contains(result, category)) {
                result.add(category);
            }
        }
        return result;
    }

    function setOrder(newOrder as Array<Symbol>) as Void {
        var names = [] as Array<String>;
        for (var i = 0; i < newOrder.size(); i += 1) {
            names.add(_toName(newOrder[i] as Symbol));
        }
        Storage.setValue(_ORDER_STORAGE_KEY, names as Storage.ValueType);
    }

    // Settings is the only way into this ordering screen, so hiding it
    // would lock the user out of unhiding anything; HomeRows only brought
    // it back once every row was hidden.
    function isHideable(category as Symbol) as Boolean {
        return category != CATEGORY_SETTINGS;
    }

    // Named hiddenCategories(), not hidden(): `hidden` is a reserved word
    // in Monkey C (a member-visibility keyword), which the compiler rejects
    // as a function name. A stored hidden Settings (saved before
    // isHideable() existed) is ignored, which shows it again.
    function hiddenCategories() as Array<Symbol> {
        var stored = Storage.getValue(_HIDDEN_STORAGE_KEY);
        var result = [] as Array<Symbol>;
        if (stored instanceof Array) {
            var names = stored as Array;
            for (var i = 0; i < names.size(); i += 1) {
                var category = _fromName(names[i] as Object?);
                if (category != null && isHideable(category) && !_contains(result, category)) {
                    result.add(category);
                }
            }
        }
        return result;
    }

    function setHidden(hiddenList as Array<Symbol>) as Void {
        var names = [] as Array<String>;
        for (var i = 0; i < hiddenList.size(); i += 1) {
            names.add(_toName(hiddenList[i] as Symbol));
        }
        Storage.setValue(_HIDDEN_STORAGE_KEY, names as Storage.ValueType);
    }

    function isHidden(category as Symbol) as Boolean {
        return _contains(hiddenCategories(), category);
    }

    // Swaps `category` with its predecessor in the persisted order. A no-op
    // at the front, or for a category the caller passes that isn't in
    // order() at all (cannot happen given order() always returns all six,
    // but guarded rather than assumed).
    function moveUp(category as Symbol) as Void {
        var current = order();
        var index = _indexOf(current, category);
        if (index <= 0) {
            return;
        }
        _swap(current, index, index - 1);
        setOrder(current);
    }

    function moveDown(category as Symbol) as Void {
        var current = order();
        var index = _indexOf(current, category);
        if (index < 0 || index >= current.size() - 1) {
            return;
        }
        _swap(current, index, index + 1);
        setOrder(current);
    }

    // A no-op for a category that cannot be hidden (isHideable()).
    function toggleHidden(category as Symbol) as Void {
        if (!isHideable(category)) {
            return;
        }
        var current = hiddenCategories();
        if (_contains(current, category)) {
            var kept = [] as Array<Symbol>;
            for (var i = 0; i < current.size(); i += 1) {
                if (current[i] != category) {
                    kept.add(current[i] as Symbol);
                }
            }
            setHidden(kept);
        } else {
            current.add(category);
            setHidden(current);
        }
    }

    // What the home list actually shows: the user's order, restricted to
    // categories this build currently supports AND that the user has not
    // hidden.
    function visible(supported as Array<Symbol>) as Array<Symbol> {
        var result = [] as Array<Symbol>;
        var current = order();
        var hiddenSet = hiddenCategories();
        for (var i = 0; i < current.size(); i += 1) {
            var category = current[i] as Symbol;
            if (_contains(supported, category) && !_contains(hiddenSet, category)) {
                result.add(category);
            }
        }
        return result;
    }

    // What the ordering screen itself lists: the user's order, restricted
    // to SUPPORTED categories only: deliberately WITHOUT the hidden
    // filter visible() applies, because a category the user hid must still
    // appear here, or they could never unhide it (US-061: "tiles for
    // unsupported actions never appear, in the ordering screen either":
    // note this says nothing about hidden ones).
    function orderableCategories(supported as Array<Symbol>) as Array<Symbol> {
        var result = [] as Array<Symbol>;
        var current = order();
        for (var i = 0; i < current.size(); i += 1) {
            var category = current[i] as Symbol;
            if (_contains(supported, category)) {
                result.add(category);
            }
        }
        return result;
    }

    function label(category as Symbol) as String {
        if (category == CATEGORY_CLIMATE) {
            return "Climate";
        }
        // The start/stop commands. "Charging" now names the detail screen,
        // as on its home row, so the command pair gets a short label of its
        // own (fits the focus pill in FONT_MEDIUM on every target).
        if (category == CATEGORY_CHARGING) {
            return "Charge on/off";
        }
        if (category == CATEGORY_CHARGING_DETAIL) {
            return "Charging";
        }
        if (category == CATEGORY_FIND_MY_CAR) {
            return "Find my car";
        }
        if (category == CATEGORY_STATUS_DETAIL) {
            return "Status detail";
        }
        return "Settings";
    }

    // Test-only, and a legitimate building block if a future "reset tile
    // order" action is ever added: mirrors Cache.clear()/Quota.clear().
    function clear() as Void {
        Storage.deleteValue(_ORDER_STORAGE_KEY);
        Storage.deleteValue(_HIDDEN_STORAGE_KEY);
    }

    // ------------------------------------------------------------ helpers

    function _indexOf(list as Array<Symbol>, value as Symbol) as Number {
        for (var i = 0; i < list.size(); i += 1) {
            if (list[i] == value) {
                return i;
            }
        }
        return -1;
    }

    function _contains(list as Array<Symbol>, value as Symbol) as Boolean {
        return _indexOf(list, value) >= 0;
    }

    function _swap(list as Array<Symbol>, a as Number, b as Number) as Void {
        var tmp = list[a];
        list[a] = list[b];
        list[b] = tmp;
    }

    // Storage accepts Number, Float, Long, Double, Char, String, Boolean,
    // Array and Dictionary (containers included) but NOT Symbol
    // (docs/best-practices): these two convert at the Storage boundary
    // only; every other function in this module deals exclusively in
    // Symbol.
    function _toName(category as Symbol) as String {
        if (category == CATEGORY_CLIMATE) {
            return "climate";
        }
        if (category == CATEGORY_CHARGING) {
            return "charging";
        }
        if (category == CATEGORY_CHARGING_DETAIL) {
            return "chargingDetail";
        }
        if (category == CATEGORY_FIND_MY_CAR) {
            return "findMyCar";
        }
        if (category == CATEGORY_STATUS_DETAIL) {
            return "statusDetail";
        }
        return "settings";
    }

    function _fromName(value as Object?) as Symbol? {
        if (!(value instanceof String)) {
            return null;
        }
        var name = value as String;
        if (name.equals("climate")) {
            return CATEGORY_CLIMATE;
        }
        if (name.equals("charging")) {
            return CATEGORY_CHARGING;
        }
        if (name.equals("chargingDetail")) {
            return CATEGORY_CHARGING_DETAIL;
        }
        if (name.equals("findMyCar")) {
            return CATEGORY_FIND_MY_CAR;
        }
        if (name.equals("statusDetail")) {
            return CATEGORY_STATUS_DETAIL;
        }
        if (name.equals("settings")) {
            return CATEGORY_SETTINGS;
        }
        return null;
    }

}
