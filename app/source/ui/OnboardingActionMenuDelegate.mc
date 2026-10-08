import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

// Handles the two items OnboardingActionMenu.push() builds. The menu stays
// up on select (popOnSelect false), as before: "Get a key" only hands a URL
// to the phone, and the clear-data confirmation returns to this menu on
// "No". BACK slides out to the right (NightMenuDelegate, A20).
class OnboardingActionMenuDelegate extends NightMenuDelegate {

    function initialize() {
        NightMenuDelegate.initialize(false);
    }

    function onPick(id as Object?) as Void {
        if (id == :openKeyPage) {
            // Fire-and-forget: openWebPage() takes no callback, so nothing
            // downstream may ever depend on this having worked (US-003).
            Communications.openWebPage(WatchUi.loadResource(Rez.Strings.OnboardingKeyPageUrl) as String, null, null);
            return;
        }
        if (id == :clearData) {
            // US-007: real consequences (erases the key), so it gets a
            // confirmation rather than acting immediately, see
            // docs/best-practices/garmin-connect-iq.md, "Confirm only when
            // the friction is warranted."
            var dialog = new WatchUi.Confirmation(
                WatchUi.loadResource(Rez.Strings.OnboardingClearConfirmMessage) as String
            );
            WatchUi.pushView(dialog, new OnboardingClearConfirmDelegate(), Theme.SLIDE_DIALOG);
        }
    }

}
