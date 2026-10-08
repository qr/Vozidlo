import Toybox.Lang;
import Toybox.WatchUi;

// Entry point for charging detail (US-023); other packages open the
// Night Panel charging screen (ChargingDetailView, PoC NC.detail) only
// through here.
module ChargingScreen {

    // Pushed from above, matching UP on home (B6 transitions).
    function open() as Void {
        var detail = new ChargingDetailView();
        WatchUi.pushView(detail, new ChargingDetailDelegate(detail), Theme.SLIDE_CHARGING);
    }

}
