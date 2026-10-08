import Toybox.Lang;
import Toybox.WatchUi;

// Entry point for the status pages (US-036 "one press below"): the own pager
// (D7 dots, D4 action list) from ui/StatusPager.mc.
module StatusScreen {

    // Pushed from below, matching DOWN on home (B6 transitions); always
    // starts at the lock page.
    function open() as Void {
        var pager = new StatusPager("status");
        WatchUi.pushView(new StatusPageView(pager), new StatusPageDelegate(pager), Theme.SLIDE_STATUS);
    }

}
