import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.WatchUi;

// US-003's guidance screen, and: when settings are syntactically present
// but this exact key has never had a successful request: the "on first
// request" validator US-002 asks for. Both live in one class because they
// share almost everything: the layout, the "Clear stored data" escape
// hatch, and (for the validating case) the transient-error sub-state. See
// ui/OnboardingGate.mc for what decides which mode a launch starts in.
//
// Never looks like an error or a crash (US-003): even the validating and
// failed-but-not-onboarding's-concern states read as plain, calm text, not
// a red banner or a stack trace.
class OnboardingView extends WatchUi.View {

    // true: settings are syntactically fine and this key has never
    // validated, so onShow() fires the one validating request US-002 asks
    // for. false: nothing to check yet (US-003). Key/VIN missing, or the
    // VIN fails Settings.isVinValid().
    private var _validating as Boolean;
    // Set only when a validation attempt failed for a reason onboarding
    // does not have a dedicated screen for (e.g. the quota is spent, the
    // phone is unreachable, a 5xx): shown in place with a manual retry.
    // US-002: "never retry automatically". This is that rule enforced by
    // construction: nothing here re-fires the request without a select
    // press reaching retry() below.
    private var _transientError as String?;

    function initialize(validating as Boolean) {
        View.initialize();
        _validating = validating;
        _transientError = null;
    }

    // No setLayout() here. These messages are whole sentences, and
    // WatchUi.Text does not wrap: :width bounds justification, not layout,
    // so the string was drawn as one line running off both edges of the
    // round face. ui/TextBlock.mc wraps it to the width actually available
    // at each line's height instead. Nothing is loaded here that onUpdate()
    // would otherwise reload, so the best-practices rule about keeping
    // resource loading out of onUpdate() is not in play: the only per-frame
    // work is arithmetic over a string we already hold.
    function onLayout(dc as Dc) as Void {
    }

    // The validating request is fired from onShow(), not onLayout() or the
    // constructor: it is I/O, not resource loading, and must only happen
    // once this screen is actually the one on top.
    function onShow() as Void {
        if (_validating && _transientError == null) {
            _startValidation();
        }
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        TextBlock.draw(dc, _bodyText(), Graphics.FONT_XTINY, Graphics.COLOR_WHITE);
    }

    // A manual retry only: called by OnboardingDelegate's onSelect() while
    // a transient error is showing. Never called from within
    // _onValidationResponse() itself.
    function retry() as Void {
        _transientError = null;
        _refreshText();
        _startValidation();
    }

    // Guidance mode's primary action: push go.skoda.eu/api-keys to the
    // phone browser. Fire-and-forget, no callback: Communications.
    // openWebPage() offers none, so this never blocks or gates anything
    // else on the page having actually opened.
    function openKeyPage() as Void {
        Communications.openWebPage(WatchUi.loadResource(Rez.Strings.OnboardingKeyPageUrl) as String, null, null);
    }

    function isValidating() as Boolean {
        return _validating;
    }

    function hasTransientError() as Boolean {
        return _transientError != null;
    }

    function _bodyText() as String {
        if (_transientError != null) {
            return _transientError as String;
        }
        if (_validating) {
            return WatchUi.loadResource(Rez.Strings.OnboardingCheckingMessage) as String;
        }
        return WatchUi.loadResource(Rez.Strings.OnboardingGuidanceMessage) as String;
    }

    // onUpdate() reads _bodyText() directly, so changing the state is the
    // whole of "refresh the text"; this only has to ask for a redraw.
    function _refreshText() as Void {
        WatchUi.requestUpdate();
    }

    // US-002: validation is "nearly free" (401/403 don't consume quota) but
    // a SUCCESS does, at the same cost as any other read, so this checks
    // the app's own quota estimate first rather than spending it on a
    // request that would only report back what Quota.mc already knows.
    function _startValidation() as Void {
        if (!Quota.canSpend()) {
            // Nothing new to learn from spending the request just to be
            // told the same thing Quota.mc already knows locally, and a
            // 429 here would look identical to a real one anyway.
            _transientError = WatchUi.loadResource(Rez.Strings.OnboardingQuotaBlockedMessage) as String;
            _refreshText();
            return;
        }
        var settings = getApp().getSettings();
        // include=status: this call exists to validate the key/VIN pair,
        // not to fetch a screen's worth of data: same quota cost either
        // way (see mock/README.md), less to receive and discard.
        ApiClient.getVehicle(settings.vin, "status", settings.apiKey, method(:_onValidationResponse));
    }

    function _onValidationResponse(responseCode as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        var settings = getApp().getSettings();

        if (responseCode >= 200 && responseCode < 300) {
            // US-004: the only place a key's estimated start date is ever
            // set: the first successful request, exactly as the story
            // asks for.
            KeyLifetime.recordSuccess(settings.apiKey);
            var controls = new ControlsView();
            WatchUi.switchToView(controls, new ControlsDelegate(controls), WatchUi.SLIDE_IMMEDIATE);
            return;
        }

        var body = (data instanceof Dictionary) ? data as Dictionary : null;
        var blocked = Onboarding.viewForProblem(responseCode, body);
        if (blocked != null) {
            WatchUi.switchToView(blocked, new OnboardingDelegate(blocked), WatchUi.SLIDE_IMMEDIATE);
            return;
        }

        // Not one of onboarding's four causes (e.g. a spent quota, the
        // phone unreachable, a 5xx): ProblemDetail already has a good
        // message for it; show it in place with a manual retry rather than
        // inventing a second copy of that wording.
        var message = ProblemDetail.describe(responseCode, body, null);
        _transientError = message.text;
        _refreshText();
    }

}
