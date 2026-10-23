import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// US-004's non-blocking notice: shown once per launch when the current key
// is estimated (never asserted as fact) to be close to expiring. Unlike
// OnboardingBlockedView, dismissing this always proceeds into the app:
// "non-blocking" means exactly that, not merely "not an error screen".
// START (or a tap) continues: a check glyph with the accent arc at START
// replaces the old "Select to continue." (C7). MENU still opens the
// onboarding menu, but no menu glyph says so: the way on here is START.
class OnboardingExpiryNoticeView extends WatchUi.View {

    private var _screen as OnboardingText;
    // Whether Garmin's action menu indicator stands in for MENU here
    // (Input.enableIndicator); the text keeps clear of it while it shows.
    private var _indicator as Boolean;

    function initialize() {
        View.initialize();
        _screen = new OnboardingText();
        _indicator = Input.enableIndicator(self);
    }

    function onLayout(dc as Dc) as Void {
    }

    // The string is loaded here, not in onUpdate() (A22, docs/best-practices
    // "Never load resources inside onUpdate()"); OnboardingText keeps the
    // wrapped layout until the text changes.
    function onShow() as Void {
        Theme.refresh();
        Geo.setKeepOut(_indicator);
        _screen.set(WatchUi.loadResource(Rez.Strings.OnboardingExpiryNoticeMessage) as String, false, true);
    }

    function onUpdate(dc as Dc) as Void {
        _screen.draw(dc);
    }

}
