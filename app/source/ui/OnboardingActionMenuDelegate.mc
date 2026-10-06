import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

// Handles the two items OnboardingActionMenu.push() builds.
class OnboardingActionMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
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
            WatchUi.pushView(dialog, new OnboardingClearConfirmDelegate(), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

}
