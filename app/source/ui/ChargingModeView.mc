import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.WatchUi;

// US-025: PUT /vehicles/{vin}/charging/mode. Offers ONLY
// settings.availableChargeModes (never the full documented enum) because
// our reference vehicle proves operations[] alone is not a guarantee (see
// docs/requirements.md, US-025). ChargingDetailView.openMode() already
// refuses to push this menu at all when that array is empty (US-025's "hide
// the action entirely"); this file only ever renders whatever it is handed,
// so there is exactly one place that decision is made.
module ChargingModeMenu {

    // Single-choice NightMenu (B6, PoC NC.mode): a check on the mode the
    // car reports, focus starting there.
    function build(modes as Array<String>, currentMode as String?) as NightMenu {
        var focus = 0;
        for (var i = 0; i < modes.size(); i += 1) {
            if (currentMode != null && (modes[i] as String).equals(currentMode)) {
                focus = i;
            }
        }
        var menu = new NightMenu("Charge mode", focus, null);
        for (var i = 0; i < modes.size(); i += 1) {
            var mode = modes[i] as String;
            var current = currentMode != null && mode.equals(currentMode);
            // The mode string itself is the item id: a plain String is as
            // comparable as a Symbol (see ChargingActionMenuDelegate).
            menu.addItem(new NightMenuItem(mode, Labels.mode(mode), null, null, current));
        }
        return menu;
    }

}

// Picking a mode pops this menu first (NightMenuDelegate(true), A14) and
// reports the result on ChargingDetailView via setStatus(), since the menu
// is gone by the time "Command sent" or a refusal arrives.
class ChargingModeMenuDelegate extends NightMenuDelegate {

    private var _detail as WeakReference;
    private var _sending as Boolean = false;
    private var _pendingMode as String? = null;

    function initialize(detail as ChargingDetailView) {
        NightMenuDelegate.initialize(true);
        _detail = detail.weak();
    }

    function onPick(id as Object?) as Void {
        if (_sending) {
            return;
        }
        if (!(id instanceof String)) {
            return;
        }
        var mode = id as String;
        if (_refused()) {
            return;
        }

        _pendingMode = mode;
        _sending = true;
        // US-025 carries no "always confirm" entry in ConfirmationPolicy's
        // table (same reasoning as the charge limit, see
        // ChargingLimitMenuDelegate.send()): ConfirmationPolicy.run() still
        // owns whether a dialog appears at all (only when the quota is nearly
        // spent). Never a second, hand-rolled confirmation here.
        ConfirmationPolicy.run(ConfirmationPolicy.SET_CHARGE_MODE, "Set mode to " + Labels.mode(mode) + "?",
            method(:_send), method(:_announceSent));
    }

    function _send() as Void {
        var mode = _pendingMode;
        if (mode == null) {
            return;
        }
        var settings = getApp().getSettings();
        var body = { "chargeMode" => mode } as Dictionary<Object, Object>;
        ApiClient.setChargeMode(settings.vin, body, settings.apiKey, method(:_onCommandResponse));
    }

    // Called once send() has actually fired (ConfirmationPolicy.run()'s own
    // contract). The menu already popped on the pick, so only the report.
    function _announceSent() as Void {
        _report(Commands.SENT, false);
    }

    // The menu has already closed (A14), so a refused pick says why in a
    // toast instead of doing nothing visible (Refusal, the same checks as
    // Refresh). The detail screen no longer has a top bar showing quota
    // state, so a spent quota also stays on its status line.
    function _refused() as Boolean {
        var verdict = Refusal.current(false);
        if (verdict == :ok) {
            return false;
        }
        var text = Refusal.commandText(verdict, Quota.secondsUntilReset());
        Refusal.toast(text);
        if (verdict == :quota && text != null) {
            _report(text, true);
        }
        return true;
    }

    // The task's KEY CONSTRAINT: this command omits :responseType, so any
    // error comes back as a negative transport code with the problem+json
    // body unreadable (see ApiClient.mc): that still means the car refused
    // this mode, so it is worded as a refusal, never a generic failure, and
    // never claims to know the specific reason.
    function _onCommandResponse(responseCode as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        _sending = false;
        if (responseCode >= 200 && responseCode < 300) {
            Quota.recordHeaders(null, null, null);
            // One read 15 s later says whether the car took it (CommandCheck).
            var detail = _detail.get() as ChargingDetailView?;
            if (detail != null && CommandCheck.startIfAllowed(ConfirmationPolicy.SET_CHARGE_MODE, _pendingMode, detail)) {
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
