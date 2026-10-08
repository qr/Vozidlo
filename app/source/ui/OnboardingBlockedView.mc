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
// automatically"). MENU (hold UP) opens the onboarding menu, shown as the
// menu glyph at UP instead of the old "Menu for more." (C7).
class OnboardingBlockedView extends WatchUi.View {

    private var _screen as OnboardingText;

    // The text arrives as a String already built by OnboardingGate, so
    // nothing is loaded here or in onUpdate() (A22).
    function initialize(text as String) {
        View.initialize();
        _screen = new OnboardingText();
        _screen.set(text, :menu);
    }

    function onLayout(dc as Dc) as Void {
    }

    // Monochrome flag cached per onShow (A21).
    function onShow() as Void {
        Theme.refresh();
    }

    // Wrapped by OnboardingText rather than laid out with WatchUi.Text,
    // which does not wrap.
    function onUpdate(dc as Dc) as Void {
        _screen.draw(dc);
    }

}
