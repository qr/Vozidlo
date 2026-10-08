import Toybox.Lang;
import Toybox.WatchUi;

// Entry points for the home screen, so other screens and the onboarding never
// construct its classes directly (plan: "packages never call each other's
// classes"). Home is the Night Panel hero list (ui/HomeMenu.mc).
module HomeScreen {

    // What getInitialView() returns once the onboarding gate is passed
    // (US-036: land on the controls).
    function view() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var home = new HomeMenu();
        return [ home, new HomeDelegate(home) ];
    }

    // Replaces the current screen with home, e.g. at the end of onboarding;
    // a switch, not a push, so BACK from home still leaves the app.
    function switchTo() as Void {
        var home = new HomeMenu();
        WatchUi.switchToView(home, new HomeDelegate(home), Theme.SLIDE_DIALOG);
    }

}
