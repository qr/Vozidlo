import Toybox.Lang;
import Toybox.WatchUi;

// US-007's confirmed half of "Clear stored data": erases everything
// StoredData.clearAll() lists (key, VIN, S-PIN, cache, quota, key start
// date, last parked position, parking flag, tile order, the saved
// waypoint), then returns to the guidance screen. Preferences such as
// TemperatureUnit stay: they say nothing about the user or the car.
class OnboardingClearConfirmDelegate extends WatchUi.ConfirmationDelegate {

    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(value as WatchUi.Confirm) as Boolean {
        if (value != WatchUi.CONFIRM_YES) {
            return true;
        }

        StoredData.clearAll();

        // A Properties write made from inside the app: as opposed to a
        // phone-side edit synced in: does not trigger the system's
        // onSettingsChanged() on its own, so it is called directly here.
        // This is calling VozidloApp's existing public lifecycle method, not
        // adding anything new to that file.
        getApp().onSettingsChanged();

        var guidance = new OnboardingView(false);
        WatchUi.switchToView(guidance, new OnboardingDelegate(guidance), WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

}
