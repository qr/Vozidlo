import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Entry point for the on-device settings reached from home (US-061): a
// NightMenu with the tile order (ui/TileOrderView.mc), the confirmation
// before a command (US-062) and "Clear stored data" (US-007), which up to
// 1.2 was only reachable before setup.
module SettingsScreen {

    // A drill-in from a home row, so it slides in from the right (B6).
    function open() as Void {
        var menu = new NightMenu("Settings", 0, null);
        menu.addItem(new NightMenuItem(:tileOrder, "Tile order", null, null, null));
        // Garmin Connect calls it "Confirm commands"; in the focused pill
        // that is cut with "…" on every watch (PoC set-menu, fitcheck), so
        // the row is "Confirmation" with the value as a word under it.
        menu.addItem(new NightMenuItem(:confirmCommands, "Confirmation",
            confirmCommandsSub(getApp().getSettings().confirmCommands), null, null));
        menu.addItem(new NightMenuItem(:clearData,
            WatchUi.loadResource(Rez.Strings.OnboardingMenuClearData) as String, null, null, null));
        WatchUi.pushView(menu, new SettingsMenuDelegate(menu), Theme.SLIDE_IN);
    }

    // Writes the property Garmin Connect edits, so the phone shows what the
    // watch set. A write from inside the app does not trigger
    // onSettingsChanged() (TemperatureMenuDelegate has the same note), so it
    // is called here: the next command reads the new Config. Returns the new
    // value.
    function toggleConfirmCommands() as Boolean {
        var on = !getApp().getSettings().confirmCommands;
        Properties.setValue("ConfirmCommands", on);
        getApp().onSettingsChanged();
        return on;
    }

    function confirmCommandsSub(on as Boolean) as String {
        return on ? "On" : "Off";
    }

    function openTileOrder() as Void {
        var view = new TileOrderView();
        WatchUi.pushView(view, new TileOrderDelegate(view), Theme.SLIDE_IN);
    }

}

// The menu stays up on select (popOnSelect false): the tile order is a
// drill-in, "Confirmation" switches in place, and "No" on the clear-data
// confirmation returns to this list.
class SettingsMenuDelegate extends NightMenuDelegate {

    // Weak: the menu owns this delegate (docs/best-practices "Break
    // reference cycles").
    private var _menu as WeakReference;

    function initialize(menu as NightMenu) {
        NightMenuDelegate.initialize(false);
        _menu = menu.weak();
    }

    function onPick(id as Object?) as Void {
        if (id == :tileOrder) {
            SettingsScreen.openTileOrder();
        } else if (id == :confirmCommands) {
            _showConfirmCommands(SettingsScreen.toggleConfirmCommands());
        } else if (id == :clearData) {
            // US-007: erases the key, so it is confirmed first, the same
            // dialog as in onboarding.
            var dialog = new WatchUi.Confirmation(
                WatchUi.loadResource(Rez.Strings.OnboardingClearConfirmMessage) as String
            );
            WatchUi.pushView(dialog, new SettingsClearConfirmDelegate(), Theme.SLIDE_DIALOG);
        }
    }

    // Updates the row in place, so the focus stays on it.
    function _showConfirmCommands(on as Boolean) as Void {
        var menu = _menu.get() as NightMenu?;
        if (menu == null) {
            return;
        }
        var index = menu.findItemById(:confirmCommands);
        var row = index >= 0 ? menu.itemAt(index) : null;
        if (row != null) {
            row.setSub(SettingsScreen.confirmCommandsSub(on));
        }
        WatchUi.requestUpdate();
    }

}

// "Yes" erases everything (StoredData.clearAll()) and closes the app: with
// no key left, the next start opens onboarding (OnboardingGate). Closing
// rather than switching to onboarding from here, under home and this menu,
// keeps the view stack out of it: a switch made while the confirmation is
// still being dismissed can land under it.
class SettingsClearConfirmDelegate extends WatchUi.ConfirmationDelegate {

    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(value as WatchUi.Confirm) as Boolean {
        if (value == WatchUi.CONFIRM_YES) {
            StoredData.clearAll();
            System.exit();
        }
        return true;
    }

}
