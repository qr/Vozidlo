import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

// Unit tests for module CommandCheck (ui/CommandCheck.mc): which section a
// command's effect shows in, when a check may run, and what the line says
// about the car's report. The timer and the read need a phone.
module CommandCheckTests {

    const SENT_AT = 1000000;

    function verdictOf(action as Symbol, expected as Object?, section as Dictionary?, capturedAt as Number?) as [String, Symbol] {
        return CommandCheck.verdict(action, expected, section, capturedAt, SENT_AT);
    }

    function expect(logger as Logger, label as String, got as [String, Symbol], text as String, kind as Symbol) as Boolean {
        if (!got[0].equals(text) || got[1] != kind) {
            logger.error(label + ": expected '" + text + "' " + kind.toString() + ", got '" + got[0] + "' " + got[1].toString());
            return false;
        }
        return true;
    }

    (:test)
    function eachCommandIsCheckedInItsSection(logger as Logger) as Boolean {
        var climate = [ConfirmationPolicy.START_CLIMATE, ConfirmationPolicy.STOP_CLIMATE,
            ConfirmationPolicy.START_VENTILATION, ConfirmationPolicy.STOP_VENTILATION,
            ConfirmationPolicy.START_AUX_HEATING, ConfirmationPolicy.STOP_AUX_HEATING] as Array<Symbol>;
        var charging = [ConfirmationPolicy.START_CHARGING, ConfirmationPolicy.STOP_CHARGING,
            ConfirmationPolicy.SET_CHARGE_LIMIT, ConfirmationPolicy.SET_CHARGE_MODE] as Array<Symbol>;
        for (var i = 0; i < climate.size(); i += 1) {
            if (!CommandCheck.section(climate[i]).equals("airConditioning")) {
                logger.error(climate[i].toString() + " must be checked in airConditioning");
                return false;
            }
        }
        for (var i = 0; i < charging.size(); i += 1) {
            if (!CommandCheck.section(charging[i]).equals("charging")) {
                logger.error(charging[i].toString() + " must be checked in charging");
                return false;
            }
        }
        return true;
    }

    // The setting, a phone, quota, and not the last few requests.
    (:test)
    function aCheckRunsOnlyWhenAllowed(logger as Logger) as Boolean {
        if (!CommandCheck.shouldCheck(true, true, true, false)) {
            logger.error("all allowed must check");
            return false;
        }
        if (CommandCheck.shouldCheck(false, true, true, false) || CommandCheck.shouldCheck(true, false, true, false)
                || CommandCheck.shouldCheck(true, true, false, false) || CommandCheck.shouldCheck(true, true, true, true)) {
            logger.error("setting off, no phone, no quota or low quota must skip the check");
            return false;
        }
        return true;
    }

    // A report from before the command says nothing about it: grey, never
    // an error, whatever the state. Within the clock slack it counts.
    (:test)
    function anOldReportIsNotAVerdict(logger as Logger) as Boolean {
        var on = { "state" => "HEATING" } as Dictionary;
        if (!expect(logger, "older report", verdictOf(ConfirmationPolicy.START_CLIMATE, null, on, SENT_AT - 60), CommandCheck.NOT_YET, :age)) {
            return false;
        }
        if (!expect(logger, "no timestamp", verdictOf(ConfirmationPolicy.START_CLIMATE, null, on, null), CommandCheck.NOT_YET, :age)) {
            return false;
        }
        if (!expect(logger, "no section", verdictOf(ConfirmationPolicy.START_CLIMATE, null, null, SENT_AT + 8), CommandCheck.NOT_YET, :age)) {
            return false;
        }
        return expect(logger, "within the slack", verdictOf(ConfirmationPolicy.START_CLIMATE, null, on, SENT_AT - 3), "Climate on", :sent);
    }

    // Measured on 2026-10-08: stop climate, then the car reported OFF 8 s
    // later; start climate, HEATING 12 s later.
    (:test)
    function climateCommandsAreConfirmedFromTheCarsState(logger as Logger) as Boolean {
        var off = { "state" => "OFF" } as Dictionary;
        var heating = { "state" => "HEATING" } as Dictionary;
        var later = SENT_AT + 10;
        return expect(logger, "start, heating", verdictOf(ConfirmationPolicy.START_CLIMATE, null, heating, later), "Climate on", :sent)
            && expect(logger, "start, cooling", verdictOf(ConfirmationPolicy.START_CLIMATE, null, { "state" => "COOLING" } as Dictionary, later), "Climate on", :sent)
            && expect(logger, "start, still off", verdictOf(ConfirmationPolicy.START_CLIMATE, null, off, later), "Car reports: Off", :warn)
            && expect(logger, "stop, off", verdictOf(ConfirmationPolicy.STOP_CLIMATE, null, off, later), "Climate off", :sent)
            && expect(logger, "stop, still heating", verdictOf(ConfirmationPolicy.STOP_CLIMATE, null, heating, later), "Car reports: Heating", :warn)
            && expect(logger, "ventilation on", verdictOf(ConfirmationPolicy.START_VENTILATION, null, { "state" => "VENTILATION" } as Dictionary, later), "Ventilating", :sent)
            && expect(logger, "ventilation off", verdictOf(ConfirmationPolicy.STOP_VENTILATION, null, off, later), "Ventilation off", :sent)
            && expect(logger, "aux on", verdictOf(ConfirmationPolicy.START_AUX_HEATING, null, { "state" => "HEATING_AUXILIARY" } as Dictionary, later), "Aux heater on", :sent)
            && expect(logger, "aux wrong", verdictOf(ConfirmationPolicy.START_AUX_HEATING, null, heating, later), "Car reports: Heating", :warn)
            && expect(logger, "aux off", verdictOf(ConfirmationPolicy.STOP_AUX_HEATING, null, off, later), "Aux heater off", :sent);
    }

    (:test)
    function chargingCommandsAreConfirmedFromTheCarsState(logger as Logger) as Boolean {
        var later = SENT_AT + 10;
        var charging = { "state" => "CHARGING" } as Dictionary;
        var ready = { "state" => "READY_FOR_CHARGING" } as Dictionary;
        return expect(logger, "start, charging", verdictOf(ConfirmationPolicy.START_CHARGING, null, charging, later), "Charging", :sent)
            && expect(logger, "start, not charging", verdictOf(ConfirmationPolicy.START_CHARGING, null, ready, later), "Car reports: Plugged in", :warn)
            && expect(logger, "stop, stopped", verdictOf(ConfirmationPolicy.STOP_CHARGING, null, ready, later), "Charging stopped", :sent)
            && expect(logger, "stop, still charging", verdictOf(ConfirmationPolicy.STOP_CHARGING, null, charging, later), "Car reports: Charging", :warn);
    }

    (:test)
    function limitAndModeAreComparedWithWhatWasSent(logger as Logger) as Boolean {
        var later = SENT_AT + 10;
        var section = { "state" => "READY_FOR_CHARGING", "targetSocPercent" => 80, "preferredChargeMode" => "MANUAL" } as Dictionary;
        return expect(logger, "limit applied", verdictOf(ConfirmationPolicy.SET_CHARGE_LIMIT, 80, section, later), "Limit set to 80%", :sent)
            && expect(logger, "limit not yet", verdictOf(ConfirmationPolicy.SET_CHARGE_LIMIT, 90, section, later), "Car reports limit: 80%", :warn)
            && expect(logger, "mode applied", verdictOf(ConfirmationPolicy.SET_CHARGE_MODE, "MANUAL", section, later), "Mode: " + Labels.mode("MANUAL"), :sent)
            && expect(logger, "mode not yet", verdictOf(ConfirmationPolicy.SET_CHARGE_MODE, "TIMER", section, later), "Car reports mode: " + Labels.mode("MANUAL"), :warn);
    }

    // A state value nobody listed still reads as words, through Labels.
    (:test)
    function anUnknownStateIsShownInWords(logger as Logger) as Boolean {
        var got = verdictOf(ConfirmationPolicy.START_CLIMATE, null, { "state" => "SOMETHING_NEW" } as Dictionary, SENT_AT + 10);
        if (got[1] != :warn || got[0].find("SOMETHING_NEW") != null) {
            logger.error("expected words, not the raw value, got '" + got[0] + "'");
            return false;
        }
        return true;
    }

    (:test)
    function aFailedCheckStillSaysSent(logger as Logger) as Boolean {
        var text = CommandCheck.failedText(-104);
        if (text.find("Sent") != 0 || text.find("-104") == null) {
            logger.error("got '" + text + "'");
            return false;
        }
        return true;
    }

    // ---------------------------------------------------- CommandChecker
    //
    // The checker driven without a network: start() arms the timer, the
    // test cancels it and hands _onVehicle() the response the read would
    // have got. The double stands in for HomeMenu / ChargingDetailView.

    class FakeReporter {
        public var text as String? = null;
        public var kind as Symbol? = null;

        function initialize() {
        }

        function commandChecked(t as String, k as Symbol) as Void {
            text = t;
            kind = k;
        }
    }

    function armed(action as Symbol, expected as Object?, reporter as FakeReporter) as CommandChecker {
        var checker = new CommandChecker();
        checker.toasts = false;
        checker.start(action, expected, reporter);
        checker.cancel();
        return checker;
    }

    // Reports dated 2037 count as "after the command": a later year would
    // not fit a 32-bit epoch (Monkey C's Number runs out in 2038).
    function vehicle(sectionName as String, section as Dictionary) as Dictionary {
        return { "vehicle" => { sectionName => section } };
    }

    (:test)
    function startArmsOneCheckAndCancelStopsIt(logger as Logger) as Boolean {
        var checker = new CommandChecker();
        checker.toasts = false;
        var reporter = new FakeReporter();
        checker.start(ConfirmationPolicy.STOP_CLIMATE, null, reporter);
        if (!checker.isPending()) {
            logger.error("start() must arm the 15 s timer");
            return false;
        }
        // A second command replaces the first check, never adds one.
        checker.start(ConfirmationPolicy.START_CHARGING, null, reporter);
        if (!checker.isPending()) {
            logger.error("a new command must re-arm the check");
            return false;
        }
        checker.cancel();
        if (checker.isPending()) {
            logger.error("cancel() must stop the timer");
            return false;
        }
        return true;
    }

    // The read came back with the car's report after the command.
    (:test)
    function aFreshReportReachesTheReporter(logger as Logger) as Boolean {
        var reporter = new FakeReporter();
        var checker = armed(ConfirmationPolicy.STOP_CLIMATE, null, reporter);
        checker._onVehicle(200, vehicle("airConditioning",
            { "state" => "OFF", "carCapturedTimestamp" => "2037-01-01T00:00:00Z" } as Dictionary));
        if (reporter.text == null || !(reporter.text as String).equals("Climate off") || reporter.kind != :sent) {
            logger.error("expected 'Climate off' :sent, got " + reporter.text + " " + reporter.kind);
            return false;
        }
        return true;
    }

    // The car has not reported since the command: grey, never an error.
    (:test)
    function anOldReportReachesTheReporterAsNotYet(logger as Logger) as Boolean {
        var reporter = new FakeReporter();
        var checker = armed(ConfirmationPolicy.STOP_CLIMATE, null, reporter);
        checker._onVehicle(200, vehicle("airConditioning",
            { "state" => "HEATING", "carCapturedTimestamp" => "2020-01-01T00:00:00Z" } as Dictionary));
        if (reporter.text == null || !(reporter.text as String).equals(CommandCheck.NOT_YET) || reporter.kind != :age) {
            logger.error("expected NOT_YET :age, got " + reporter.text + " " + reporter.kind);
            return false;
        }
        return true;
    }

    // The charge limit is compared with what was sent, from the read's
    // charging section.
    (:test)
    function aLimitChangeIsReadFromTheChargingSection(logger as Logger) as Boolean {
        var reporter = new FakeReporter();
        var checker = armed(ConfirmationPolicy.SET_CHARGE_LIMIT, 80, reporter);
        checker._onVehicle(200, vehicle("charging", {
            "carCapturedTimestamp" => "2037-01-01T00:00:00Z",
            "status" => { "state" => "READY_FOR_CHARGING" },
            "settings" => { "targetStateOfChargeInPercent" => 80 }
        } as Dictionary));
        if (reporter.text == null || !(reporter.text as String).equals("Limit set to 80%") || reporter.kind != :sent) {
            logger.error("expected 'Limit set to 80%' :sent, got " + reporter.text + " " + reporter.kind);
            return false;
        }
        return true;
    }

    // The check's own read failed: grey, with its status, still "Sent".
    (:test)
    function aFailedReadReachesTheReporterAsSent(logger as Logger) as Boolean {
        var reporter = new FakeReporter();
        var checker = armed(ConfirmationPolicy.START_CHARGING, null, reporter);
        checker._onVehicle(503, null);
        if (reporter.text == null || !(reporter.text as String).equals(CommandCheck.failedText(503)) || reporter.kind != :age) {
            logger.error("expected the failed text :age, got " + reporter.text + " " + reporter.kind);
            return false;
        }
        return true;
    }

    // The screen that asked may be gone by the time the read returns.
    (:test)
    function aGoneReporterIsNoCrash(logger as Logger) as Boolean {
        var checker = new CommandChecker();
        checker.toasts = false;
        checker.start(ConfirmationPolicy.STOP_CLIMATE, null, new FakeReporter());
        checker.cancel();
        checker._onVehicle(200, vehicle("airConditioning",
            { "state" => "OFF", "carCapturedTimestamp" => "2037-01-01T00:00:00Z" } as Dictionary));
        return true;
    }

    // ------------------------------------------------------- the hooks

    // Home's 202 starts the check when the setting, phone and quota allow,
    // and the result lands on the screen that asked. A second 202 replaces
    // the pending check rather than adding one.
    (:test)
    function homesAcceptedCommandStartsTheCheck(logger as Logger) as Boolean {
        var home = new HomeMenu();
        var runner = new CommandRunner(home);
        var allowed = CommandCheck.shouldCheck(getApp().getSettings().checkAfterCommand,
            System.getDeviceSettings().phoneConnected, Quota.canSpend(), Quota.isLow());
        logger.debug("check allowed in this run: " + allowed);
        var checker = CommandCheck.checker();
        checker.cancel();
        runner._onCommandResponse(202, null);
        var pending = checker.isPending();
        checker.cancel();
        if (pending != allowed) {
            logger.error("a 202 must start the check exactly when it is allowed (allowed " + allowed + ", pending " + pending + ")");
            return false;
        }
        return true;
    }

    // Charging detail shows the check in the check's own kind: amber for a
    // different report, grey for "not yet", never the red of a failure.
    (:test)
    function chargingDetailShowsTheChecksKind(logger as Logger) as Boolean {
        if (!System.getDeviceSettings().phoneConnected) {
            return true;   // the offline line outranks every status, as it should
        }
        var detail = new ChargingDetailView();
        detail.commandChecked("Car reports limit: 80%", :warn);
        if (detail._transientKind() != :warn || !detail._transientText().equals("Car reports limit: 80%")) {
            logger.error("expected the amber report");
            return false;
        }
        detail.commandChecked(CommandCheck.NOT_YET, :age);
        if (detail._transientKind() != :age) {
            logger.error("'not reported yet' must be grey");
            return false;
        }
        detail.setStatus("Not sent (422): Your car can't do this.", true);
        if (detail._transientKind() != :error) {
            logger.error("a failure stays red");
            return false;
        }
        return true;
    }

}
