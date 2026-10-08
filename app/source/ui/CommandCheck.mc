import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

// One check after a command (setting "Check the car after a command", on by
// default). A 202 only means Škoda accepted the command; whether the car
// acted is only known from what the car itself reports afterwards. On
// 2026-10-08 the car reported a new climate state 8 s (stop) and 12 s
// (start) after the command, so 15 s after a 202 the app reads the one
// section the command touches, once, and says what the car reported. One
// request per command, never a retry, never in the background: see
// docs/decisions.md, "One check after a command".
//
// The pure half (module CommandCheck) is unit tested in
// tests/CommandCheckTests.mc; CommandChecker does the timer and the read.
module CommandCheck {

    // Whoever shows a check's result: HomeMenu, ChargingDetailView, or a
    // test double.
    typedef Reporter as interface {
        function commandChecked(text as String, kind as Symbol) as Void;
    };

    const DELAY_MS = 15000;
    // The car's clock and the watch's may differ a little; a report up to
    // this many seconds before the send still counts as after it.
    const CLOCK_SLACK = 5;

    const CHECKING = "Sent, checking the car…";
    const NOT_YET = "Sent; the car has not reported yet";

    // The section of the vehicle read that shows a command's effect.
    function section(action as Symbol) as String {
        if (action == ConfirmationPolicy.START_CHARGING || action == ConfirmationPolicy.STOP_CHARGING
                || action == ConfirmationPolicy.SET_CHARGE_LIMIT || action == ConfirmationPolicy.SET_CHARGE_MODE) {
            return "charging";
        }
        return "airConditioning";
    }

    // Whether to check at all: the user's setting, a phone to ask through,
    // and quota to spare. A nearly spent quota is kept for the user's own
    // requests (Quota.isLow()).
    function shouldCheck(enabled as Boolean, phoneConnected as Boolean, canSpend as Boolean, isLow as Boolean) as Boolean {
        return enabled && phoneConnected && canSpend && !isLow;
    }

    // [text, kind] for the status line. `section` is the projected cache
    // section (Cache.section()), `capturedAt` the car's own
    // carCapturedTimestamp in epoch seconds (null when absent), `sentAt`
    // when the command went out. A report from before the command says
    // nothing about it, so it reads as "not reported yet", never as failed.
    function verdict(action as Symbol, expected as Object?, section as Dictionary?,
                     capturedAt as Number?, sentAt as Number) as [String, Symbol] {
        if (section == null || capturedAt == null || capturedAt < sentAt - CLOCK_SLACK) {
            return [NOT_YET, :age];
        }
        var state = section.get("state") as String?;
        if (action == ConfirmationPolicy.START_CLIMATE) {
            return _climate(ControlTiles.isClimateRunning(state), "Climate on", state);
        }
        if (action == ConfirmationPolicy.STOP_CLIMATE) {
            return _climate(!ControlTiles.isClimateRunning(state), "Climate off", state);
        }
        if (action == ConfirmationPolicy.START_VENTILATION) {
            return _climate(state != null && state.equals("VENTILATION"), "Ventilating", state);
        }
        if (action == ConfirmationPolicy.STOP_VENTILATION) {
            return _climate(!ControlTiles.isClimateRunning(state), "Ventilation off", state);
        }
        if (action == ConfirmationPolicy.START_AUX_HEATING) {
            return _climate(state != null && state.equals("HEATING_AUXILIARY"), "Aux heater on", state);
        }
        if (action == ConfirmationPolicy.STOP_AUX_HEATING) {
            return _climate(!ControlTiles.isClimateRunning(state), "Aux heater off", state);
        }
        var charging = state != null && state.equals("CHARGING");
        if (action == ConfirmationPolicy.START_CHARGING) {
            return charging ? ["Charging", :sent] : ["Car reports: " + Labels.charging(state), :warn];
        }
        if (action == ConfirmationPolicy.STOP_CHARGING) {
            return !charging ? ["Charging stopped", :sent] : ["Car reports: " + Labels.charging(state), :warn];
        }
        if (action == ConfirmationPolicy.SET_CHARGE_LIMIT) {
            var limit = section.get("targetSocPercent") as Number?;
            if (limit != null && expected != null && limit == expected) {
                return ["Limit set to " + limit.toString() + "%", :sent];
            }
            return ["Car reports limit: " + (limit != null ? limit.toString() + "%" : "—"), :warn];
        }
        if (action == ConfirmationPolicy.SET_CHARGE_MODE) {
            var mode = section.get("preferredChargeMode") as String?;
            if (mode != null && expected instanceof String && mode.equals(expected)) {
                return ["Mode: " + Labels.mode(mode), :sent];
            }
            return ["Car reports mode: " + Labels.mode(mode), :warn];
        }
        return [NOT_YET, :age];
    }

    function _climate(applied as Boolean, confirmed as String, state as String?) as [String, Symbol] {
        return applied ? [confirmed, :sent] : ["Car reports: " + Labels.climate(state), :warn];
    }

    // The check's own read failed: the command itself was still sent.
    function failedText(status as Number) as String {
        return "Sent; check failed (status " + status.toString() + ")";
    }

    // One checker for the whole app run: it outlives the menus that send
    // commands (the charge limit and mode menus close on the pick).
    var _checker as CommandChecker? = null;

    function checker() as CommandChecker {
        var c = _checker;
        if (c == null) {
            c = new CommandChecker();
            _checker = c;
        }
        return c;
    }

    // Starts a check when it is allowed; returns whether it did, so the
    // caller can say "checking". `reporter` is a HomeMenu or a
    // ChargingDetailView (held weakly).
    function startIfAllowed(action as Symbol, expected as Object?, reporter as Object) as Boolean {
        var allowed = shouldCheck(getApp().getSettings().checkAfterCommand,
            System.getDeviceSettings().phoneConnected, Quota.canSpend(), Quota.isLow());
        if (allowed) {
            checker().start(action, expected, reporter);
        }
        return allowed;
    }

}

// The timer and the one read. A new command cancels a pending check: one at
// a time, so a burst of commands never turns into a burst of reads.
class CommandChecker {

    private var _timer as Timer.Timer? = null;
    private var _action as Symbol = ConfirmationPolicy.START_CLIMATE;
    private var _expected as Object? = null;
    private var _sentAt as Number = 0;
    private var _section as String = "airConditioning";
    private var _reporter as WeakReference? = null;
    // Off in the unit tests, which drive _onVehicle() without a screen.
    public var toasts as Boolean = true;

    function initialize() {
    }

    // Whether a check is waiting for its 15 s.
    function isPending() as Boolean {
        return _timer != null;
    }

    function start(action as Symbol, expected as Object?, reporter as Object) as Void {
        cancel();
        _action = action;
        _expected = expected;
        _sentAt = Time.now().value();
        _section = CommandCheck.section(action);
        _reporter = (reporter as Lang.Object).weak();
        var timer = new Timer.Timer();
        timer.start(method(:_fire), CommandCheck.DELAY_MS, false);
        _timer = timer;
    }

    function cancel() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
            _timer = null;
        }
    }

    function _fire() as Void {
        _timer = null;
        // Checked again: the phone or the quota may have gone in 15 s.
        if (!(System.getDeviceSettings().phoneConnected) || !Quota.canSpend()) {
            _report(CommandCheck.NOT_YET, :age);
            return;
        }
        var settings = getApp().getSettings();
        ApiClient.getVehicle(settings.vin, _section, settings.apiKey, method(:_onVehicle));
    }

    function _onVehicle(responseCode as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        var body = (data instanceof Dictionary) ? (data as Dictionary) : null;
        if (responseCode == 200 && body != null) {
            var vehicle = body.get("vehicle") as Dictionary?;
            if (vehicle != null) {
                Cache.update(vehicle, body.get("errors") as Array?);
                Quota.recordHeaders(null, null, null);
                var raw = vehicle.get(_section) as Dictionary?;
                var stamp = (raw != null) ? (raw.get("carCapturedTimestamp") as String?) : null;
                var capturedAt = (stamp != null) ? Cache._parseIso8601(stamp) : null;
                var v = CommandCheck.verdict(_action, _expected, Cache.section(_section), capturedAt, _sentAt);
                _report(v[0], v[1]);
                return;
            }
        }
        if (responseCode == 429) {
            Quota.recordRateLimited((body != null) ? (body.get("type") as String?) : null, null);
        }
        _report(CommandCheck.failedText(responseCode), :age);
    }

    // The reporter is whatever has commandChecked(text, kind): HomeMenu,
    // ChargingDetailView, or a test double. Gone (popped) means only the
    // toast says it.
    function _report(text as String, kind as Symbol) as Void {
        var ref = _reporter;
        if (ref != null && ref.stillAlive()) {
            var reporter = ref.get();
            if (reporter != null && (reporter has :commandChecked)) {
                (reporter as CommandCheck.Reporter).commandChecked(text, kind);
            }
        }
        if (toasts && (WatchUi has :showToast)) {
            WatchUi.showToast(text, null);
        }
        WatchUi.requestUpdate();
    }

}
