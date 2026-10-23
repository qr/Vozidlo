import Toybox.Lang;
import Toybox.WatchUi;

// Shared input handling for every onboarding-family screen (US-002,
// US-003, US-004, US-007): OnboardingView (guidance/validating),
// OnboardingBlockedView (a validation failure) and
// OnboardingExpiryNoticeView (the 159-day estimate). One delegate rather
// than one per view, because the three screens differ only in what select
// does (open the key page, retry, or continue) and the menu escape
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
            HomeScreen.switchTo();
            return true;
        }

        return false;
    }

    // A tap does what START does only where that is free: guidance opens
    // the key page, the expiry notice continues home. On the check (with or
    // without an error) and on a blocked key START retries, which spends
    // quota, so a tap there is consumed and does nothing; consuming it also
    // keeps it from arriving as onSelect() (A15). The state comes from the
    // view this delegate was made for, as in onSelect().
    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var view = _view;
        if (view instanceof OnboardingView) {
            var onboarding = view as OnboardingView;
            if (!onboarding.isValidating()) {
                onboarding.openKeyPage();
            }
        } else if (view instanceof OnboardingExpiryNoticeView) {
            HomeScreen.switchTo();
        }
        return true;
    }

    // The two escape hatches every onboarding screen shares: US-007's
    // "Clear stored data" and US-003's link to go.skoda.eu/api-keys.
    function onMenu() as Boolean {
        OnboardingActionMenu.push();
        return true;
    }

    // Watches without MENU (profile C) open the same list from Garmin's
    // action menu indicator; never called on the others.
    function onActionMenu() as Boolean {
        return onMenu();
    }

}
