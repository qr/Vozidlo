import Toybox.Lang;
import Toybox.WatchUi;

// Input profile of this watch (Geo.INPUT_A / _B / _C) and Garmin's action
// menu indicator, the stand-in for MENU on watches without that key
// (profile C: vívoactive 6, Venu 4 41 / 45 mm, Venu X1).
//
// View.setActionMenuIndicator and BehaviorDelegate.onActionMenu are API
// 5.1.1, above our minApiLevel of 5.1.0, and only the profile C watches
// implement them anyway, so every call is guarded with `has`. A view that enables
// the indicator also calls Geo.setKeepOut(true) in onShow, so text stays
// clear of it; NightMenu clears the keep-out again.
module Input {

    function profile() as Number {
        return Geo.current().input;
    }

    // Shows the indicator on this view when the watch has no MENU key and
    // the firmware supports it. Returns whether it is shown, which is what
    // the view passes to Geo.setKeepOut().
    function enableIndicator(view as WatchUi.View) as Boolean {
        return setIndicator(view, true);
    }

    // Turns the indicator on or off (a map in browse mode wants it off).
    // Returns whether it is now shown.
    function setIndicator(view as WatchUi.View, on as Boolean) as Boolean {
        if (profile() != Geo.INPUT_C) {
            return false;
        }
        if (view has :setActionMenuIndicator) {
            view.setActionMenuIndicator({:enabled => on});
            return on;
        }
        return false;
    }

}
