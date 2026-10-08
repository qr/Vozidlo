import Toybox.Lang;
import Toybox.WatchUi;

// The menu shared by every onboarding screen (US-003, US-007): "Get a key"
// (opens go.skoda.eu/api-keys on the phone) and "Clear stored data" (behind
// a confirmation, see OnboardingClearConfirmDelegate.mc). One place to build
// it so every onboarding screen opens the same list. A NightMenu like every
// other list in the app (B6 "Menus"), pushed as a drill-in (A20).
module OnboardingActionMenu {

    function push() as Void {
        var menu = new NightMenu(WatchUi.loadResource(Rez.Strings.OnboardingMenuTitle) as String, 0, null);
        menu.addItem(new NightMenuItem(:openKeyPage,
            WatchUi.loadResource(Rez.Strings.OnboardingMenuOpenKeyPage) as String, null, null, null));
        menu.addItem(new NightMenuItem(:clearData,
            WatchUi.loadResource(Rez.Strings.OnboardingMenuClearData) as String, null, null, null));
        WatchUi.pushView(menu, new OnboardingActionMenuDelegate(), Theme.SLIDE_IN);
    }

}
