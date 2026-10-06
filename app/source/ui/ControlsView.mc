import Toybox.Graphics;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// US-036/US-037: the landing screen. Everything drawn at the top (state of
// charge, charging state, lock state) comes from Cache.mc only: this view
// never makes a request on its own, exactly like the glance (US-034/041):
// so it appears instantly, cached data or none. Every tile is a direct
// action (never a category), filtered by vehicle.operations[], built with
// WatchUi.Selectable so one layout serves touch and the five buttons
// (setKeyToSelectableInteraction, see ControlsView.onShow()). StatusView
// (task 6) sits one press below, reached via the DOWN behaviour
// (onNextPage), never by remapping back.
//
// ControlTiles below is a pure, side-effect-free module deliberately kept
// separate from the View/Selectable/drawing code in this same file, so
// tests/ControlTilesTests.mc can exercise "which tiles show up" and "which
// one is primary" without constructing a live View at all.
module ControlTiles {

    // One entry in the fixed candidate list this screen can ever show.
    // `operation` is the exact operations[] name (see mock/openapi.json's
    // VehicleOperation enum) gating this tile; `requiresSpin` is US-021's
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

    // Fixed order: also the fallback search order primaryAction() below
    // walks when climate itself is unsupported. Task 8 (US-022) adds the two
    // charging tiles at the end: same Candidate shape, same operations[]
    // gate (startCharging/stopCharging), never S-PIN gated. Both directions
    // are offered together exactly like climate's own pair: visibleCandidates()
    // below never looks at charging STATE, only at capability, so
    // CONNECT_CABLE (see ChargingLogic.needsCableWarning(), surfaced by
    // ControlsView.activate()/_announceStartCharging() below) can never be
    // the reason "Start charging" is hidden.
    function _candidates() as Array<Candidate> {
        return [
            new Candidate(ConfirmationPolicy.START_CLIMATE, "startAirConditioning", false, "Start\nclimate"),
            new Candidate(ConfirmationPolicy.STOP_CLIMATE, "stopAirConditioning", false, "Stop\nclimate"),
            new Candidate(ConfirmationPolicy.START_VENTILATION, "startActiveVentilation", false, "Start\nventilation"),
            new Candidate(ConfirmationPolicy.STOP_VENTILATION, "stopActiveVentilation", false, "Stop\nventilation"),
            new Candidate(ConfirmationPolicy.START_AUX_HEATING, "startAuxiliaryHeating", true, "Start\naux heat"),
            new Candidate(ConfirmationPolicy.STOP_AUX_HEATING, "stopAuxiliaryHeating", true, "Stop\naux heat"),
            new Candidate(ConfirmationPolicy.START_CHARGING, "startCharging", false, "Start\ncharging"),
            new Candidate(ConfirmationPolicy.STOP_CHARGING, "stopCharging", false, "Stop\ncharging")
        ] as Array<Candidate>;
    }

    // US-014's "operations absent means treat everything as possibly
    // supported" applies here exactly as it does to VehicleState.Vehicle:
    // duplicated rather than reused because Cache.operations() returns a
    // bare Array<String>?, not a VehicleState.Vehicle (ControlsView never
    // builds one; it has no other use for the rest of that shape). See
    // VehicleState.mc's own hasOperation() for the twin.
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

    // US-036 ("tiles for actions absent from operations[] are not
    // rendered") and US-021 ("hidden entirely when no S-PIN is set") in one
    // pass. Never hides "stop" based on state/staleness: this function
    // never looks at state at all, only capability, see the hard
    // constraint in docs/requirements.md US-036 and
    // preferredClimateAction() below for where staleness IS considered.
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
    // matching StatusView's own staleness threshold) prefers Start. This
    // never hides Stop (visibleCandidates() always offers both together
    // when climate is supported at all): it only decides which one gets
    // the select button by default.
    function preferredClimateAction(state as String?, ageSeconds as Number?) as Symbol {
        if (state == null || ageSeconds == null) {
            return ConfirmationPolicy.START_CLIMATE;
        }
        if (ageSeconds > 3600) {
            return ConfirmationPolicy.START_CLIMATE;
        }
        if (state.equals("HEATING") || state.equals("COOLING")) {
            return ConfirmationPolicy.STOP_CLIMATE;
        }
        if (state.equals("VENTILATION") || state.equals("HEATING_AUXILIARY")) {
            return ConfirmationPolicy.STOP_CLIMATE;
        }
        return ConfirmationPolicy.START_CLIMATE;
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

    // Puts the primary action first (ControlsView relies on the first
    // Selectable in setLayout()'s array starting highlighted, see
    // ControlsView._buildTiles()), keeping every other tile in the fixed
    // candidate order.
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

    // REGRESSION FIX (task 11, US-036): "at most seven tiles". A plain
    // {actionId, label} pair, deliberately not just Candidate, because the
    // full tile list this screen can show also includes find-my-car/status
    // detail/settings, which are navigation, not operations[]-gated
    // Candidates. Kept pure and separate from ControlsView's own
    // Selectable/View code, exactly like Candidate above, so
    // tests/ControlTilesTests.mc can assert the cap without constructing a
    // live View, see that file's own header comment on why this module is
    // split out at all.
    class TileDescriptor {
        public var actionId as Symbol;
        public var label as String;

        function initialize(action as Symbol, tileLabel as String) {
            actionId = action;
            label = tileLabel;
        }
    }

    const MAX_VISIBLE_TILES = 7;

    // `all` is already in FINAL display order (category order from
    // TileOrder.visible(), primary-first within climate, see
    // ControlsView._buildTiles()), so this only ever truncates, never
    // reorders: "keep the most-used actions as tiles" is satisfied by that
    // existing ordering (the user's own TileOrder arrangement, plus
    // US-037's primary-first climate rule), not by a usage count this app
    // deliberately never tracks (US-061). When `all` already fits, this
    // returns it unchanged: no "More" tile appears for a vehicle/user
    // combination that never needed one.
    function capped(all as Array<TileDescriptor>, moreAction as Symbol, moreLabel as String) as Array<TileDescriptor> {
        if (all.size() <= MAX_VISIBLE_TILES) {
            return all;
        }
        var result = [] as Array<TileDescriptor>;
        for (var i = 0; i < MAX_VISIBLE_TILES - 1; i += 1) {
            result.add(all[i]);
        }
        result.add(new TileDescriptor(moreAction, moreLabel));
        return result;
    }

    // The flip side of capped() above: whatever got pushed off the visible
    // grid, in the same order, for the "More" screen to list: "do not
    // silently drop functionality" (US-036's regression-fix brief) means
    // every one of these must still be reachable, just one press deeper.
    function overflow(all as Array<TileDescriptor>) as Array<TileDescriptor> {
        if (all.size() <= MAX_VISIBLE_TILES) {
            return [] as Array<TileDescriptor>;
        }
        var result = [] as Array<TileDescriptor>;
        for (var i = MAX_VISIBLE_TILES - 1; i < all.size(); i += 1) {
            result.add(all[i]);
        }
        return result;
    }

}

// One tile. Deliberately ignores the Drawable/color half of what
// Selectable's four states normally mean (stateDefault etc. still get real
// colours at construction, just so the constructor's typed options stay
// simple) and draws its own background + label in draw() instead, because a
// tile needs text, not just a colour swap.
class ControlTile extends WatchUi.Selectable {

    public var actionId as Symbol;
    // Which grid row this tile belongs to. Its y position is derived from
    // this and the view's scroll offset, never stored independently, so the
    // two cannot drift apart. See ControlsView._repositionTiles().
    public var row as Number;
    private var _label as String;

    function initialize(options as {
                :locX as Numeric, :locY as Numeric, :width as Numeric, :height as Numeric,
                :stateDefault as Graphics.ColorType, :stateHighlighted as Graphics.ColorType,
                :stateSelected as Graphics.ColorType, :stateDisabled as Graphics.ColorType
            }, action as Symbol, label as String, tileRow as Number) {
        Selectable.initialize(options);
        actionId = action;
        _label = label;
        row = tileRow;
    }

    function draw(dc as Dc) as Void {
        var state = getState();
        var background = _backgroundFor(state);
        dc.setColor(MonochromeTest.color(background), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(locX, locY, width, height, 8);
        if (state == :stateHighlighted) {
            // The preselected/focused tile also gets an outline: colour
            // alone must not be the only signal it is the one SELECT will
            // fire (docs/best-practices' US-010 analogue for this screen).
            dc.setPenWidth(2);
            dc.setColor(MonochromeTest.color(Graphics.COLOR_WHITE), Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(locX, locY, width, height, 8);
            dc.setPenWidth(1);
        } else if (state == :stateSelected) {
            // US-060: green (stateSelected) vs blue (stateHighlighted) is a
            // colour pair only: a THICKER outline than the highlighted
            // state's own single-pixel one gives it a distinct SHAPE too,
            // so the moment a tile actually fires is not colour-only. See
            // this task's monochrome-test audit.
            dc.setPenWidth(4);
            dc.setColor(MonochromeTest.color(Graphics.COLOR_WHITE), Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(locX, locY, width, height, 8);
            dc.setPenWidth(1);
        }
        dc.setColor(MonochromeTest.color(Graphics.COLOR_WHITE), Graphics.COLOR_TRANSPARENT);
        dc.drawText(locX + (width / 2), locY + (height / 2), Graphics.FONT_XTINY, _label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _backgroundFor(state as Symbol) as Graphics.ColorType {
        if (state == :stateHighlighted) {
            return stateHighlighted as Graphics.ColorType;
        }
        if (state == :stateSelected) {
            return stateSelected as Graphics.ColorType;
        }
        if (state == :stateDisabled) {
            return stateDisabled as Graphics.ColorType;
        }
        return stateDefault as Graphics.ColorType;
    }

}

class ControlsView extends WatchUi.View {

    // Fixed grid geometry for the 260x260 round face shared by every
    // supported device (see manifest.xml), so these are plain constants
    // rather than something computed from dc at layout time.
    private const _TILE_W = 90;
    private const _TILE_H = 46;
    private const _COL0_X = 35;
    private const _COL1_X = 135;
    private const _ROW0_Y = 52;
    private const _ROW_PITCH = 52;
    private const _COLUMNS = 2;

    // Only three rows fit, and that is geometry rather than taste. A row of
    // two 90-pixel tiles reaches 95 pixels either side of centre, so it needs
    // a chord at least that wide: sqrt(130^2 - dy^2) >= 95, so dy <= 88, so
    // y from 42 to 218. Three rows at a 52 pitch end at y 202; a fourth would
    // end at 254, where the chord is 78 pixels and the tile disappears under
    // the bezel.
    //
    // Seven tiles need four rows, which is how the "More" tile came to be cut
    // off on a real watch. The simulator's bezel is more forgiving and showed
    // it fine. The grid therefore scrolls, keeping the focused tile whole;
    // ui/GridScroll.mc holds the arithmetic.
    private const _VISIBLE_ROWS = 3;

    // Rows scrolled off the top. Always a value GridScroll.offsetFor()
    // returned, never assigned directly.
    private var _scrollRows as Number = 0;
    private var _tiles as Array<ControlTile> = [] as Array<ControlTile>;
    private var _totalRows as Number = 0;

    // Task 9 (US-028): "find my car" has no operations[] entry at all. It
    // is a data section (parkingPosition), not a command, so it cannot go
    // through ControlTiles' operations[]-gated Candidate table the way every
    // other tile does. Appended as one extra tile in _buildTiles() below,
    // independent of `ordered`, and handled as the very first branch of
    // activate() so it skips that function's phone/quota/vin guards, exactly
    // like openStatus()/openChargingDetail() skip them by being reached
    // outside activate() entirely: opening a screen needs none of that,
    // only the live command sends do.
    private const _FIND_MY_CAR_ACTION as Symbol = :findMyCar;

    // REGRESSION FIX (task 11, US-036): "at most seven tiles". Tasks 7, 8,
    // 9 and 10 each added tiles independently (climate x2, ventilation x2,
    // aux heat x2, charging x2, find my car, status, settings: eleven
    // possible), and nothing capped the total. ControlTiles.MAX_VISIBLE_TILES
    // is that cap; anything beyond position 6 collapses into one "More"
    // tile (the 7th) that opens a Menu2 listing the rest, see
    // ControlTiles.capped()/overflow() (pure, tested in isolation:
    // tests/ControlTilesTests.mc) and openMoreActions() below. The user's
    // own TileOrder ordering (and, within climate, the primary-first
    // ordering from US-037) decides what survives as a direct tile: nothing
    // here is picked by usage count (US-061's own hard rule), only by the
    // order already on screen, which is this app's best available proxy
    // for "most used".
    private const _MORE_ACTIONS_ACTION as Symbol = :moreActions;

    private var _hasTiles as Boolean = false;
    // What the "More" tile (when shown) opens: empty whenever everything
    // already fits within ControlTiles.MAX_VISIBLE_TILES, so
    // openMoreActions() never has to guess whether it was actually
    // reachable.
    private var _overflow as Array<ControlTiles.TileDescriptor> = [] as Array<ControlTiles.TileDescriptor>;

    private var _socText as String = EM_DASH;
    private var _chargingText as String = EM_DASH;
    private var _lockText as String = EM_DASH;
    // Raw (unformatted) readings behind the three texts above: kept
    // separately because US-059's state icons key off the API's own enum
    // values (see StateIcons.mc), not the already-humanised strings above.
    private var _chargingRaw as String? = null;
    private var _lockRaw as String? = null;
    private var _climateRaw as String? = null;

    // Set only by a command's own send/response handling: never touched by
    // onShow(), so a dialog's pop-back-to-this-view (which re-triggers
    // onShow()) can never clobber the "Command sent" text that was just
    // shown (see ConfirmationPolicy.run()/_announceSent() below).
    private var _statusMessage as String? = null;
    private var _statusIsError as Boolean = false;
    private var _sending as Boolean = false;

    function initialize() {
        View.initialize();
    }

    // Nothing here needs `dc` (see the grid-geometry comment above) so
    // there is nothing to do until onShow() actually builds the tiles from
    // live cache state.
    function onLayout(dc as Dc) as Void {
    }

    // Rebuilt every time this view becomes the top view, not just once:
    // returning here from StatusView (which can perform a live refresh) or
    // from a settings change must be reflected immediately, and Cache.mc is
    // Storage-backed and effectively instant (see StatusView's own onShow()
    // comment): this is "parse once when a response landed a while ago",
    // never resource loading.
    function onShow() as Void {
        _refreshStrip();
        _buildTiles();
        // US-038 (task 10): refresh the published complications every time
        // this screen becomes the top view: the same touch-point Cache.mc
        // itself is read from above, and the only one this app has: there
        // is no background service (out of scope), so a complication shows
        // whatever was cached the last time the app actually ran. Never
        // makes a request of its own, see source/Complications.mc.
        VehicleComplications.publish();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(MonochromeTest.color(Graphics.COLOR_WHITE), Graphics.COLOR_BLACK);
        dc.clear();
        _drawStrip(dc);
        if (_hasTiles) {
            View.onUpdate(dc); // draws every registered ControlTile via its own draw()
            _drawScrollHints(dc);
        } else {
            dc.setColor(MonochromeTest.color(Graphics.COLOR_LT_GRAY), Graphics.COLOR_TRANSPARENT);
            dc.drawText(dc.getWidth() / 2, 130, Graphics.FONT_XTINY,
                "No actions available\nfor this vehicle", Graphics.TEXT_JUSTIFY_CENTER);
        }
        _drawStatus(dc);
        _drawBottomHint(dc);
    }

    // ---------------------------------------------------------- building

    function _buildTiles() as Void {
        var settings = getApp().getSettings();
        var operations = Cache.operations() as Array<String>?;
        var visible = ControlTiles.visibleCandidates(operations, settings.hasSpin);

        var acSection = Cache.section("airConditioning");
        var acState = (acSection != null) ? (acSection.get("state") as String?) : null;
        var acAge = Cache.sectionAge("airConditioning");
        var ageSeconds = (acAge != null) ? (Time.now().value() - acAge) : null;
        var preferred = ControlTiles.preferredClimateAction(acState, ageSeconds);

        var primary = ControlTiles.primaryAction(visible, preferred);
        var ordered = ControlTiles.orderedForDisplay(visible, primary);

        // US-061 (task 10): everything below this point is ordering-only.
        // no gating condition from task 7/8/9 changes. `ordered` above
        // already carries the primary action first (US-037) and the fixed
        // order within it otherwise; splitting it by operation preserves
        // that inner order exactly, it only decides which BLOCK is drawn
        // first. Find My Car's own "hidden once known unsupported" check
        // (task 9, ParkingFeature.isKnownUnsupported()) is untouched, just
        // read once here instead of inline below.
        var climateGroup = [] as Array<ControlTiles.Candidate>;
        var chargingGroup = [] as Array<ControlTiles.Candidate>;
        for (var i = 0; i < ordered.size(); i += 1) {
            var candidate = ordered[i] as ControlTiles.Candidate;
            if (TileOrder.isChargingOperation(candidate.operation)) {
                chargingGroup.add(candidate);
            } else {
                climateGroup.add(candidate);
            }
        }
        var hasFindMyCarTile = !ParkingFeature.isKnownUnsupported();
        var supported = TileOrder.supportedCategories(climateGroup.size() > 0, chargingGroup.size() > 0, hasFindMyCarTile);
        var categories = TileOrder.visible(supported);

        // Every candidate action this vehicle/user combination COULD show,
        // in final display order, with nothing capped yet: climate can
        // alone contribute up to six of these (start/stop climate,
        // ventilation, aux heat) and charging two more, which is exactly
        // how tasks 7-10 together blew past seven (see the REGRESSION FIX
        // comment on _MORE_ACTIONS_ACTION above).
        var all = [] as Array<ControlTiles.TileDescriptor>;
        for (var c = 0; c < categories.size(); c += 1) {
            var category = categories[c] as Symbol;
            if (category == TileOrder.CATEGORY_CLIMATE) {
                _appendCandidateDescriptors(all, climateGroup);
            } else if (category == TileOrder.CATEGORY_CHARGING) {
                _appendCandidateDescriptors(all, chargingGroup);
            } else if (category == TileOrder.CATEGORY_FIND_MY_CAR) {
                all.add(new ControlTiles.TileDescriptor(_FIND_MY_CAR_ACTION, "Find\nmy car"));
            } else if (category == TileOrder.CATEGORY_STATUS_DETAIL) {
                // A touch-friendly alternative to the DOWN behaviour above,
                // per the story's own default order: DOWN keeps working
                // regardless of where (or whether) this tile is shown.
                all.add(new ControlTiles.TileDescriptor(:openStatusDetail, "Status"));
            } else if (category == TileOrder.CATEGORY_SETTINGS) {
                // The only entry point into TileOrderView: this task's
                // file-ownership does not extend to
                // VozidloApp.getSettingsView() (task 7's existing
                // TargetTemperatureSettingsView), see openTileOrder().
                all.add(new ControlTiles.TileDescriptor(:openTileOrder, "Settings"));
            }
        }

        // REGRESSION FIX (US-036): cap at seven, whatever the vehicle
        // supports: anything beyond position 6 becomes a single "More"
        // tile, and _overflow is what openMoreActions() lists so nothing
        // is silently dropped.
        var visibleDescriptors = ControlTiles.capped(all, _MORE_ACTIONS_ACTION, "More");
        _overflow = ControlTiles.overflow(all);

        // Two views of the same objects: setLayout() takes Drawables, while
        // repositioning needs the ControlTile type for its `row`. Built in
        // one pass rather than cast back out of the Drawable array.
        var tiles = [] as Array<WatchUi.Drawable>;
        var controlTiles = [] as Array<ControlTile>;
        for (var i = 0; i < visibleDescriptors.size(); i += 1) {
            var descriptor = visibleDescriptors[i] as ControlTiles.TileDescriptor;
            var tile = _tileAt(i, descriptor.actionId, descriptor.label);
            tiles.add(tile);
            controlTiles.add(tile);
        }

        _hasTiles = tiles.size() > 0;
        // Scroll state belongs to this set of tiles, so it is rebuilt with
        // them: a rebuild always starts at the top, matching the framework
        // highlighting the first Selectable again.
        _tiles = controlTiles;
        _totalRows = GridScroll.rowCount(tiles.size(), _COLUMNS);
        _scrollRows = 0;
        _repositionTiles();
        // Every rebuild replaces the whole layout, which is exactly what is
        // wanted: whichever tile TileOrder places first starts highlighted
        // again each time this screen is shown (the framework's own "first
        // Selectable in setLayout() starts highlighted" behaviour). With
        // the DEFAULT order that is still the primary climate/charging
        // action, per US-037; a user who has reordered categories has, by
        // definition, chosen that trade-off themselves (US-061).
        setLayout(tiles);
        setKeyToSelectableInteraction(true);
    }

    // Appends one descriptor per entry in `candidates`, in order: the
    // capping decision (ControlTiles.capped()/overflow()) happens once,
    // later, over the FULL descriptor list built across every category, not
    // per-group, so it can never split a category awkwardly.
    function _appendCandidateDescriptors(descriptors as Array<ControlTiles.TileDescriptor>, candidates as Array<ControlTiles.Candidate>) as Void {
        for (var i = 0; i < candidates.size(); i += 1) {
            var candidate = candidates[i] as ControlTiles.Candidate;
            descriptors.add(new ControlTiles.TileDescriptor(candidate.actionId, candidate.label));
        }
    }

    // Common geometry + colours for every tile this screen draws: command
    // tiles and the find-my-car/status/settings navigation tiles alike.
    // Extracted here (task 10) so the category loop in _buildTiles() above
    // doesn't repeat this construction call for each of the five categories.
    function _tileAt(index as Number, action as Symbol, label as String) as ControlTile {
        var col = index % _COLUMNS;
        var row = index / _COLUMNS;
        var x = (col == 0) ? _COL0_X : _COL1_X;
        return new ControlTile({
            :locX => x, :locY => _rowY(row), :width => _TILE_W, :height => _TILE_H,
            :stateDefault => Graphics.COLOR_DK_GRAY,
            :stateHighlighted => Graphics.COLOR_BLUE,
            :stateSelected => Graphics.COLOR_GREEN,
            :stateDisabled => Graphics.COLOR_DK_GRAY
        }, action, label, row);
    }

    // The y a row draws at under the current scroll offset. Rows outside the
    // window land off-screen and the Dc clips them, which is what makes this
    // a scrolling list rather than a pager: relative positions are preserved,
    // so the framework's own spatial key navigation between Selectables keeps
    // working untouched.
    function _rowY(row as Number) as Number {
        return _ROW0_Y + ((row - _scrollRows) * _ROW_PITCH);
    }

    function _repositionTiles() as Void {
        for (var i = 0; i < _tiles.size(); i += 1) {
            var tile = _tiles[i] as ControlTile;
            tile.setLocation(tile.locX, _rowY(tile.row));
        }
    }

    // Called by ControlsDelegate when a tile takes the highlight, including
    // on a highlight-only move. Scrolls the window the minimum needed to show
    // that tile whole, then redraws. A no-op when it is already visible,
    // which is the common case.
    function ensureTileVisible(tile as ControlTile) as Void {
        var wanted = GridScroll.offsetFor(_scrollRows, tile.row, _VISIBLE_ROWS, _totalRows);
        if (wanted == _scrollRows) {
            return;
        }
        _scrollRows = wanted;
        _repositionTiles();
        WatchUi.requestUpdate();
    }

    // Carets saying there is more above or below. Without them a scrolling
    // grid looks like a grid that is simply missing tiles.
    function _drawScrollHints(dc as Dc) as Void {
        var x = dc.getWidth() / 2;
        dc.setColor(MonochromeTest.color(Graphics.COLOR_LT_GRAY), Graphics.COLOR_TRANSPARENT);
        if (GridScroll.hasRowsAbove(_scrollRows)) {
            dc.fillPolygon([[x - 6, 50], [x + 6, 50], [x, 44]] as Array<[Numeric, Numeric]>);
        }
        if (GridScroll.hasRowsBelow(_scrollRows, _VISIBLE_ROWS, _totalRows)) {
            dc.fillPolygon([[x - 6, 206], [x + 6, 206], [x, 212]] as Array<[Numeric, Numeric]>);
        }
    }

    // -------------------------------------------------------- activation

    // Called by ControlsDelegate.onSelectable() once a tile has actually
    // reached :stateSelected (a tap, or SELECT while highlighted). Never
    // for a highlight-only transition.
    function activate(action as Symbol) as Void {
        // Task 9: opening a screen, not sending a command. Skip every
        // guard below (phone connection, quota, VIN) exactly like
        // openStatus()/openChargingDetail() do by living outside this
        // function. LocationView itself decides what it can show, cached or
        // not (US-033's own "still offers the last known parked position").
        if (action == _FIND_MY_CAR_ACTION) {
            openLocation();
            return;
        }
        // US-061 (task 10): the Status/Settings navigation tiles, exactly
        // the same "opening a screen, not sending a command" reasoning as
        // the find-my-car branch just above: skip every guard below.
        if (action == :openStatusDetail) {
            openStatus();
            return;
        }
        if (action == :openTileOrder) {
            openTileOrder();
            return;
        }
        // REGRESSION FIX (US-036): the 7th slot when there is overflow.
        // opening a menu, same "not a command" reasoning as every branch
        // above, so it also skips the guards below.
        if (action == _MORE_ACTIONS_ACTION) {
            openMoreActions();
            return;
        }
        if (_sending) {
            return; // a request is already in flight; ignore a stray double-press
        }
        if (!(System.getDeviceSettings().phoneConnected)) {
            return; // US-045: silently disabled, same as StatusView.refresh()
        }
        if (!Quota.canSpend()) {
            _statusMessage = "Quota spent for this hour";
            _statusIsError = true;
            WatchUi.requestUpdate();
            return;
        }
        var settings = getApp().getSettings();
        if (!settings.vinValid || settings.apiKey.length() == 0) {
            return; // onboarding's job, not this screen's, see OnboardingGate.mc
        }

        if (action == ConfirmationPolicy.START_CLIMATE) {
            ConfirmationPolicy.run(action, "Start climate?", method(:_sendStartClimate), method(:_announceSent));
        } else if (action == ConfirmationPolicy.STOP_CLIMATE) {
            ConfirmationPolicy.run(action, "Stop climate?", method(:_sendStopClimate), method(:_announceSent));
        } else if (action == ConfirmationPolicy.START_VENTILATION) {
            ConfirmationPolicy.run(action, "Start ventilation?", method(:_sendStartVentilation), method(:_announceSent));
        } else if (action == ConfirmationPolicy.STOP_VENTILATION) {
            ConfirmationPolicy.run(action, "Stop ventilation?", method(:_sendStopVentilation), method(:_announceSent));
        } else if (action == ConfirmationPolicy.START_AUX_HEATING) {
            ConfirmationPolicy.run(action, "Start the auxiliary heater?", method(:_sendStartAuxHeating), method(:_announceSent));
        } else if (action == ConfirmationPolicy.STOP_AUX_HEATING) {
            ConfirmationPolicy.run(action, "Stop the auxiliary heater?", method(:_sendStopAuxHeating), method(:_announceSent));
        } else if (action == ConfirmationPolicy.START_CHARGING) {
            // US-022: sends immediately (not in ConfirmationPolicy's
            // _alwaysConfirms table): the announce callback is the one that
            // differs from every other "start" action, to carry the
            // CONNECT_CABLE warning (see _announceStartCharging() below).
            ConfirmationPolicy.run(action, "Start charging?", method(:_sendStartCharging), method(:_announceStartCharging));
        } else if (action == ConfirmationPolicy.STOP_CHARGING) {
            // US-062: stopping charging interrupts something already
            // running, so it is one of ConfirmationPolicy's _alwaysConfirms
            // entries: the dialog here is not optional the way climate's is.
            ConfirmationPolicy.run(action, "Stop charging?", method(:_sendStopCharging), method(:_announceSent));
        }
    }

    // "One press below" (US-036's own phrase): DOWN opens the detailed
    // status screen task 6 already built. Never a Menu2 detour, never a
    // remap of back: StatusDelegate itself leaves onBack() untouched, so
    // getting back here is exactly one press too.
    function openStatus() as Void {
        var status = new StatusView();
        WatchUi.pushView(status, new StatusDelegate(status), WatchUi.SLIDE_UP);
    }

    // US-023: "a screen below the tile". The vertical partner to DOWN's
    // StatusView above, reached via UP (ControlsDelegate.onPreviousPage()),
    // one press away from this landing screen exactly like StatusView is.
    // Always pushed, never gated on operations[]/Cache: ChargingDetailView
    // itself shows "no charging data yet" when there is nothing cached, the
    // same graceful-absence convention StatusView's own KIND_UNSUPPORTED
    // sections already use, rather than a second gating scheme here.
    function openChargingDetail() as Void {
        var detail = new ChargingDetailView();
        WatchUi.pushView(detail, new ChargingDetailDelegate(detail), WatchUi.SLIDE_DOWN);
    }

    // Task 9 (US-028): the "Find my car" tile's action, see
    // _FIND_MY_CAR_ACTION's own comment above for why this is reached from
    // activate() rather than from a paging behaviour (both UP and DOWN are
    // already spoken for by charging detail and status).
    function openLocation() as Void {
        var location = new LocationView();
        WatchUi.pushView(location, new LocationDelegate(location), WatchUi.SLIDE_LEFT);
    }

    // US-061 (task 10): the on-device tile-ordering screen, reached from
    // the "Settings" tile _buildTiles() adds above, not from
    // AppBase.getSettingsView(), which already belongs to task 7's
    // TargetTemperatureSettingsView and sits outside this task's
    // file-ownership (VozidloApp.mc's own edit is limited to
    // getGlanceView(), see the task's final report).
    function openTileOrder() as Void {
        var view = new TileOrderView();
        WatchUi.pushView(view, new TileOrderDelegate(view), WatchUi.SLIDE_LEFT);
    }

    // REGRESSION FIX (US-036): the "More" tile's action. Everything
    // ControlTiles.overflow() pushed off the seven-tile grid, listed here
    // by Menu2 (well within its own ~7-item guidance since this is only
    // ever what didn't fit above) so nothing this vehicle supports is ever
    // silently unreachable. Selecting an item re-enters activate() with
    // that action's real id, so it goes through the exact same
    // confirmation/send path a direct tile would: this menu is purely a
    // second way to reach the same action, never a different one.
    function openMoreActions() as Void {
        var menu = new WatchUi.Menu2({ :title => "More" });
        for (var i = 0; i < _overflow.size(); i += 1) {
            var descriptor = _overflow[i] as ControlTiles.TileDescriptor;
            menu.addItem(new WatchUi.MenuItem(descriptor.label, null, descriptor.actionId, null));
        }
        WatchUi.pushView(menu, new MoreActionsDelegate(self), WatchUi.SLIDE_LEFT);
    }

    // ------------------------------------------------------------ sending
    //
    // Each function below does exactly one thing: build this command's
    // body (if it needs one) and fire it. `:responseType` is never set here
    //: ApiClient's own functions already omit it for every command (see
    // ApiClient.mc); nothing here re-adds it.

    function _sendStartClimate() as Void {
        _sending = true;
        var settings = getApp().getSettings();
        ApiClient.startAirConditioning(settings.vin, _airConditioningBody(settings), settings.apiKey, method(:_onCommandResponse));
    }

    function _sendStopClimate() as Void {
        _sending = true;
        var settings = getApp().getSettings();
        ApiClient.stopAirConditioning(settings.vin, settings.apiKey, method(:_onCommandResponse));
    }

    function _sendStartVentilation() as Void {
        _sending = true;
        var settings = getApp().getSettings();
        // US-020: no body, no S-PIN. Nothing else to build.
        ApiClient.startActiveVentilation(settings.vin, settings.apiKey, method(:_onCommandResponse));
    }

    function _sendStopVentilation() as Void {
        _sending = true;
        var settings = getApp().getSettings();
        ApiClient.stopActiveVentilation(settings.vin, settings.apiKey, method(:_onCommandResponse));
    }

    function _sendStartAuxHeating() as Void {
        _sending = true;
        var settings = getApp().getSettings();
        // US-021: spin is the only REQUIRED field of
        // StartAuxiliaryHeatingConfiguration; duration/mode have no on-watch
        // picker in this task (see the final report's noted scope trim), so
        // fixed, sensible defaults are sent: 600s/HEATING matches
        // openapi.json's own example values for this exact body. settings.spin
        // goes straight into the request body and nowhere else: it is never
        // logged, never echoed into _statusMessage, never drawn, see
        // _onCommandResponse() below, which only ever reads the SERVER's
        // response, never this request.
        var body = {
            "spin" => settings.spin,
            "durationInSeconds" => 600,
            "startMode" => "HEATING"
        };
        ApiClient.startAuxiliaryHeating(settings.vin, body, settings.apiKey, method(:_onCommandResponse));
    }

    function _sendStopAuxHeating() as Void {
        _sending = true;
        var settings = getApp().getSettings();
        ApiClient.stopAuxiliaryHeating(settings.vin, settings.apiKey, method(:_onCommandResponse));
    }

    // US-022: neither endpoint takes a body (see docs/requirements.md, US-022).
    function _sendStartCharging() as Void {
        _sending = true;
        var settings = getApp().getSettings();
        ApiClient.startCharging(settings.vin, settings.apiKey, method(:_onCommandResponse));
    }

    function _sendStopCharging() as Void {
        _sending = true;
        var settings = getApp().getSettings();
        ApiClient.stopCharging(settings.vin, settings.apiKey, method(:_onCommandResponse));
    }

    // US-016: the body always carries BOTH fields. Preference order: an
    // explicit on-device/phone override (US-018) first; otherwise exactly
    // what the car itself last reported (value AND unit, unconverted, see
    // this task's final report for why no C/F conversion happens here);
    // otherwise a conservative common default so a body is always sent at
    // all, never omitted.
    function _airConditioningBody(settings as Settings.Config) as Dictionary<Object, Object> {
        var override = settings.targetTemperature;
        if (override != null) {
            return {
                "targetTemperature" => { "value" => override, "unit" => _apiUnit(settings.temperatureUnit) },
                "airConditioningWithoutExternalPower" => true
            };
        }

        var cached = Cache.section("airConditioning");
        var cachedValue = (cached != null) ? cached.get("targetValue") : null;
        var cachedUnit = (cached != null) ? (cached.get("targetUnit") as String?) : null;
        if (cachedValue != null && cachedUnit != null) {
            return {
                "targetTemperature" => { "value" => cachedValue, "unit" => cachedUnit },
                "airConditioningWithoutExternalPower" => true
            };
        }

        return {
            "targetTemperature" => { "value" => 21.0, "unit" => "CELSIUS" },
            "airConditioningWithoutExternalPower" => true
        };
    }

    function _apiUnit(unit as String) as String {
        if (unit.equals("F")) {
            return "FAHRENHEIT";
        }
        return "CELSIUS";
    }

    // -------------------------------------------------------- response

    // US-016/US-043: a 202 means "sent", full stop. _announceSent() (called
    // the moment the request went out, from ConfirmationPolicy.run()) already
    // said so; there is nothing more specific a 202's empty body could add,
    // and this app never claims "Climate on" from a command response. A
    // negative code overwrites that with "not sent", see ProblemDetail's own
    // note on why the reason is necessarily generic for a command response.
    function _onCommandResponse(responseCode as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        _sending = false;

        if (responseCode >= 200 && responseCode < 300) {
            Quota.recordHeaders(null, null, null);
            WatchUi.requestUpdate();
            return;
        }

        var body = (data instanceof Dictionary) ? (data as Dictionary) : null;
        if (responseCode == 429) {
            var problemType = (body != null) ? (body.get("type") as String?) : null;
            Quota.recordRateLimited(problemType, null);
        }
        _statusMessage = "Not sent: " + _shorten(ProblemDetail.describe(responseCode, body, Quota.retryAfterUntil()).text);
        _statusIsError = true;
        _toast(_statusMessage as String);
        WatchUi.requestUpdate();
    }

    // US-062: called once, immediately, on whichever branch of
    // ConfirmationPolicy.run() actually fires the request: the vibration
    // itself happens inside that module (see ConfirmationPolicy.mc); this is
    // only the on-screen half.
    function _announceSent() as Void {
        _statusMessage = "Command sent";
        _statusIsError = false;
        _toast(_statusMessage as String);
        WatchUi.requestUpdate();
    }

    // US-022: "starting is offered but the app warns that no cable appears
    // to be connected": the tile itself is never hidden for this (see
    // _candidates()'s own comment), and this is not a second confirmation
    // dialog, just a different announce message once the request has
    // already gone out. Reads the same cached charging state _drawStrip()
    // already shows, so this can never disagree with what is on screen.
    function _announceStartCharging() as Void {
        var charging = Cache.section("charging");
        var state = (charging != null) ? (charging.get("state") as String?) : null;
        if (ChargingLogic.needsCableWarning(state)) {
            _statusMessage = "Sent: no cable appears to be connected";
            _statusIsError = true; // orange, same as every other warning on this screen
        } else {
            _statusMessage = "Command sent";
            _statusIsError = false;
        }
        _toast(_statusMessage as String);
        WatchUi.requestUpdate();
    }

    // US-058: "use the Personality library so components pick up the
    // device's native look rather than us hand-rolling visuals": the
    // command-result line above is kept (it persists on screen, which a
    // toast deliberately does not), but every one of those same moments
    // also fires the system's own native toast, exactly the Personality
    // library's own worked example under "Toasts" (WatchUi.showToast()).
    // Guarded with `has` per docs/best-practices, "Probe optional API
    // surface with has": this app's minApiLevel (5.2.0) predates
    // showToast's own System 6 introduction on some devices, so this stays
    // a bonus, never a requirement, if the running firmware lacks it.
    function _toast(message as String) as Void {
        if (WatchUi has :showToast) {
            WatchUi.showToast(message, null);
        }
    }

    // -------------------------------------------------------- top strip

    function _refreshStrip() as Void {
        var charging = Cache.section("charging");
        _chargingRaw = (charging != null) ? (charging.get("state") as String?) : null;
        _socText = (charging != null) ? _percentText(charging.get("batterySocPercent")) : EM_DASH;
        _chargingText = (charging != null) ? _textOr(_chargingRaw) : EM_DASH;

        var status = Cache.section("status");
        _lockRaw = (status != null) ? (status.get("doorsLocked") as String?) : null;
        _lockText = (status != null) ? _lockLabel(_lockRaw) : EM_DASH;

        // US-059: the top strip's own icon row needs airConditioning's raw
        // state too, even though this screen's text line above never showed
        // it, see the icon row in _drawStrip() below.
        var ac = Cache.section("airConditioning");
        _climateRaw = (ac != null) ? (ac.get("state") as String?) : null;
    }

    function _drawStrip(dc as Dc) as Void {
        var centerX = dc.getWidth() / 2;
        dc.setColor(MonochromeTest.color(Graphics.COLOR_WHITE), Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 18, Graphics.FONT_XTINY,
            _socText + "  " + _chargingText + "  " + _lockText, Graphics.TEXT_JUSTIFY_CENTER);

        // US-059/US-060: the same icon-per-state used on StatusView, the
        // glance and the complications, drawn again here so this screen
        // never depends on the words above being read: lock status always
        // shows one (its own icon covers "no data yet" via UNKNOWN);
        // charging/climate only show one when their state actually
        // warrants it (see StateIcons.forChargingStatus()/
        // forClimateStatus()'s own comments on why a blank slot there is
        // deliberate, not a gap).
        var iconColor = MonochromeTest.color(Graphics.COLOR_WHITE);
        StateIcons.draw(dc, StateIcons.forLockStatus(_lockRaw), centerX, 38, 9, iconColor);
        var chargeIcon = StateIcons.forChargingStatus(_chargingRaw);
        if (chargeIcon != null) {
            StateIcons.draw(dc, chargeIcon as Symbol, centerX - 40, 38, 9, iconColor);
        }
        var climateIcon = StateIcons.forClimateStatus(_climateRaw);
        if (climateIcon != null) {
            StateIcons.draw(dc, climateIcon as Symbol, centerX + 40, 38, 9, iconColor);
        }
    }

    function _drawStatus(dc as Dc) as Void {
        var message = _statusMessage;
        if (message == null) {
            return;
        }
        dc.setColor(MonochromeTest.color(_statusIsError ? Graphics.COLOR_ORANGE : Graphics.COLOR_GREEN), Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, 216, Graphics.FONT_XTINY, message as String, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function _drawBottomHint(dc as Dc) as Void {
        // US-023 adds UP -> charging detail alongside task 6's existing
        // DOWN -> status (see ControlsDelegate.onPreviousPage() below).
        //
        // Drawn through TextBlock.drawFittedLine() rather than straight at the
        // bottom edge: at y 240 on a round 260 face the chord leaves about 84
        // usable pixels, and this hint needs far more, so it used to run off
        // both sides. The helper moves it up to where it fits whole.
        TextBlock.drawFittedLine(dc, "UP charging - DOWN status", Graphics.FONT_XTINY,
            MonochromeTest.color(Graphics.COLOR_DK_GRAY), dc.getHeight() - 20);
    }

    // ------------------------------------------------------------- text

    function _percentText(value as Object?) as String {
        if (value == null) {
            return EM_DASH;
        }
        if (value instanceof Float) {
            return (value as Float).toNumber().toString() + "%";
        }
        return value.toString() + "%";
    }

    function _textOr(value as Object?) as String {
        if (value == null) {
            return EM_DASH;
        }
        return value.toString();
    }

    // Duplicated from StatusView._lockLabel rather than reused across
    // classes: small, and this screen only ever needs the single-word
    // form for the top strip, not StatusView's full page rendering.
    function _lockLabel(raw as String?) as String {
        if (raw == null) {
            return EM_DASH;
        }
        if (raw.equals("YES")) {
            return "LOCKED";
        }
        if (raw.equals("NO")) {
            return "UNLOCKED";
        }
        return raw;
    }

    function _shorten(text as String) as String {
        if (text.length() > 36) {
            return text.substring(0, 36) as String;
        }
        return text;
    }

    private const EM_DASH as String = "—";

}

// BehaviorDelegate, never InputDelegate, see docs/best-practices. Back is
// left completely untouched. Selectable activation goes through
// onSelectable() (the framework's own event for a Selectable's state
// change), not onSelect(): with setKeyToSelectableInteraction(true) active,
// SELECT drives the highlighted tile from :stateHighlighted to
// :stateSelected itself, and a touch tap does the same directly. Either
// way, onSelectable() is the one place that transition is observed.
class ControlsDelegate extends WatchUi.BehaviorDelegate {

    // Weak, per docs/best-practices ("break reference cycles with weak()")
    //: this delegate is owned by the view it acts on.
    private var _view as WeakReference;

    function initialize(view as ControlsView) {
        BehaviorDelegate.initialize();
        _view = view.weak();
    }

    function onSelectable(event as WatchUi.SelectableEvent) as Boolean {
        var instance = event.getInstance();
        if (!(instance instanceof ControlTile)) {
            return false;
        }
        var tile = instance as ControlTile;
        if (tile.getState() != :stateSelected) {
            // A highlight-only move. Nothing to fire, but the grid scrolls
            // more rows than fit on a round face, so the newly focused tile
            // may be off-screen: ask the view to bring it fully into view.
            var highlighted = _resolve();
            if (highlighted != null && tile.getState() == :stateHighlighted) {
                highlighted.ensureTileVisible(tile);
            }
            return true;
        }

        var view = _resolve();
        if (view != null) {
            view.activate(tile.actionId);
        }
        // Momentary action, not a persisted toggle (unlike the CheckBox
        // sample this pattern is drawn from): reset immediately so the
        // tile is ready to fire again rather than staying "selected".
        tile.setState(:stateDefault);
        return true;
    }

    function onNextPage() as Boolean {
        var view = _resolve();
        if (view != null) {
            view.openStatus();
        }
        return true;
    }

    // US-023: UP opens the charging session detail screen. The vertical
    // partner to DOWN's StatusView above, previously unused on this
    // delegate (docs/best-practices: "navigate vertically").
    function onPreviousPage() as Boolean {
        var view = _resolve();
        if (view != null) {
            view.openChargingDetail();
        }
        return true;
    }

    function _resolve() as ControlsView? {
        if (!_view.stillAlive()) {
            return null;
        }
        return _view.get() as ControlsView?;
    }

}

// REGRESSION FIX (US-036): the delegate for ControlsView.openMoreActions()'s
// Menu2: mirrors ChargingDetailView.mc's ChargingActionMenuDelegate: select
// an item and hand its id straight back to ControlsView.activate(), exactly
// as if it had been a direct tile.
class MoreActionsDelegate extends WatchUi.Menu2InputDelegate {

    private var _view as WeakReference;

    function initialize(view as ControlsView) {
        Menu2InputDelegate.initialize();
        _view = view.weak();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var view = _resolve();
        if (view != null) {
            view.activate(item.getId() as Symbol);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function _resolve() as ControlsView? {
        if (!_view.stillAlive()) {
            return null;
        }
        return _view.get() as ControlsView?;
    }

}
