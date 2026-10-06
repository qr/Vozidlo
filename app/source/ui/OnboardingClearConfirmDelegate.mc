import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.WatchUi;

// US-007's confirmed half of "Clear stored data": erases the key, VIN,
// S-PIN, cache, quota counters and the recorded key start date, then
// returns to the guidance screen. TemperatureUnit is deliberately left
// alone: it is a preference, not identifying data, and US-007 only lists
// key, VIN, S-PIN and cached/quota state.
//
// Writes Properties directly rather than adding a writer to Settings.mc:
// that module's own header says it exists so Properties is only ever read
// through it, and a one-off "erase everything" doesn't belong in a module
// whose entire point is validating what a phone-side edit put there.
class OnboardingClearConfirmDelegate extends WatchUi.ConfirmationDelegate {

    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(value as WatchUi.Confirm) as Boolean {
        if (value != WatchUi.CONFIRM_YES) {
            return true;
        }

        Properties.setValue("ApiKey", "");
        Properties.setValue("Vin", "");
        Properties.setValue("Spin", "");

        Cache.clear();
        Quota.clear();
        KeyLifetime.clear();

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
