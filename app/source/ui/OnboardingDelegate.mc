import Toybox.Lang;
import Toybox.WatchUi;

// Shared input handling for every onboarding-family screen (US-002,
// US-003, US-004, US-007): OnboardingView (guidance/validating),
// OnboardingBlockedView (a validation failure) and
// OnboardingExpiryNoticeView (the 159-day estimate). One delegate rather
// than one per view, because the three screens differ only in what select
// does (open the key page, retry, or continue) and the Menu2 escape
// hatches are identical everywhere. BehaviorDelegate, not InputDelegate,
// per docs/best-practices/garmin-connect-iq.md; back is left untouched, so
// there is no onBack() override here.
class OnboardingDelegate extends WatchUi.BehaviorDelegate {

    private var _view as WatchUi.View;

    function initialize(view as WatchUi.View) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // US-002: the only way a retry can ever happen. Never automatically.
    function onSelect() as Boolean {
        var view = _view;

        if (view instanceof OnboardingView) {
            var onboarding = view as OnboardingView;
            if (!onboarding.isValidating()) {
                // Guidance mode's primary action: offer the key page.
                onboarding.openKeyPage();
            } else if (onboarding.hasTransientError()) {
                // Validating mode: retry only once a transient error is
                // actually showing: a request already in flight must
                // never be fired a second time.
                onboarding.retry();
            }
            return true;
        }

        if (view instanceof OnboardingBlockedView) {
            // Hands off to OnboardingView's own validating flow rather
            // than duplicating the request logic here.
            var checking = new OnboardingView(true);
            WatchUi.switchToView(checking, new OnboardingDelegate(checking), WatchUi.SLIDE_IMMEDIATE);
            return true;
        }

        if (view instanceof OnboardingExpiryNoticeView) {
            // Non-blocking: select always proceeds into the app. There is
            // nothing here to retry, only to acknowledge.
            var controls = new ControlsView();
            WatchUi.switchToView(controls, new ControlsDelegate(controls), WatchUi.SLIDE_IMMEDIATE);
            return true;
        }

        return false;
    }

    // The two escape hatches every onboarding screen shares: US-007's
    // "Clear stored data" and US-003's link to go.skoda.eu/api-keys.
    function onMenu() as Boolean {
        OnboardingActionMenu.push();
        return true;
    }

}
