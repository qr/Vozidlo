import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// Night Panel home (D1 variant b, PoC NH.hero, ui-improvements.md C1b): a
// NightMenu whose title area is the hero and whose rows are every action in
// TileOrder order (US-036, US-061). It is the root view, so there is one per
// app run: returning from any screen lands on the same instance, which is
// what lets the focus survive (A11).
//
// Buttons: UP/DOWN move the focus and wrap at both ends, like Garmin's own
// menus. Charging and Status are rows (US-023, US-036 "one press below"), and
// a tap on the hero opens Status (onTitle).
class HomeMenu extends NightMenu {

    private var _signature as String;
    private var _hero as HomeHero.Data;
    // Set by a command's send/response handling (CommandRunner). It lives
    // until home has drawn it once and is then cleared by the next onShow()
    // (HomeHero.feedbackAfterShow), so a confirmation's pop back to this
    // view cannot clobber the "Command sent" that was just set, and a
    // missing phone or stale data are not hidden behind it for the rest of
    // the session (US-045, US-009).
    private var _feedback as String? = null;
    private var _feedbackKind as Symbol = :sent;
    private var _feedbackDrawn as Boolean = false;
    private var _runner as CommandRunner;

    function initialize() {
        var built = HomeRows.build();
        // US-037: the primary action has the focus at launch.
        NightMenu.initialize("", built[1], Theme.HOME_TITLE_H);
        _signature = ControlTiles.signature(built[0]);
        _addRows(built[0]);
        _hero = HomeHero.fromCache(null, :sent);
        _runner = new CommandRunner(self);
    }

    // Every time home becomes the top view again: returning from Status (a
    // live refresh), from settings or from a command must show at once.
    // Cache.mc is Storage-backed and effectively instant, never a request.
    function onShow() as Void {
        NightMenu.onShow();
        _feedback = HomeHero.feedbackAfterShow(_feedback, _feedbackDrawn);
        if (_feedback == null) {
            _feedbackDrawn = false;
        }
        _hero = HomeHero.fromCache(_feedback, _feedbackKind);
        var built = HomeRows.build();
        var signature = ControlTiles.signature(built[0]);
        // A11: the rows are rebuilt only when they changed (operations[]
        // arrived, a tile was moved or hidden), so the focus a user left on
        // a row is still there when they come back.
        if (!signature.equals(_signature)) {
            _signature = signature;
            while (getItem(0) != null) {
                deleteItem(0);
            }
            _addRows(built[0]);
            setFocus(built[1]);
        }
        // US-038: refresh the published complications whenever home is
        // shown: there is no background service, so a complication shows
        // what was cached the last time the app ran (source/Complications.mc).
        VehicleComplications.publish();
    }

    function drawTitle(dc as Dc) as Void {
        dc.setColor(Theme.TEXT_1, Theme.BG);
        dc.clear();
        // From focus 1 on only the bottom 33 px of the hero would show, cut
        // by the edge: the hero belongs to the top of the list.
        if (!titleShown()) {
            return;
        }
        HomeHero.draw(dc, _hero);
        if (_feedback != null) {
            _feedbackDrawn = true;
        }
    }

    // Called after the rows and title, over the whole screen: the SoC ring
    // stays put while the list scrolls under it.
    function drawForeground(dc as Dc) as Void {
        HomeHero.drawRing(dc, _hero);
    }

    // CommandRunner's way back in (through a WeakReference).
    function showFeedback(text as String, kind as Symbol) as Void {
        _feedback = text;
        _feedbackKind = kind;
        _feedbackDrawn = false;
        _hero = HomeHero.fromCache(_feedback, _feedbackKind);
    }

    // CommandChecker's report: what the car said 15 s after a command. The
    // read has refreshed the cache, so the hero is rebuilt from it too.
    function commandChecked(text as String, kind as Symbol) as Void {
        showFeedback(text, kind);
    }

    function run(action as Symbol) as Void {
        _runner.activate(action);
    }

    function _addRows(rows as Array<ControlTiles.TileDescriptor>) as Void {
        for (var i = 0; i < rows.size(); i += 1) {
            var row = rows[i] as ControlTiles.TileDescriptor;
            addItem(new NightMenuItem(row.actionId, row.label, null, row.icon, null));
        }
    }

}

// What the home list shows right now, read from Cache, Settings and
// TileOrder. Shared with TileOrderView so the ordering screen offers exactly
// what home shows (US-061 "never less").
module HomeRows {

    // [rows, index of the primary action] (US-037).
    function build() as [Array<ControlTiles.TileDescriptor>, Number] {
        var settings = getApp().getSettings();
        var operations = Cache.operations() as Array<String>?;
        var ac = Cache.section("airConditioning");
        var acState = (ac != null) ? (ac.get("state") as String?) : null;
        var acAt = Cache.sectionAge("airConditioning");
        var ageSeconds = (acAt != null) ? (Time.now().value() - acAt) : null;
        var preferred = ControlTiles.preferredClimateAction(acState, ageSeconds);

        var rows = ControlTiles.rows(operations, settings.hasSpin, preferred,
            _chargingDetail(operations), !ParkingFeature.isKnownUnsupported());
        // Settings cannot be hidden (TileOrder.isHideable), so the list is
        // never empty; kept as a guard, because an empty list would leave
        // no way back to the tile order.
        if (rows.size() == 0) {
            rows.add(new ControlTiles.TileDescriptor(ControlTiles.OPEN_TILE_ORDER, "Settings", :gear));
        }
        var primary = ControlTiles.primaryAction(ControlTiles.visibleCandidates(operations, settings.hasSpin), preferred);
        return [rows, ControlTiles.indexOf(rows, primary)];
    }

    function supported() as Array<Symbol> {
        var settings = getApp().getSettings();
        var operations = Cache.operations() as Array<String>?;
        return ControlTiles.supportedCategories(ControlTiles.visibleCandidates(operations, settings.hasSpin),
            _chargingDetail(operations), !ParkingFeature.isKnownUnsupported());
    }

    function _chargingDetail(operations as Array<String>?) as Boolean {
        return ControlTiles.hasChargingDetail(operations, Cache.section("charging") != null);
    }

}

// Home input. Rows that open a screen go only through the screen entry
// points (packages never call each other's classes); commands go through
// CommandRunner with every guard and ConfirmationPolicy (US-062).
class HomeDelegate extends NightMenuDelegate {

    // Weak: this delegate is owned alongside the menu it acts on
    // (docs/best-practices "Break reference cycles").
    private var _home as WeakReference;

    function initialize(home as HomeMenu) {
        // Rows that open screens push on top; nothing pops on select.
        NightMenuDelegate.initialize(false);
        _home = home.weak();
    }

    function onPick(id as Object?) as Void {
        if (id == ControlTiles.OPEN_CHARGING) {
            ChargingScreen.open();
        } else if (id == ControlTiles.OPEN_STATUS) {
            StatusScreen.open();
        } else if (id == ControlTiles.FIND_MY_CAR) {
            FindMyCarScreen.open();
        } else if (id == ControlTiles.OPEN_TILE_ORDER) {
            SettingsScreen.openTileOrder();
        } else if (id instanceof Symbol) {
            var home = _resolve();
            if (home != null) {
                home.run(id as Symbol);
            }
        }
    }

    // The list wraps at both ends, like Garmin's own menus. 1.1.0 opened
    // Charging past the first row and Status past the last instead: someone
    // scrolling with UP or DOWN saw a screen open that they never chose, after
    // two presses or after twenty depending on where the focus started.
    function onWrap(key as WatchUi.Key) as Boolean {
        return true;
    }

    // A tap on the hero: the touch route to Status.
    function onTitle() as Void {
        StatusScreen.open();
    }

    // Back on home leaves the app: the platform default, not NightMenu's
    // slide-right pop meant for menus pushed on top of something.
    function onBack() as Void {
        Menu2InputDelegate.onBack();
    }

    function _resolve() as HomeMenu? {
        if (!_home.stillAlive()) {
            return null;
        }
        return _home.get() as HomeMenu?;
    }

}
