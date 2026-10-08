import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.WatchUi;

// US-024: PUT /vehicles/{vin}/charging/limit, as a list of exactly
// ChargingLogic.limitChoices() (50-100 in tens, never the schema's full
// 1-100). Replaces the old UP/DOWN stepper (B6 "charge limit as a Menu2 of
// 6 values", PoC NC.limitMenu): a list shows every allowed value at once
// and needs no picker-specific key mapping.
module ChargingLimitMenu {

    // `current` is settings.targetStateOfChargeInPercent as last seen by
    // ChargingDetailView (cached or freshly fetched); `careTarget` is
    // batteryCareModeTargetValueInPercent, or null when the car has never
    // reported one: both are read-only inputs, this menu never re-fetches
    // them itself.
    function build(current as Number?, careTarget as Number?) as NightMenu {
        var choices = ChargingLogic.limitChoices();
        var menu = new NightMenu("Charge limit", ChargingLogic.limitIndexFor(current), null);
        for (var i = 0; i < choices.size(); i += 1) {
            var value = choices[i];
            // Single-choice rows (check column) only when the car told us
            // its limit; otherwise no row may claim to be the current one.
            var checked = (current != null) ? (value == current) : null;
            menu.addItem(new NightMenuItem(value, value.toString() + "%",
                ChargingLogic.isRecommended(value, careTarget) ? "Recommended" : null, null, checked));
        }
        return menu;
    }

    function push(detail as ChargingDetailView, current as Number?, careTarget as Number?) as Void {
        WatchUi.pushView(build(current, careTarget), new ChargingLimitMenuDelegate(detail), Theme.SLIDE_IN);
    }

}

// Picking a value pops this menu first (NightMenuDelegate(true), A14) so
// the confirmation, when ConfirmationPolicy shows one, lands on the detail
// screen, and every outcome is reported there via setStatus(): the send,
// prompt, body and response handling are the old ChargingLimitView's
// (ChargingLimitView.mc:108-171 before the Night Panel), only the place the
// result appears moved.
class ChargingLimitMenuDelegate extends NightMenuDelegate {

    private var _detail as WeakReference;
    private var _sending as Boolean = false;
    private var _value as Number = 0;

    function initialize(detail as ChargingDetailView) {
        NightMenuDelegate.initialize(true);
        _detail = detail.weak();
    }

    function onPick(id as Object?) as Void {
        if (id instanceof Number) {
            send(id as Number);
        }
    }

    // Same disabled-preconditions as Refresh (US-040/US-045, Refusal).
    // The menu has already closed (A14), so a refused pick says why in a
    // toast instead of doing nothing visible; a spent quota also stays on
    // the detail screen's status line, which has no quota bar of its own.
    // A second pick while one is on its way stays silent, as on home.
    function send(value as Number) as Void {
        var verdict = Refusal.current(_sending);
        if (verdict != :ok) {
            var text = Refusal.commandText(verdict, Quota.secondsUntilReset());
            Refusal.toast(text);
            if (verdict == :quota && text != null) {
                _report(text, true);
            }
            return;
        }
        _value = value;
        // US-024 carries no explicit "always confirm" entry in
        // ConfirmationPolicy's table: it is reversible and low-stakes like
        // the climate/charging start commands, so ConfirmationPolicy.run()
        // sends it immediately unless the quota is nearly spent, exactly the
        // same rule every other command in this app follows. Never a second,
        // hand-rolled confirmation here.
        ConfirmationPolicy.run(ConfirmationPolicy.SET_CHARGE_LIMIT, "Set limit to " + value.toString() + "%?",
            method(:_sendLimit), method(:_announceSent));
    }

    function _sendLimit() as Void {
        _sending = true;
        var settings = getApp().getSettings();
        var body = { "targetStateOfChargeInPercent" => _value } as Dictionary<Object, Object>;
        ApiClient.setChargingLimit(settings.vin, body, settings.apiKey, method(:_onCommandResponse));
    }

    // US-024/the task's KEY CONSTRAINT: this command omits :responseType, so
    // any error (a real 422 included) comes back as a negative transport
    // code with the problem+json body unreadable (see ApiClient.mc). That
    // still means the car refused this limit; it never means "we don't know
    // what happened", so this is worded as a refusal, not a generic failure,
    // and never claims to know the specific reason.
    function _onCommandResponse(responseCode as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        _sending = false;

        if (responseCode >= 200 && responseCode < 300) {
            Quota.recordHeaders(null, null, null);
            // One read 15 s later says whether the car took it (CommandCheck).
            var detail = _detail.get() as ChargingDetailView?;
            if (detail != null && CommandCheck.startIfAllowed(ConfirmationPolicy.SET_CHARGE_LIMIT, _value, detail)) {
                _report(CommandCheck.CHECKING, false);
            }
            WatchUi.requestUpdate();
            return;
        }

        var body = (data instanceof Dictionary) ? (data as Dictionary) : null;
        if (responseCode == 429) {
            var problemType = (body != null) ? (body.get("type") as String?) : null;
            Quota.recordRateLimited(problemType, null);
        }
        _report(Commands.failureText(responseCode, ProblemDetail.describe(responseCode, body, Quota.retryAfterUntil()).text), true);
    }

    function _announceSent() as Void {
        _report(Commands.SENT, false);
    }

    function _report(message as String, isError as Boolean) as Void {
        if (!_detail.stillAlive()) {
            return;
        }
        var detail = _detail.get() as ChargingDetailView?;
        if (detail != null) {
            detail.setStatus(message, isError);
        }
    }

}
