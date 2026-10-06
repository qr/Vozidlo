import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.WatchUi;

// US-025: PUT /vehicles/{vin}/charging/mode. Offers ONLY
// settings.availableChargeModes (never the full documented enum) because
// our reference vehicle proves operations[] alone is not a guarantee (see
// docs/requirements.md, US-025). ChargingDetailView.
// openMode() already refuses to push this menu at all when that array is
// empty (US-025's "hide the action entirely"); this file only ever renders
// whatever it is handed, so there is exactly one place that decision is
// made.
module ChargingModeMenu {

    function build(modes as Array<String>, currentMode as String?) as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({ :title => "Charge mode" });
        for (var i = 0; i < modes.size(); i += 1) {
            var mode = modes[i] as String;
            var subLabel = (currentMode != null && mode.equals(currentMode)) ? "Current" : null;
            // The mode string itself is the MenuItem id, see
            // ChargingActionMenuDelegate's own comment on why a plain
            // String, not a Symbol, is used as an identifier here.
            menu.addItem(new WatchUi.MenuItem(ChargingLogic.modeLabel(mode), subLabel, mode, null));
        }
        return menu;
    }

}

// Selecting a mode pops this menu back to ChargingDetailView and reports the
// result there (ChargingDetailView.setStatus()) rather than on this
// transient screen, since a Menu2 selection closes the menu immediately:
// there is nowhere on THIS screen left to show "Command sent" or a refusal
// by the time either arrives.
class ChargingModeMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _detail as WeakReference;
    private var _sending as Boolean = false;
    private var _pendingMode as String? = null;

    function initialize(detail as ChargingDetailView) {
        Menu2InputDelegate.initialize();
        _detail = detail.weak();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        if (_sending) {
            return;
        }
        var mode = item.getId() as String?;
        if (mode == null) {
            return;
        }
        if (!(System.getDeviceSettings().phoneConnected)) {
            return;
        }
        if (!Quota.canSpend()) {
            return; // the detail screen's own top bar already surfaces quota state
        }
        var settings = getApp().getSettings();
        if (!settings.vinValid || settings.apiKey.length() == 0) {
            return;
        }

        _pendingMode = mode;
        _sending = true;
        // US-025 carries no "always confirm" entry in ConfirmationPolicy's
        // table (same reasoning as the charge limit, see
        // ChargingLimitView.send()): ConfirmationPolicy.run() still owns
        // whether a dialog appears at all (only when the quota is nearly
        // spent). Never a second, hand-rolled confirmation here.
        ConfirmationPolicy.run(ConfirmationPolicy.SET_CHARGE_MODE, "Set mode to " + ChargingLogic.modeLabel(mode) + "?",
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
    // contract): pop back to the detail screen and say so there, since this
    // menu is on its way out either way.
    function _announceSent() as Void {
        var detail = _resolve();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        if (detail != null) {
            detail.setStatus("Command sent", false);
        }
    }

    // The task's KEY CONSTRAINT: this command omits :responseType, so any
    // error comes back as a negative transport code with the problem+json
    // body unreadable (see ApiClient.mc): that still means the car refused
    // this mode, so it is worded as a refusal, never a generic failure, and
    // never claims to know the specific reason. Arrives after this menu has
    // already popped (see _announceSent() above), so it is reported on the
    // detail screen via the same weak reference, not on this one.
    function _onCommandResponse(responseCode as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        _sending = false;
        if (responseCode >= 200 && responseCode < 300) {
            Quota.recordHeaders(null, null, null);
            return;
        }
        var body = (data instanceof Dictionary) ? (data as Dictionary) : null;
        if (responseCode == 429) {
            var problemType = (body != null) ? (body.get("type") as String?) : null;
            Quota.recordRateLimited(problemType, null);
        }
        var detail = _resolve();
        if (detail != null) {
            detail.setStatus("Vehicle refused: " + _shorten(ProblemDetail.describe(responseCode, body, Quota.retryAfterUntil()).text), true);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function _resolve() as ChargingDetailView? {
        if (!_detail.stillAlive()) {
            return null;
        }
        return _detail.get() as ChargingDetailView?;
    }

    function _shorten(text as String) as String {
        if (text.length() > 30) {
            return text.substring(0, 30) as String;
        }
        return text;
    }

}
