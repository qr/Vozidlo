import Toybox.Communications;
import Toybox.Lang;
import Toybox.Test;

// Unit tests for the pure half of ui/Commands.mc: the guards in their old
// order, the request bodies (US-016, US-018, US-021), the cable warning
// (US-022), the failure text (US-043), which answers count as sent, and
// CommandFlight, the one in-flight flag. The sends themselves need a phone.
module CommandsTests {

    (:test)
    function guardKeepsTheOldOrder(logger as Logger) as Boolean {
        if (Commands.guard(true, false, false, false, false) != :busy) {
            logger.error("a request in flight must win over everything");
            return false;
        }
        if (Commands.guard(false, false, false, false, false) != :offline) {
            logger.error("no phone must come before the quota check (US-045)");
            return false;
        }
        if (Commands.guard(false, true, false, false, false) != :quota) {
            logger.error("a spent quota must be reported before the setup check");
            return false;
        }
        if (Commands.guard(false, true, true, true, false) != :setup) {
            logger.error("a missing API key must stop the send");
            return false;
        }
        if (Commands.guard(false, true, true, true, true) != :ok) {
            logger.error("everything in place must send");
            return false;
        }
        return true;
    }

    // CommandFlight: one command in flight for home and both charging
    // menus. A start blocks until done(); the backstop lets go after
    // STALE_MS, and a wrapped timer (negative) never blocks.
    (:test)
    function oneCommandInFlightForEveryScreen(logger as Logger) as Boolean {
        if (!CommandFlight.blocks(0) || !CommandFlight.blocks(CommandFlight.STALE_MS - 1)) {
            logger.error("a command just started must block the next");
            return false;
        }
        if (CommandFlight.blocks(CommandFlight.STALE_MS) || CommandFlight.blocks(-1)) {
            logger.error("a stale or wrapped start must not block");
            return false;
        }
        CommandFlight.done();
        if (CommandFlight.busy()) {
            logger.error("nothing sent, nothing in flight");
            return false;
        }
        CommandFlight.start();
        var during = CommandFlight.busy();
        CommandFlight.done();
        if (!during || CommandFlight.busy()) {
            logger.error("start() must block until done()");
            return false;
        }
        return true;
    }

    (:test)
    function promptOnlyForCommands(logger as Logger) as Boolean {
        var p = Commands.prompt(ConfirmationPolicy.STOP_CHARGING);
        if (p == null || !p.equals("Stop charging?")) {
            logger.error("stop charging must ask a yes/no question");
            return false;
        }
        if (Commands.prompt(ControlTiles.OPEN_STATUS) != null || Commands.prompt(ConfirmationPolicy.SET_CHARGE_LIMIT) != null) {
            logger.error("navigation rows and other screens' commands have no prompt here");
            return false;
        }
        return true;
    }

    function _target(body as Dictionary<Object, Object>) as Dictionary {
        return body.get("targetTemperature") as Dictionary;
    }

    // US-018 override first, in the user's unit, F mapped to FAHRENHEIT.
    (:test)
    function airConditioningBodyPrefersTheOverride(logger as Logger) as Boolean {
        var body = Commands.airConditioningBody(70, "F", 21.5, "CELSIUS");
        var t = _target(body);
        if ((t.get("value") as Number) != 70 || !(t.get("unit") as String).equals("FAHRENHEIT")) {
            logger.error("the override must win, in FAHRENHEIT");
            return false;
        }
        if (!(body.get("airConditioningWithoutExternalPower") as Boolean)) {
            logger.error("the body must always carry airConditioningWithoutExternalPower");
            return false;
        }
        return true;
    }

    (:test)
    function airConditioningBodyFallsBackToCachedThenDefault(logger as Logger) as Boolean {
        var cached = _target(Commands.airConditioningBody(null, "C", 22.5, "CELSIUS"));
        if ((cached.get("value") as Float) != 22.5 || !(cached.get("unit") as String).equals("CELSIUS")) {
            logger.error("without an override the car's own last value must be sent unconverted");
            return false;
        }
        var fallback = _target(Commands.airConditioningBody(null, "C", 22.5, null));
        if ((fallback.get("value") as Float) != 21.0 || !(fallback.get("unit") as String).equals("CELSIUS")) {
            logger.error("with nothing usable the default 21 C must be sent");
            return false;
        }
        return true;
    }

    (:test)
    function auxHeatingBodyUsesTheFixedDefaults(logger as Logger) as Boolean {
        var body = Commands.auxHeatingBody("1234");
        if (!(body.get("spin") as String).equals("1234") || (body.get("durationInSeconds") as Number) != 600
            || !(body.get("startMode") as String).equals("HEATING")) {
            logger.error("aux heating body must be spin, 600 s, HEATING");
            return false;
        }
        return true;
    }

    (:test)
    function startChargingWarnsWhenNoCable(logger as Logger) as Boolean {
        var warned = Commands.announcement(ConfirmationPolicy.START_CHARGING, "CONNECT_CABLE");
        if (!warned[0].equals(Commands.CABLE_WARNING) || warned[1] != :warn) {
            logger.error("start charging with CONNECT_CABLE must warn");
            return false;
        }
        var plain = Commands.announcement(ConfirmationPolicy.START_CHARGING, "READY_FOR_CHARGING");
        var other = Commands.announcement(ConfirmationPolicy.START_CLIMATE, "CONNECT_CABLE");
        if (plain[1] != :sent || other[1] != :sent || !other[0].equals(Commands.SENT)) {
            logger.error("only start charging with CONNECT_CABLE warns; the rest say Command sent");
            return false;
        }
        return true;
    }

    // The status comes first, so the line's "…" cut never hides it, and
    // the reason follows whole.
    (:test)
    function failureTextPutsTheStatusFirst(logger as Logger) as Boolean {
        var text = Commands.failureText(422, "Your car can't do this.");
        if (!text.equals("Not sent (422): Your car can't do this.")) {
            logger.error("expected the status before the reason, got " + text);
            return false;
        }
        if (!Commands.failureText(-104, "Offline").equals("Not sent (-104): Offline")) {
            logger.error("a transport code is shown the same way");
            return false;
        }
        var at = Commands.failureText(401, "x").find("401");
        if (at == null || at > 12) {
            logger.error("the status must sit at the start of the line");
            return false;
        }
        return true;
    }

    // Garmin Connect on iOS reports Škoda's empty 202 as -400; only there,
    // and only that code, counts as sent.
    (:test)
    function isSentReadsMinus400AsSentOnIosOnly(logger as Logger) as Boolean {
        var invalidBody = Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE;
        if (!Commands.isSent(202, false) || !Commands.isSent(202, true) || !Commands.isSent(200, false)) {
            logger.error("a 2xx is sent on every phone");
            return false;
        }
        if (!Commands.isSent(invalidBody, true)) {
            logger.error("-400 on iOS is Škoda's 202 and must count as sent");
            return false;
        }
        if (Commands.isSent(invalidBody, false)) {
            logger.error("-400 on Android must stay a failure");
            return false;
        }
        if (Commands.isSent(Communications.BLE_CONNECTION_UNAVAILABLE, true) || Commands.isSent(429, true)
                || Commands.isSent(401, true) || Commands.isSent(300, true)) {
            logger.error("other codes on iOS must stay failures");
            return false;
        }
        return true;
    }

}
