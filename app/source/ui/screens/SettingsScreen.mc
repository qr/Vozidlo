import Toybox.Lang;
import Toybox.WatchUi;

// Entry point for the on-device settings reached from home (US-061): the
// tile order, a NightMenu (ui/TileOrderView.mc).
module SettingsScreen {

    // A drill-in from a home row, so it slides in from the right (B6).
    function openTileOrder() as Void {
        var view = new TileOrderView();
        WatchUi.pushView(view, new TileOrderDelegate(view), Theme.SLIDE_IN);
    }

}
