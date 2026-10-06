import Toybox.Lang;
import Toybox.WatchUi;

// The Menu2 shared by every onboarding screen (US-003, US-007): "Get a key"
// (opens go.skoda.eu/api-keys on the phone) and "Clear stored data" (behind
// a confirmation, see OnboardingClearConfirmDelegate.mc). One place to build
// it so OnboardingDelegate, OnboardingBlockedDelegate and
// OnboardingExpiryNoticeDelegate don't each carry their own copy.
module OnboardingActionMenu {

    function push() as Void {
        var menu = new WatchUi.Menu2({
            :title => WatchUi.loadResource(Rez.Strings.OnboardingMenuTitle) as String
        });
        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.OnboardingMenuOpenKeyPage) as String, null, :openKeyPage, null
        ));
        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.OnboardingMenuClearData) as String, null, :clearData, null
        ));
        WatchUi.pushView(menu, new OnboardingActionMenuDelegate(), WatchUi.SLIDE_UP);
    }

}
