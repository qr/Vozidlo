import Toybox.Lang;
import Toybox.WatchUi;

// Entry point for Find my car (US-028): the Night Panel LocationView (C5).
module FindMyCarScreen {

    // A drill-in from a home row, so it slides in from the right (B6).
    function open() as Void {
        var location = new LocationView();
        WatchUi.pushView(location, new LocationDelegate(location), Theme.SLIDE_IN);
    }

}
