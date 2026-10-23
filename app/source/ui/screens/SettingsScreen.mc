import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Entry point for the on-device settings reached from home (US-061): a
// NightMenu with the tile order (ui/TileOrderView.mc) and "Clear stored
// data" (US-007), which up to 1.2 was only reachable before setup.
module SettingsScreen {

    // A drill-in from a home row, so it slides in from the right (B6).
    function open() as Void {
        var menu = new NightMenu("Settings", 0, null);
        menu.addItem(new NightMenuItem(:tileOrder, "Tile order", null, null, null));
        menu.addItem(new NightMenuItem(:clearData,
            WatchUi.loadResource(Rez.Strings.OnboardingMenuClearData) as String, null, null, null));
        WatchUi.pushView(menu, new SettingsMenuDelegate(), Theme.SLIDE_IN);
    }

    function openTileOrder() as Void {
        var view = new TileOrderView();
        WatchUi.pushView(view, new TileOrderDelegate(view), Theme.SLIDE_IN);
    }

}

// The menu stays up on select (popOnSelect false): the tile order is a
// drill-in, and "No" on the confirmation returns to this list.
class SettingsMenuDelegate extends NightMenuDelegate {

    function initialize() {
        NightMenuDelegate.initialize(false);
    }

    function onPick(id as Object?) as Void {
        if (id == :tileOrder) {
            SettingsScreen.openTileOrder();
        } else if (id == :clearData) {
            // US-007: erases the key, so it is confirmed first, the same
            // dialog as in onboarding.
            var dialog = new WatchUi.Confirmation(
                WatchUi.loadResource(Rez.Strings.OnboardingClearConfirmMessage) as String
            );
            WatchUi.pushView(dialog, new SettingsClearConfirmDelegate(), Theme.SLIDE_DIALOG);
        }
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
