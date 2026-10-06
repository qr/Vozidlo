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
// automatically").
class OnboardingBlockedView extends WatchUi.View {

    private var _text as String;

    function initialize(text as String) {
        View.initialize();
        _text = text;
    }

    function onLayout(dc as Dc) as Void {
    }

    // Wrapped by ui/TextBlock.mc rather than laid out with WatchUi.Text,
    // which does not wrap, see that file's header.
    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        TextBlock.draw(dc, _text, Graphics.FONT_XTINY, Graphics.COLOR_WHITE);
    }

}
