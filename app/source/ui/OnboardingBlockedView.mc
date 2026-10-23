import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// US-002/US-004's blocking screens: an expired key (with the exact date),
// a key not authorised for this VIN, an unknown VIN, or our own routing
// bug: one class because all four are "stop here, this is why, here is
// what to do" with only the message text differing. See
// ui/OnboardingGate.mc.viewForProblem() for which text each cause gets.
//
// Blocking, but never automatic: getting past this screen means fixing the
// key/VIN on the phone and pressing select to retry (US-002: "never retry
// automatically"). MENU opens the onboarding menu, shown as the menu glyph
// (Bezel.menuGlyph, M9) instead of the old "Menu for more." (C7). No check
// at START: a retry spends quota, so it is not advertised, and a tap does
// nothing (OnboardingDelegate.onTap).
class OnboardingBlockedView extends WatchUi.View {

    private var _screen as OnboardingText;
    // Whether Garmin's action menu indicator stands in for MENU here
    // (Input.enableIndicator); the text keeps clear of it while it shows.
    private var _indicator as Boolean;

    // The text arrives as a String already built by OnboardingGate, so
    // nothing is loaded here or in onUpdate() (A22).
    function initialize(text as String) {
        View.initialize();
        _screen = new OnboardingText();
        _screen.set(text, true, false);
        _indicator = Input.enableIndicator(self);
    }

    function onLayout(dc as Dc) as Void {
    }

    // Monochrome flag cached per onShow (A21); the keep-out again after
    // the onboarding menu, which clears it, pops.
    function onShow() as Void {
        Theme.refresh();
        Geo.setKeepOut(_indicator);
    }

    // Wrapped by OnboardingText rather than laid out with WatchUi.Text,
    // which does not wrap.
    function onUpdate(dc as Dc) as Void {
        _screen.draw(dc);
    }

}
