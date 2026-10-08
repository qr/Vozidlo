import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// US-004's non-blocking notice: shown once per launch when the current key
// is estimated (never asserted as fact) to be close to expiring. Unlike
// OnboardingBlockedView, dismissing this always proceeds into the app:
// "non-blocking" means exactly that, not merely "not an error screen".
// START continues: a check glyph with the accent arc at START replaces the
// old "Select to continue." (C7).
class OnboardingExpiryNoticeView extends WatchUi.View {

    private var _screen as OnboardingText;

    function initialize() {
        View.initialize();
        _screen = new OnboardingText();
    }

    function onLayout(dc as Dc) as Void {
    }

    // The string is loaded here, not in onUpdate() (A22, docs/best-practices
    // "Never load resources inside onUpdate()"); OnboardingText keeps the
    // wrapped layout until the text changes.
    function onShow() as Void {
        Theme.refresh();
        _screen.set(WatchUi.loadResource(Rez.Strings.OnboardingExpiryNoticeMessage) as String, :check);
    }

    function onUpdate(dc as Dc) as Void {
        _screen.draw(dc);
    }

}
