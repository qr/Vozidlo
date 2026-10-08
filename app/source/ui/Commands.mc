import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.WatchUi;

// The home list's command sends (US-016, US-020, US-021, US-022, US-062),
// lifted line for line from the old ControlsView.mc (activate() and the
// sending/response/announce section, :636-919) so the menu only draws. The
// pure half (module Commands) is unit tested in tests/CommandsTests.mc; the
// CommandRunner class below does the I/O and reports back to the home
// through a WeakReference (the home owns the runner, so a strong reference
// back would be a cycle, docs/best-practices "Break reference cycles").
module Commands {

    // One wording per message, shared by every screen that says it (home,
    // Status, Charging detail and its menus, profiles, Find my car).
    const SENT = "Command sent";
    const CABLE_WARNING = "Sent: no cable appears to be connected";
    const QUOTA_SPENT = "Quota spent for this hour";
    const NO_PHONE = "Phone not connected";
    const NOT_SENT_PREFIX = "Not sent (";

    // What activate() does before anything is sent. :busy, :offline and
    // :setup stay silent exactly as before (a stray double press; US-045
    // "silently disabled"; onboarding's job, see OnboardingGate.mc); only
    // :quota says why (US-040).
    function guard(sending as Boolean, phoneConnected as Boolean, canSpend as Boolean,
                   vinValid as Boolean, hasApiKey as Boolean) as Symbol {
        if (sending) {
            return :busy;
        }
        if (!phoneConnected) {
            return :offline;
        }
        if (!canSpend) {
            return :quota;
        }
        if (!vinValid || !hasApiKey) {
            return :setup;
        }
        return :ok;
    }

    // The yes/no question ConfirmationPolicy shows when it asks (US-062).
    // null for anything that is not a command this list sends.
    function prompt(action as Symbol) as String? {
        if (action == ConfirmationPolicy.START_CLIMATE) {
            return "Start climate?";
        }
        if (action == ConfirmationPolicy.STOP_CLIMATE) {
            return "Stop climate?";
        }
        if (action == ConfirmationPolicy.START_VENTILATION) {
            return "Start ventilation?";
        }
        if (action == ConfirmationPolicy.STOP_VENTILATION) {
            return "Stop ventilation?";
        }
        if (action == ConfirmationPolicy.START_AUX_HEATING) {
            return "Start the auxiliary heater?";
        }
        if (action == ConfirmationPolicy.STOP_AUX_HEATING) {
            return "Stop the auxiliary heater?";
        }
        if (action == ConfirmationPolicy.START_CHARGING) {
            return "Start charging?";
        }
        if (action == ConfirmationPolicy.STOP_CHARGING) {
            return "Stop charging?";
        }
        return null;
    }

    // US-016: the body always carries BOTH fields. Preference order: an
    // explicit on-device/phone override (US-018) first; otherwise exactly
    // what the car itself last reported (value AND unit, unconverted: no
    // C/F conversion happens here); otherwise a conservative common default
    // so a body is always sent at all, never omitted.
    function airConditioningBody(override as Number?, unitSetting as String,
                                 cachedValue as Object?, cachedUnit as String?) as Dictionary<Object, Object> {
        if (override != null) {
            return {
                "targetTemperature" => { "value" => override, "unit" => apiUnit(unitSetting) },
                "airConditioningWithoutExternalPower" => true
            };
        }
        if (cachedValue != null && cachedUnit != null) {
            return {
                "targetTemperature" => { "value" => cachedValue, "unit" => cachedUnit },
                "airConditioningWithoutExternalPower" => true
            };
        }
        return {
            "targetTemperature" => { "value" => 21.0, "unit" => "CELSIUS" },
            "airConditioningWithoutExternalPower" => true
        };
    }

    function apiUnit(unit as String) as String {
        if (unit.equals("F")) {
            return "FAHRENHEIT";
        }
        return "CELSIUS";
    }

    // US-021: spin is the only REQUIRED field of
    // StartAuxiliaryHeatingConfiguration; duration/mode have no on-watch
    // picker, so fixed defaults are sent: 600 s/HEATING matches
    // openapi.json's own example values for this exact body. The S-PIN goes
    // into the request body and nowhere else: never logged, never shown.
    function auxHeatingBody(spin as String) as Dictionary<Object, Object> {
        return {
            "spin" => spin,
            "durationInSeconds" => 600,
            "startMode" => "HEATING"
        };
    }

    // US-022: "starting is offered but the app warns that no cable appears
    // to be connected": not a second confirmation, just a different
    // announcement once the request has already gone out. Returns
    // [text, kind] for HomeMenu.showFeedback().
    function announcement(action as Symbol, chargingState as String?) as [String, Symbol] {
        if (action == ConfirmationPolicy.START_CHARGING && ChargingLogic.needsCableWarning(chargingState)) {
            return [CABLE_WARNING, :warn];
        }
        return [SENT, :sent];
    }

    // US-016/US-043: "Not sent", the status, then ProblemDetail's reason,
    // whole. The hero's status line fits it by pixels with "…" (A5), so the
    // status goes first, where the cut never reaches it: 1.1.x put it last,
    // and on the watch nobody could read why a command failed.
    function failureText(status as Number, reason as String) as String {
        return NOT_SENT_PREFIX + status.toString() + "): " + reason;
    }

}

// Sends one command at a time for the home list. `_sending` lives here, not
// in the menu, so a double press is ignored however the menu was rebuilt.
class CommandRunner {

    private var _home as WeakReference;
    private var _sending as Boolean = false;
    private var _action as Symbol = ConfirmationPolicy.START_CLIMATE;

    function initialize(home as HomeMenu) {
        _home = home.weak();
    }

    // Called once a row was picked (one tap or SELECT, D6). Navigation rows
    // never reach this: HomeDelegate opens their screens without the guards.
    function activate(action as Symbol) as Void {
        var message = Commands.prompt(action);
        if (message == null) {
            return;
        }
        var settings = getApp().getSettings();
        var verdict = Commands.guard(_sending, System.getDeviceSettings().phoneConnected, Quota.canSpend(),
            settings.vinValid, settings.apiKey.length() > 0);
        if (verdict == :quota) {
            _feedback(Commands.QUOTA_SPENT, :error);
            return;
        }
        if (verdict != :ok) {
            return;
        }
        _action = action;
        ConfirmationPolicy.run(action, message, method(:_send), method(:_announce));
    }

    // ------------------------------------------------------------ sending
    //
    // `:responseType` is never set here: ApiClient's own functions already
    // omit it for every command (see ApiClient.mc).

    function _send() as Void {
        _sending = true;
        var settings = getApp().getSettings();
        var vin = settings.vin;
        var key = settings.apiKey;
        var done = method(:_onCommandResponse);
        var action = _action;
        if (action == ConfirmationPolicy.START_CLIMATE) {
            var cached = Cache.section("airConditioning");
            var cachedValue = (cached != null) ? cached.get("targetValue") : null;
            var cachedUnit = (cached != null) ? (cached.get("targetUnit") as String?) : null;
            ApiClient.startAirConditioning(vin,
                Commands.airConditioningBody(settings.targetTemperature, settings.temperatureUnit, cachedValue, cachedUnit),
                key, done);
        } else if (action == ConfirmationPolicy.STOP_CLIMATE) {
            ApiClient.stopAirConditioning(vin, key, done);
        } else if (action == ConfirmationPolicy.START_VENTILATION) {
            // US-020: no body, no S-PIN.
            ApiClient.startActiveVentilation(vin, key, done);
        } else if (action == ConfirmationPolicy.STOP_VENTILATION) {
            ApiClient.stopActiveVentilation(vin, key, done);
        } else if (action == ConfirmationPolicy.START_AUX_HEATING) {
            ApiClient.startAuxiliaryHeating(vin, Commands.auxHeatingBody(settings.spin), key, done);
        } else if (action == ConfirmationPolicy.STOP_AUX_HEATING) {
            ApiClient.stopAuxiliaryHeating(vin, key, done);
        } else if (action == ConfirmationPolicy.START_CHARGING) {
            // US-022: neither charging endpoint takes a body.
            ApiClient.startCharging(vin, key, done);
        } else if (action == ConfirmationPolicy.STOP_CHARGING) {
            ApiClient.stopCharging(vin, key, done);
        } else {
            _sending = false;
        }
    }

    // ----------------------------------------------------------- response

    // US-016/US-043: a 202 means "sent", never "done". _announce() (called
    // the moment the request went out, from ConfirmationPolicy.run())
    // already said so. "Climate on" is only ever said from the car's own
    // report, read once 15 s later when the user's setting allows
    // (CommandCheck.mc). A failure overwrites "sent" with "Not sent", see
    // ProblemDetail's own note on why the reason comes from the status.
    function _onCommandResponse(responseCode as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        _sending = false;

        if (responseCode >= 200 && responseCode < 300) {
            Quota.recordHeaders(null, null, null);
            if (_home.stillAlive()) {
                var home = _home.get() as HomeMenu?;
                if (home != null && CommandCheck.startIfAllowed(_action, null, home)) {
                    _feedback(CommandCheck.CHECKING, :sent);
                }
            }
            WatchUi.requestUpdate();
            return;
        }

        var body = (data instanceof Dictionary) ? (data as Dictionary) : null;
        if (responseCode == 429) {
            var problemType = (body != null) ? (body.get("type") as String?) : null;
            Quota.recordRateLimited(problemType, null);
        }
        var text = Commands.failureText(responseCode, ProblemDetail.describe(responseCode, body, Quota.retryAfterUntil()).text);
        _feedback(text, :error);
        _toast(text);
    }

    // US-062: called once, right after the send, on whichever branch of
    // ConfirmationPolicy.run() fired (the vibration happens in that module).
    // Reads the same cached charging state the hero chip shows, so the cable
    // warning can never disagree with what is on screen.
    function _announce() as Void {
        var charging = Cache.section("charging");
        var state = (charging != null) ? (charging.get("state") as String?) : null;
        var said = Commands.announcement(_action, state);
        _feedback(said[0], said[1]);
        _toast(said[0]);
    }

    // US-058: the status line persists, the native toast does not; both
    // fire. Guarded with `has`: minApiLevel 5.2.0 predates showToast on some
    // firmware, so it stays a bonus (docs/best-practices "Probe optional
    // API surface with has").
    function _toast(message as String) as Void {
        if (WatchUi has :showToast) {
            WatchUi.showToast(message, null);
        }
    }

    function _feedback(text as String, kind as Symbol) as Void {
        if (_home.stillAlive()) {
            var home = _home.get() as HomeMenu?;
            if (home != null) {
                home.showFeedback(text, kind);
            }
        }
        WatchUi.requestUpdate();
    }

}
