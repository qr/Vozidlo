import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// US-004's non-blocking notice: shown once per launch when the current key
// is estimated (never asserted as fact) to be close to expiring. Unlike
// OnboardingBlockedView, dismissing this always proceeds into the app:
// "non-blocking" means exactly that, not merely "not an error screen".
class OnboardingExpiryNoticeView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    // Wrapped by ui/TextBlock.mc rather than laid out with WatchUi.Text,
    // which does not wrap, see that file's header. Note the resource is
    // loaded here, not referenced as a Rez symbol: the old code passed
    // Rez.Strings.OnboardingExpiryNoticeMessage straight into a drawable,
    // which resolves at layout time, but TextBlock.draw() takes a String.
    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var text = WatchUi.loadResource(Rez.Strings.OnboardingExpiryNoticeMessage) as String;
        TextBlock.draw(dc, text, Graphics.FONT_XTINY, Graphics.COLOR_WHITE);
    }

}
